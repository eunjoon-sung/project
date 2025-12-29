//마스터 

/*
 * Master.c
 
 * 입차 번호 누르고 확인 누른 순간 -> 입차로 감지
 * LCD에 입차 감지 표시. 아닐 때는 기다리고 있다고 LCD에 계속 표시
 * UART 통해서 입차 대수 (최대 8대) 남은 공간 계속 신호로 slave A에 알려주기
 * 차가 들어오는 순간부터 타이머 인터럽트로 1초씩 시간 계산 -> 메모리에 차번호 4자리, 시간 저장하기
 * slave B에서 출차 신호를 보내서 master에서 신호가 수신되면 주차 시간만큼 요금 정산하기
 * 
   입차 흐름:
 1. 대기 상태 → LCD: “입차 대기 중입니다”
 2. slave A에서 차량 번호 입력 (Keypad) 확인 누름 (#) → 입차 감지
 3. UART 인터럽트 들어옴
 - LCD: “입차 감지됨”
 - 차량 번호 + 시간 메모리에 저장
 - car_count++, UART로 Slave A에 잔여 공간 전송
 - 입차 시간 저장
 
 출차 흐름:
 - main 루프 내에서 UART로 slave B가 차량번호 송신 → 출차 요청
 - 그 번호와 메모리에 저장된 번호 비교 → 있으면 시간 계산
 - 요금 정산, LCD 출력 and UART 송신
 - car_count--, 잔여 공간 다시 Slave A로 송신
 
 * Created: 2025-06-16 오전 9:27:58
 * Author : me
 */ 
#define F_CPU 16000000UL
#include <avr/io.h>
#include <avr/interrupt.h>
#include <util/delay.h>
#include <string.h> // strcpy 함수 쓰려면 포함
#include <stdlib.h> // itoa() 함수 쓰려면 포함

// LCD 관련 정의
#define PORT_DATA      PORTA
#define PORT_CONTROL   PORTG
#define DDR_DATA      DDRA
#define DDR_CONTROL      DDRG
#define RS_PIN         0
#define RW_PIN         1
#define E_PIN         2

#define COMMAND_CLEAR_DISPLAY   0x01
#define COMMAND_8_BIT_MODE      0x38
#define MAX_CARS 8

// 차량 번호, 시간, 빈자리 관리
typedef struct {
	char car_num[5];              // 차량번호 (NULL 포함해서 5바이트 확보)
	uint16_t entry_seconds;  // 입차 시간
	uint8_t valid;  // 1: 주차 중, 0: 빈 자리
} CarData;
CarData parked_cars[MAX_CARS];  // 차량 정보 메모리에 저장

// 주차 자리 상태
uint8_t calculate_parking_state(void) {
	uint8_t occupied = 0;
	for (int i = 0; i < MAX_CARS; i++) {
		if (parked_cars[i].valid == 1) {
			occupied++;
		}
	}
	return MAX_CARS - occupied;  // 남은 공간 수 반환
}

// ------------------- LCD 함수 -------------------
void LCD_pulse_enable(void) {
	PORT_CONTROL |= (1 << E_PIN);
	_delay_us(1);
	PORT_CONTROL &= ~(1 << E_PIN);
	_delay_ms(1);
}
void LCD_write_data(uint8_t data) {
	PORT_CONTROL |= (1 << RS_PIN);
	PORT_DATA = data;
	LCD_pulse_enable();
	_delay_ms(2);
}
void LCD_write_command(uint8_t command) {
	PORT_CONTROL &= ~(1 << RS_PIN);
	PORT_DATA = command;
	LCD_pulse_enable();
	_delay_ms(2);
}
void LCD_clear(void) {
	LCD_write_command(COMMAND_CLEAR_DISPLAY);
	_delay_ms(2);
}
void LCD_init(void) {
	_delay_ms(50);
	DDR_DATA = 0xFF;
	PORT_DATA = 0x00;
	DDR_CONTROL |= (1 << RS_PIN) | (1 << RW_PIN) | (1 << E_PIN);
	PORT_CONTROL &= ~(1 << RW_PIN);
	_delay_ms(50);
	LCD_write_command(COMMAND_8_BIT_MODE);
	LCD_write_command(0x0C); // Display ON, Cursor OFF
	LCD_clear();
	LCD_write_command(0x06); // Entry mode set
}
void LCD_write_string(const char *string) {
	uint8_t i = 0;
	while (string[i]) {
		LCD_write_data(string[i]);
		i++;
	}
}
void LCD_goto_XY(uint8_t row, uint8_t col) {
	col %= 16;
	row %= 2;
	uint8_t address = (0x40 * row) + col;
	uint8_t command = 0x80 + address;
	LCD_write_command(command);
}

