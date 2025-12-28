// 슬레이브 B

// 출차 코드

#define F_CPU 16000000UL
#include <avr/io.h>
#include <avr/interrupt.h>
#include <util/delay.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>

// LCD 관련 정의
#define PORT_DATA      PORTA
#define PORT_CONTROL   PORTG
#define DDR_DATA       DDRA
#define DDR_CONTROL    DDRG
#define RS_PIN         0
#define RW_PIN         1
#define E_PIN          2

#define TRIG_PIN PE4
#define ECHO_PIN PE5

// ---- 세그먼트 배열과 로직은 기존 그대로 ----
const unsigned char fnd[10] = {0xc0,0xf9,0xa4,0xb0,0x99,0x92,0x82,0xf8,0x80,0x90};

char input[5] = {0};
uint8_t input_len = 0;

volatile uint16_t parking_minutes = 0;
volatile uint16_t parking_fee = 0;
volatile uint8_t payment_ready = 0;

volatile uint16_t timer_start = 0;
volatile uint16_t timer_end = 0;
volatile uint8_t echo_flag = 0;

// UART1 초기화
void UART1_init(void) {
	UBRR1H = 0;
	UBRR1L = 103; // 9600bps 기준 (F_CPU = 16MHz)
	UCSR1B = (1 << TXEN1) | (1 << RXEN1) | (1 << RXCIE1); // 송신, 수신, 인터럽트 활성화
	UCSR1C = (1 << UCSZ11) | (1 << UCSZ10); // 8-bit data
}

// UART1 단일 문자 송신
void UART1_send_char(char data) {
	while (!(UCSR1A & (1 << UDRE1))); // 송신 버퍼가 빌 때까지 대기
	UDR1 = data;
}

// UART1 문자열 송신
void UART1_send_string(const char *str) {
	while (*str) UART1_send_char(*str++);
}

