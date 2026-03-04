//입차 Slave A 수정본

#define F_CPU 16000000UL
#include <avr/io.h>
#include <avr/interrupt.h>
#include <util/delay.h>
#include <stdint.h>
#include <string.h>

// LCD 관련 정의
#define PORT_DATA      PORTA
#define PORT_CONTROL   PORTG
#define DDR_DATA       DDRA
#define DDR_CONTROL    DDRG
#define RS_PIN         0
#define RW_PIN         1
#define E_PIN          2

#define COMMAND_CLEAR_DISPLAY   0x01
#define COMMAND_8_BIT_MODE      0x38

// 초음파 센서 핀 정의
#define TRIG_PIN PE4
#define ECHO_PIN PE5

// 7-segment(액티브 로우)
const unsigned char fnd[10] = {0xc0,0xf9,0xa4,0xb0,0x99,0x92,0x82,0xf8,0x80,0x90};

// 차량번호 입력 저장 (최대 4자리)
char input[5] = {0};
uint8_t input_len = 0;

// 주차 자리 상태 (1:비어있음, 0:차있음)
volatile uint16_t parking_state = 0xFF; // 8자리 모두 비어있음(1111 1111)

// 초음파 측정용 변수
volatile uint16_t timer_start = 0;
volatile uint16_t timer_end = 0;
volatile uint8_t echo_flag = 0;

// ------------------- UART0 송신 함수 -------------------
void UART0_init(void) {
	UBRR0H = 0;
	UBRR0L = 103; // 16MHz, 9600bps
	UCSR0B = (1 << TXEN0) | (1 << RXEN0) | (1 << RXCIE0); // 송신(TXEN0)과 수신(RXEN0) 모두 활성화
	UCSR0C = (1 << UCSZ01) | (1 << UCSZ00);
}
void UART0_send_char(char data) {
	while (!(UCSR0A & (1 << UDRE0)));
	UDR0 = data;
}
void UART0_send_string(const char *str) {
	while (*str) UART0_send_char(*str++);
}

// ------------------- UART0 수신 함수 -------------------
uint8_t UART0_receive(void) {
	while (!(UCSR0A & (1 << RXC0))); // UART0 수신 완료 대기
	return UDR0;                       // UART0 수신 버퍼에서 데이터 반환
}

//---------------- UART0 interrupt 함수 -----------------
volatile uint8_t master_parking_state = 0; // 마스터로부터 받은 최신 주차 상태
volatile uint8_t parking_state_updated = 0; // 새 상태가 수신되었음을 알리는 플래그