// ------------------ UART 함수 ---------------------
void UART0_init(void) {
	UBRR0H = 0;
	UBRR0L = 103;
	UCSR0B = (1 << RXEN0) | (1 << TXEN0) | (1 << RXCIE0); // 수신 인터럽트 포함
	UCSR0C = (1 << UCSZ01) | (1 << UCSZ00);
}
void UART1_init(void) {
	UBRR1H = 0;
	UBRR1L = 103;           // 9600 baud @16MHz
	UCSR1B = (1<<RXEN1)|(1<<TXEN1)|(1<<RXCIE1);
	UCSR1C = (1<<UCSZ11)|(1<<UCSZ10);
}
// 입차 UART 0로 송신
void UART0_transmit(uint8_t data) {
	while (!(UCSR0A & (1 << UDRE0)));
	UDR0 = data;
}
void UART_transmit_string(const char* str) {
	while (*str) {
		UART0_transmit(*str++);
	}
}



// -------------------- UART 인터럽트 함수 -----------------------------
 // 입차 신호 발생 시 동작
 volatile char rx_buffer[5];     // 차량번호 수신 버퍼
 volatile uint8_t rx_index = 0;
 volatile uint8_t new_car_ready = 0;
 
ISR(USART0_RX_vect) {
	char data = UDR0;

	if (rx_index < 4) {
		rx_buffer[rx_index++] = data;
	}

	if (rx_index == 4) {
		rx_buffer[4] = '\0'; // 문자열 종료
		new_car_ready = 1;
		rx_index = 0;
	}
}
// 출차 신호 발생 시 동작
volatile char exit_car_buf[7];
volatile uint8_t exit_index = 0;
volatile uint8_t exit_ready = 0;
volatile uint8_t exit_done = 0;

ISR(USART1_RX_vect) {
	char data = UDR1;

	if (data == '\n') {
		if (exit_index < sizeof(exit_car_buf))
		exit_car_buf[exit_index] = '\0';  // 문자열 종료
		else
		exit_car_buf[sizeof(exit_car_buf)-1] = '\0';

		exit_ready = 1;
		exit_index = 0;

		// 디버깅용 LCD 출력
		LCD_clear();
		LCD_goto_XY(0, 0);
		LCD_write_string("RCV:");
		LCD_write_string(exit_car_buf);

		} else {
		if (exit_index < sizeof(exit_car_buf) - 1) {
			exit_car_buf[exit_index++] = data;
			} else {
			exit_index = 0; // overflow 방지
		}
	}

	if (data == 'D') {  // 'D' 문자가 오면 exit_done 플래그 세우기
		exit_done = 1;
	}
}

// ------------------------ 타이머 인터럽트 함수 ------------------------
volatile uint16_t current_seconds = 0; // 전역 시간
volatile uint8_t count = 0;

ISR(TIMER0_COMP_vect) {
	count++;
	if (count == 61) {
		count = 0;
		current_seconds++;
	}
}

void Compare_INT(void){
	
	TCCR0 |= (1 << CS02) | (1 << CS01) | (1 << CS00); // 분주비 1024로 설정 (1 1 1)
	
	TIMSK |= (1 << OCIE0); // 비교일치 interrupt 허용
	OCR0 = 255; // 비교일치 기준 값. 65ns * 1024 = 66us >> 256번 했을 때 비교기 1번 카운트 됨
	// 16MHz => T = 65ns, 65ns * 1024 (분주비) = 66560ns = 66us * 256 (OCR 값) = 8448us * 64 *2 (비교일치 횟수)= 541ms*2 = 1s

	sei();
}

uint8_t parking_state =0;
uint8_t waiting_displayed = 0;