// LCD
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
	LCD_write_command(0x01);
	_delay_ms(2);
}
void LCD_init(void) {
	_delay_ms(50);
	DDR_DATA = 0xFF;
	PORT_DATA = 0x00;
	DDR_CONTROL |= (1 << RS_PIN) | (1 << RW_PIN) | (1 << E_PIN);
	PORT_CONTROL &= ~(1 << RW_PIN);
	_delay_ms(50);
	LCD_write_command(0x38);
	LCD_write_command(0x0C);
	LCD_clear();
	LCD_write_command(0x06);
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

// 초음파
void ultrasonic_init(void) {
	DDRE |= (1 << TRIG_PIN);
	DDRE &= ~(1 << ECHO_PIN);
	PORTE |= (1 << ECHO_PIN);
	TCCR1B |= (1 << CS11);
}
void trigger_pulse(void) {
	PORTE |= (1 << TRIG_PIN);
	_delay_us(10);
	PORTE &= ~(1 << TRIG_PIN);
}
uint16_t measure_distance(void) {
	echo_flag = 0;
	TCNT1 = 0;
	trigger_pulse();

	uint32_t timeout = 0;
	while (!(PINE & (1 << ECHO_PIN))) {
		if (timeout++ > 48000) return 999;
	}
	uint16_t start = TCNT1;
	timeout = 0;
	while (PINE & (1 << ECHO_PIN)) {
		if (timeout++ > 48000) return 999;
	}
	uint16_t end = TCNT1;

	uint16_t pulse;
	if (end >= start) pulse = end - start;
	else pulse = (65535 - start) + end;

	return (pulse * 0.5) / 58;
}

// ---- 세그먼트 표시 함수: PORTD → PORTB, PORTC → PORTF ----
void Disp_Fnd_input() {
	for (int i = 0; i < 4; i++) {
		PORTF = 0xFF; // 모든 자릿수 비활성화
		_delay_us(10);
		if (i < input_len && input[i] >= '0' && input[i] <= '9')
		PORTB = fnd[input[i] - '0'];
		else
		PORTB = 0xFF;
		PORTF = ~(0x08 >> i); // 해당 자릿수 활성화
		_delay_ms(2);
	}
}

// ---- 키패드 함수: PORTF/PINF → PORTC/PINC ----
#define Key_data_input PINC
#define Key_data_output PORTC

int KeyMatrix() {
	PORTF = 0xFF; // 세그먼트 자릿수 비활성화
	unsigned keyout = 0xfe;
	for (int i = 0; i < 4; i++) {
		Key_data_output = keyout;
		_delay_us(50);
		switch (Key_data_input & 0xf0) {
			case 0xe0: return i;
			case 0xd0: return 4 + i;
			case 0xb0: return 8 + i;
			case 0x70: return 12 + i;
		}
		keyout = (keyout << 1) | 0x01;
	}
	return -1;
}
char mapKey(int key) {
	switch (key) {
		case 15: return 'D';
		case 7:  return 'E';
		case 3:  return 'C';
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

// UART1 수신 인터럽트
ISR(USART1_RX_vect) {
	static char buf[16];
	static uint8_t idx = 0;
	char data = UDR1;

	if (data == '\n') {
		buf[idx] = 0;
		char *token = strtok(buf, ",");
		if (token) parking_minutes = atoi(token);
		token = strtok(NULL, ",");
		if (token) parking_fee = atoi(token);
		payment_ready = 1;
		idx = 0;
		} else {
		if (idx < 15) buf[idx++] = data;
	}
}

// 정수→문자열 변환 함수
void int_to_str(uint16_t num, char *buf) {
	char tmp[6];
	int i = 0, j = 0;
	if(num == 0) {
		buf[0] = '0'; buf[1] = 0; return;
	}
	while(num > 0) {
		tmp[i++] = (num % 10) + '0';
		num /= 10;
	}
	for(j = 0; j < i; j++) buf[j] = tmp[i-j-1];
	buf[j] = 0;
}

int main(void) {
	// ---- 포트 설정: 요청한 부분만 변경 ----
	DDRB = 0xFF;  // 7-segment 데이터 (PORTB)
	PORTB = 0xFF;
	DDRF = 0x0F;  // 7-segment 자릿수 (PORTF)
	PORTF = 0xFF;
	DDRC = 0x0F;  // 키패드 (PORTC)
	PORTC = 0xF0; // 키패드 상위 4비트 풀업

	DDR_DATA = 0xFF;
	DDR_CONTROL |= (1 << RS_PIN) | (1 << RW_PIN) | (1 << E_PIN);
	LCD_init();
	ultrasonic_init();
	UART1_init();
	sei();

	memset(input, 0, sizeof(input));
	input_len = 0;

	char prev_key = 0;

	while (1) {
		LCD_clear();
		LCD_goto_XY(0, 0);
		LCD_write_string("Exit System     ");
		LCD_goto_XY(1, 0);
		LCD_write_string("Ready...        ");
		_delay_ms(500);

		while (1) {
			for (int repeat = 0; repeat < 15; repeat++) {
				Disp_Fnd_input();
			}
			if (measure_distance() < 10) break;
		}

		LCD_clear();
		LCD_goto_XY(0, 0);
		LCD_write_string("Input car num   ");
		LCD_goto_XY(1, 0);
		LCD_write_string("on Keypad...    ");
		memset(input, 0, sizeof(input));
		input_len = 0;

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
					} else if (key == 'D') {
					if (input_len > 0) {
						input[--input_len] = 0;
					}
					} else if (key == 'E') {
					if (input_len == 4) {
						for (uint8_t j = 0; j < input_len; j++) {
							UART1_send_char(input[j]);
						}
						UART1_send_char('\n');

						LCD_clear();
						LCD_goto_XY(0, 0);
						LCD_write_string("Waiting master..");
						LCD_goto_XY(1, 0);
						LCD_write_string("for fee info    ");

						uint16_t wait = 0;
						while (!payment_ready && wait++ < 2000) {
							_delay_ms(1);
						}

						LCD_clear();
						if (payment_ready) {
							char buf1[8], buf2[8];
							LCD_goto_XY(0, 0);
							LCD_write_string("Time: ");
							int_to_str(parking_minutes, buf1);
							LCD_write_string(buf1);
							LCD_write_string(" min");

							LCD_goto_XY(1, 0);
							LCD_write_string("Fee: ");
							int_to_str(parking_fee, buf2);
							LCD_write_string(buf2);
							LCD_write_string(" won");

							LCD_goto_XY(1, 13);
							LCD_write_string("Pay");
							while (1) {
								int k2 = KeyMatrix();
								char key2 = 0;
								if (k2 != -1) key2 = mapKey(k2);
								if (key2 == 'E') {
									// 여기에 차량번호 + 결제 완료 신호 전송!
									for (uint8_t j = 0; j < input_len; j++) {
										UART1_send_char(input[j]);
									}
									UART1_send_char(',');    // 구분자
									UART1_send_char('D');    // Done 신호
									UART1_send_char('\n');   // 끝
									break;
								}
								_delay_ms(50);
							}

							LCD_clear();
							LCD_goto_XY(0, 0);
							LCD_write_string("Payment done    ");
							LCD_goto_XY(1, 0);
							LCD_write_string("Thanks!         ");
							_delay_ms(2000);
							payment_ready = 0;
							} else {
							LCD_goto_XY(0, 0);
							LCD_write_string("No master resp. ");
							LCD_goto_XY(1, 0);
							LCD_write_string("Try again later ");
							_delay_ms(2000);
						}
						memset(input, 0, sizeof(input));
						input_len = 0;
						prev_key = 0;
						break;
					}
				}
				} else if (!key) {
				prev_key = 0;
			}
		}
	}
}