ISR(USART0_RX_vect) {
	char data = UDR0;
		
	if (data >= '0' && data <= '8') { // '0'에서 '8' 사이의 숫자인지 확인 (남은 자리 수)
		master_parking_state = data - '0'; // ASCII를 숫자로 변환
		} else if (data == '\n') { 
		parking_state_updated = 1;
	}
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
void LCD_show_parking_state() {
	LCD_goto_XY(1, 0);
	for (int i = 7; i >= 0; i--) {
		if (parking_state & (1 << i))
		LCD_write_data('1');
		else
		LCD_write_data('0');
		LCD_write_data(' ');
	}
}
uint8_t is_full() {
	return (parking_state == 0x00);
}

// ------------------- LED 함수 -------------------
void update_leds() {
	PORTB = ~parking_state; // 각 비트가 LED에 그대로 반영됨 (LOW일 때 켜짐)
}

// ------------------- 초음파 함수 -------------------
void ultrasonic_init(void) {
	DDRE |= (1 << TRIG_PIN);    // TRIG 출력
	DDRE &= ~(1 << ECHO_PIN);   // ECHO 입력

	// INT5 인터럽트 설정 (상승 에지 감지)
	EICRB |= (1 << ISC51) | (1 << ISC50);
	EIMSK |= (1 << INT5);

	// 타이머1 설정: 분주비 8 (1 tick = 0.5us)
	TCCR1B |= (1 << CS11);
}
void trigger_pulse(void) {
	PORTE |= (1 << TRIG_PIN);
	_delay_us(10);
	PORTE &= ~(1 << TRIG_PIN);
}
ISR(INT5_vect) {
	if (echo_flag == 0) {
		timer_start = TCNT1;
		EICRB &= ~(1 << ISC50);   // 하강 에지 감지로 변경
		echo_flag = 1;
		} else if (echo_flag == 1) {
		timer_end = TCNT1;
		EICRB |= (1 << ISC50);    // 다시 상승 에지 감지로 변경
		echo_flag = 2;
	}
}
uint16_t measure_distance(void) {
	echo_flag = 0;
	TCNT1 = 0;
	trigger_pulse();

	uint32_t timeout = 0;
	while (echo_flag < 2 && timeout < 30000) {
		timeout++;
	}

	if (echo_flag < 2) {
		return 999;  // 오류 시 큰 값 반환
	}

	uint16_t pulse = timer_end - timer_start;
	uint16_t distance_cm = pulse / 58;  // 거리 계산

	return distance_cm;
}

// ------------------- 7-segment 함수 -------------------
void Disp_Fnd_input() {
	int dnum[4] = { -1, -1, -1, -1 };
	for (int i = 0; i < input_len; i++) {
		dnum[3 - i] = input[i] - '0'; // 입력값을 오른쪽부터 채움
	}
	for (int i = 0; i < 4; i++) {
		PORTC = ~(0x01 << i); // i=0: 오른쪽, i=3: 왼쪽
		if (dnum[i] >= 0 && dnum[i] <= 9)
		PORTD = fnd[dnum[i]];
		else
		PORTD = 0xFF;
		_delay_ms(2);
	}
}

// ------------------- 키패드 함수 -------------------
#define Key_data_input PINF
#define Key_data_output PORTF

int KeyMatrix() {
	unsigned keyout = 0xfe;
	for (int i = 0; i < 4; i++) {
		Key_data_output = keyout;
		_delay_us(50);
		switch (Key_data_input & 0xf0) {
			case 0xe0: return i;      // 첫 행
			case 0xd0: return 4 + i;  // 둘째 행
			case 0xb0: return 8 + i;  // 셋째 행
			case 0x70: return 12 + i; // 넷째 행
		}
		keyout = (keyout << 1) | 0x01;
	}
	return -1;
}
char mapKey(int key) {
	switch (key) {
		case 15: return 'D'; // 지우기
		case 7:  return 'E'; // 확인
		case 3:  return 'C'; // 미사용(X)
		case 12: return '7';
		case 13: return '8';
		case 14: return '9';
		case 8:  return '4';
		case 9:  return '5';
		case 10: return '6';
		case 4:  return '1';
		case 5:  return '2';
		case 6:  return '3';
		case 1:  return '0';
		default: return 0;
	}
}

// ------------------- 메인 함수 -------------------
int main(void) {
	// 7-segment, DIGIT 포트 출력
	DDRD = 0xFF; PORTD = 0xFF;
	DDRC = 0x0F; PORTC = 0x0F;

	// 키패드 포트 설정 (하위 4비트 출력, 상위 4비트 입력)
	DDRF = 0x0F;
	PORTF = 0xF0;

	// LED 포트 설정
	DDRB = 0xFF;
	PORTB = 0xFF;

	ultrasonic_init();
	sei();
	LCD_init();
	UART0_init(); // ★ UART0 초기화

	memset(input, 0, sizeof(input));
	input_len = 0;

	char prev_key = 0;

	update_leds();

	while (1) {
		// 주차 자리 업데이트
		if (parking_state_updated) {
			parking_state_updated = 0; // 플래그 초기화
			uint8_t occupied_count = 8 - master_parking_state; // 차있는 자리 수
			uint16_t new_calculated_parking_state = 0xFF; // 초기화: 모두 비어있음 (1)
			for (int i = 0; i < occupied_count; i++) {
				new_calculated_parking_state &= ~(1 << (7 - i)); // 7, 6, 5... 순서로 0으로 만듦
			}
			parking_state = new_calculated_parking_state; // 최종 비트맵으로 업데이트

			update_leds(); // LED 상태 업데이트

			// LCD에 업데이트된 상태 표시 (선택 사항)
			LCD_clear();
			LCD_goto_XY(0, 0);
			LCD_write_string("Parking update");
			LCD_goto_XY(1, 0);
			// parking_state (uint8_t)를 문자열로 변환하여 표시
			char buf[2];
			itoa(master_parking_state, buf, 10);
			LCD_write_string("Avail: ");
			LCD_write_string(buf);
			_delay_ms(1000); // 잠시 표시
		}
		// 만차라면 안내 메시지 및 LED 깜빡임
		if (is_full()) {
			LCD_clear();
			LCD_goto_XY(0, 0);
			LCD_write_string("Parking Full!   ");
			LCD_goto_XY(1, 0);
			LCD_write_string("No more space   ");
			for (int repeat = 0; repeat < 15; repeat++)
			PORTD = 0xFF;

			for (int i = 0; i < 4; i++) {
				PORTB = 0xFF; // 모두 ON
				_delay_ms(200);
				PORTB = 0x00; // 모두 OFF
				_delay_ms(200);
			}
			PORTB = 0xFF; // 만차 상태에서 모두 OFF 유지

			while (is_full()) {
				if (parking_state_updated) {
					break; // 플래그가 1이 되면 이 루프를 빠져나가 바깥쪽 if로 이동
				}
			}
			_delay_ms(500); // 지연 중에도 플래그 확인 필요
		}

		// 1. 입차 대기
		LCD_clear();
		LCD_goto_XY(0, 0);
		LCD_write_string("Ready for entry ");
		LCD_goto_XY(1, 0);
		LCD_write_string("Please wait...  ");

		while (1) {
			for (int repeat = 0; repeat < 15; repeat++) {
				Disp_Fnd_input();
			}
			if (measure_distance() < 10) break;
			if (parking_state_updated) {
				break; // 플래그가 1이 되면 이 루프를 빠져나가 바깥쪽 if로 이동
			}
			if (is_full()) break;
		}
		if (is_full()) continue;

		// 2. 차량 감지됨 → 자리상태 표시
		LCD_clear();
		LCD_goto_XY(0, 0);
		LCD_write_string("Parking LOT A   ");
		LCD_show_parking_state();
		_delay_ms(2000);

		// 3. 차량번호 입력 안내
		LCD_clear();
		LCD_goto_XY(0, 0);
		LCD_write_string("Input car num   ");
		LCD_goto_XY(1, 0);
		LCD_write_string("on keypad...    ");
		memset(input, 0, sizeof(input));
		input_len = 0;

		// 4. 차량번호 입력(4자리) + 확인('E')
		while (1) {
			for (int repeat = 0; repeat < 15; repeat++) {
				Disp_Fnd_input();
			}
			char key = 0;
			int k = KeyMatrix();
			if (k != -1) key = mapKey(k);

			if (key && key != prev_key) {
				prev_key = key;
				if (key >= '0' && key <= '9') {
					if (input_len < 4) {
						input[input_len++] = key;
					}
					} else if (key == 'D') { // 지우기
					if (input_len > 0) {
						input[--input_len] = 0;
					}
					}else if (key == 'E') {
					if (input_len == 4) {
						// 입차 처리: parking_state의 왼쪽부터 1을 0으로
						for (int i = 7; i >= 0; i--) {
							if (parking_state & (1 << i)) {
								parking_state &= ~(1 << i);
								update_leds();

								// ★ 차량번호 4글자만 전송
								for (uint8_t j = 0; j < input_len; j++) {
									UART0_send_char(input[j]);
								}
								// 필요하다면 개행문자('\n') 추가 가능(마스터가 무시함)
								// UART0_send_char('\n');

								// ★★★ 반드시 아래를 추가 ★★★
								memset(input, 0, sizeof(input));
								input_len = 0;
								prev_key = 0;

								break;
							}
						}
						// 자리상태 2초간 표시
						LCD_clear();
						LCD_goto_XY(0, 0);
						LCD_write_string("Parking LOT A   ");
						LCD_show_parking_state();
						_delay_ms(2000);
						break;
					}
				}
				} else if (!key) {
				prev_key = 0;
			}
			if (parking_state_updated) {
				break; // 플래그가 1이 되면 이 루프를 빠져나가 바깥쪽 if로 이동
			}
			if (is_full()) break;
		}
	}
}