int main(void)
{
	UART0_init();
	UART1_init();
	Compare_INT();
	LCD_init();

	// UART 핀 설정
	DDRE |= (1 << PE1);  // TX0
	DDRE &= ~(1 << PE0); // RX0
	DDRD |= (1 << PD1);  // TX1
	DDRD &= ~(1 << PD0); // RX1

	// 차량 데이터 초기화
	for (int i = 0; i < MAX_CARS; i++) {
		parked_cars[i].valid = 0;
		memset(parked_cars[i].car_num, 0, 5);
	}
	parking_state = calculate_parking_state();

	while (1) {
		// 1. 입차 처리
		if (new_car_ready) {
			new_car_ready = 0;

			int idx = -1;
			for (int i = 0; i < MAX_CARS; i++) {
				if (parked_cars[i].valid == 0) {
					idx = i;
					break;
				}
			}

			if (idx != -1) {
				strncpy(parked_cars[idx].car_num, rx_buffer, 4);
				parked_cars[idx].car_num[4] = '\0';
				parked_cars[idx].entry_seconds = current_seconds;
				parked_cars[idx].valid = 1;

				LCD_clear();
				LCD_goto_XY(0, 0);
				LCD_write_string("CAR DETECTED");
				LCD_goto_XY(1, 0);
				LCD_write_string(parked_cars[idx].car_num);

				parking_state = calculate_parking_state();
				UART0_transmit('0' + parking_state);
				UART0_transmit('\n');
				_delay_ms(1000);
				waiting_displayed = 0;
				} else {
				// 만차
				parking_state = 0;
				UART0_transmit('0' + parking_state);
				UART0_transmit('\n');

				LCD_clear();
				LCD_goto_XY(0, 0);
				LCD_write_string("PARKING FULL");
				_delay_ms(1000);
				waiting_displayed = 0;
			}
		}

		// 2. 대기 표시
		else if (!new_car_ready && !waiting_displayed) {
			parking_state = calculate_parking_state();
			char buff[16];
			itoa(parking_state, buff, 10);

			LCD_clear();
			LCD_goto_XY(0, 0);
			LCD_write_string("CAR WAITING");
			LCD_goto_XY(1, 0);
			LCD_write_string("Available: ");
			LCD_write_string(buff);
			waiting_displayed = 1;
		}

		// 3. 출차 처리
		else if (exit_ready) {
			exit_ready = 0;
			uint8_t found = 0;

			// 차량번호 추출 (앞 4자리)
			char exit_num_only[5];
			strncpy(exit_num_only, exit_car_buf, 4);
			exit_num_only[4] = '\0';
			
			// 디버깅용 출력
			LCD_clear();
			LCD_goto_XY(0, 0);
			LCD_write_string("Exit Num:");
			LCD_write_string(exit_num_only);
			_delay_ms(500);

			for (int i = 0; i < MAX_CARS; i++) {
				if (parked_cars[i].valid && strncmp(exit_num_only, parked_cars[i].car_num, 4) == 0) {
					found = 1;
					
					// 디버깅용 출력
					LCD_clear();
					LCD_goto_XY(0, 0);
					LCD_write_string("Match Found:");
					LCD_write_string(parked_cars[i].car_num);
					_delay_ms(500);
					
					uint16_t duration = current_seconds - parked_cars[i].entry_seconds;
					uint16_t fee = duration * 10;

					char buf[16];
					LCD_clear();
					LCD_goto_XY(0, 0);
					LCD_write_string("EXIT:");
					LCD_write_string(exit_num_only);

					itoa(fee, buf, 10);
					LCD_goto_XY(1, 0);
					LCD_write_string("FEE:");
					LCD_write_string(buf);
					LCD_write_string(" Won");

					// 슬레이브 B로 duration, fee 전송
					char txbuf[20];
					itoa(duration, txbuf, 10);
					uint8_t len = strlen(txbuf);
					txbuf[len] = ',';
					itoa(fee, txbuf + len + 1, 10);
					len = strlen(txbuf);
					txbuf[len] = '\n';
					txbuf[len + 1] = '\0';

					for (uint8_t k = 0; txbuf[k] != 0; k++) {
						while (!(UCSR1A & (1 << UDRE1)));
						UDR1 = txbuf[k];
					}

					// 슬레이브 B에서 'D' 받을 때까지 대기
					uint32_t timeout = 0;
					while (!exit_done && timeout++ < 500000UL) {
						_delay_us(10);
					}

					if (exit_done) {
						exit_done = 0;
						parked_cars[i].valid = 0;
						memset(parked_cars[i].car_num, 0, 5);
						parked_cars[i].entry_seconds = 0;

						parking_state = calculate_parking_state();
						UART0_transmit('0' + parking_state);
						UART0_transmit('\n');

						LCD_clear();
						LCD_goto_XY(0, 0);
						LCD_write_string("EXIT DONE");
						exit_ready = 0;
						exit_done = 0;
						exit_index = 0;
						memset(exit_car_buf, 0, sizeof(exit_car_buf));

						_delay_ms(1000);
						waiting_displayed = 0;
					}else {
					// 타임아웃 발생했을 때 디버깅 출력
					LCD_clear();
					LCD_goto_XY(0, 0);
					LCD_write_string("EXIT TIMEOUT");
					_delay_ms(1000);
				}
					break;
				}
			}

			if (!found) {
				LCD_clear();
				LCD_goto_XY(0, 0);
				LCD_write_string("EXIT FAILED");
				LCD_goto_XY(1, 0);
				LCD_write_string("NOT FOUND");
				_delay_ms(1000);
				waiting_displayed = 0;
			}
		}
	}
}
