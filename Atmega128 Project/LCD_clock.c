/*
 * LCD_clock.c
 *
 * LCD_ctrl 코드에 + Timer Interrupt 써서 시간 구현
 * Created: 2025-05-19 오전 10:40:36
 * Author : me
 */ 


#define F_CPU 16000000
#include <avr/io.h>
#include <util/delay.h>
#include <avr/interrupt.h>


#define PORT_DATA		PORTA		// 데이터 핀 연결 포트
#define PORT_CONTROL	PORTB		// 제어 핀 연결 포트
#define DDR_DATA		DDRA		// 데이터 핀의 데이터 방향
#define DDR_CONTROL		DDRB		// 제어 핀의 데이터 방향

#define RS_PIN			0		// RS 제어 핀의 비트 번호
#define RW_PIN			1		// R/W 제어 핀의 비트 번호
#define E_PIN			2		// E 제어 핀의 비트 번호

#define COMMAND_CLEAR_DISPLAY	0x01
#define COMMAND_8_BIT_MODE		0x38	// 8비트, 2라인, 5x8 폰트
#define COMMAND_4_BIT_MODE		0x28	// 4비트, 2라인, 5x8 폰트

#define COMMAND_DISPLAY_ON_OFF_BIT		2
#define COMMAND_CURSOR_ON_OFF_BIT		1
#define COMMAND_BLINK_ON_OFF_BIT		0

void LCD_pulse_enable(void) 		// 하강 에지에서 동작
{
	PORT_CONTROL |= (1 << E_PIN);	// E를 HIGH로
	_delay_us(1);
	PORT_CONTROL &= ~(1 << E_PIN);	// E를 LOW로
	_delay_ms(1);
}

void LCD_write_data(uint8_t data)
{
	PORT_CONTROL |= (1 << RS_PIN);	// 문자 출력에서 RS는 1
	PORT_DATA = data;			// 출력할 문자 데이터
	LCD_pulse_enable();			// 문자 출력
	_delay_ms(2);
}

void LCD_write_command(uint8_t command)
{
	PORT_CONTROL &= ~(1 << RS_PIN);	// 명령어 실행에서 RS는 0
	PORT_DATA = command;		// 데이터 핀에 명령어 전달
	LCD_pulse_enable();			// 명령어 실행
	_delay_ms(2);
}

void LCD_clear(void)
{
	LCD_write_command(COMMAND_CLEAR_DISPLAY);
	_delay_ms(2);
}

void LCD_init(void)
{
	_delay_ms(50);				// 초기 구동 시간
	
	// 연결 핀을 출력으로 설정
	DDR_DATA = 0xFF;
	PORT_DATA = 0x00;
	DDR_CONTROL |= (1 << RS_PIN) | (1 << RW_PIN) | (1 << E_PIN);

	// RW 핀으로 LOW를 출력하여 쓰기 전용으로 사용
	PORT_CONTROL &= ~(1 << RW_PIN);
	
	LCD_write_command(COMMAND_8_BIT_MODE);		// 8비트 모드
	
	// display on/off control
	// 화면 on, 커서 off, 커서 깜빡임 off
	uint8_t command = 0x08 | (1 << COMMAND_DISPLAY_ON_OFF_BIT);
	LCD_write_command(command);

	LCD_clear();				// 화면 지움

	// Entry Mode Set
	// 출력 후 커서를 오른쪽으로 옮김, 즉, DDRAM의 주소가 증가하며 화면 이동은 없음
	LCD_write_command(0x06);
}

void LCD_write_string(char *string)
{
	uint8_t i;
	for(i = 0; string[i]; i++)			// 종료 문자를 만날 때까지
	LCD_write_data(string[i]);		// 문자 단위 출력
}

void LCD_goto_XY(uint8_t row, uint8_t col)
{
	col %= 16;		// [0 15]
	row %= 2;		// [0 1]

	// 첫째 라인 시작 주소는 0x00, 둘째 라인 시작 주소는 0x40
	uint8_t address = (0x40 * row) + col;
	uint8_t command = 0x80 + address;
	
	LCD_write_command(command);	// 커서 이동
}

/////// 시계 계속 동작하게 하기위한 Timer Interrupt 설정 //////
volatile uint16_t count = 0;
volatile uint8_t sec = 0, min = 33, hour = 11;

ISR(TIMER0_COMP_vect) // Timer Compare Interrupt
{
	count++; // 인터럽트 발생할 때마다 count up
	if ((count % )  == 0){
		sec++;
		if (sec == 60){
			min++;
			sec = 0;
		}
		if (min == 60){
			hour++;
			min = 0;
			sec = 0;
		}
		if (hour == 24){
		hour = 0;
		min = 0;
		sec = 0;
		}
	}
	
	char hourStr[2];  // 두 자릿수 문자열을 위한 버퍼
	char minStr[2];
	char secStr[2];

	hourStr[0] = '0' + (hour / 10);  // 십의 자리
	hourStr[1] = '0' + (hour % 10);  // 일의 자리
	minStr[0] = '0' + (min / 10);  // 십의 자리
	minStr[1] = '0' + (min % 10);  // 일의 자리
	secStr[0] = '0' + (sec / 10);  // 십의 자리
	secStr[1] = '0' + (sec % 10);  // 일의 자리
	
	
	LCD_goto_XY(0, 0);			// 0행 0열로 이동
	LCD_write_data(hourStr[0]);			// 문자 단위 출력
	LCD_goto_XY(0, 1);
	LCD_write_data(hourStr[1]); // hour
	LCD_goto_XY(0, 2);
	LCD_write_data(':');
	LCD_goto_XY(0, 3);
	LCD_write_data(minStr[0]);
	LCD_goto_XY(0, 4);
	LCD_write_data(minStr[1]); // min
	LCD_goto_XY(0, 5);
	LCD_write_data(':');
	LCD_goto_XY(0, 6);
	LCD_write_data(secStr[0]); // sec
	LCD_goto_XY(0, 7);
	LCD_write_data(secStr[1]);
	

	TCNT0 = 0; // 타이머 카운터 초기화
}
void Timer_Compare_INT(void){
	
	TCCR0 |= (1 << CS02) | (1 << CS01) | (1 << CS00); // 분주비 1024로 설정 (1 1 1)
	TIMSK |= (1 << OCIE0); // 비교일치 interrupt 허용
	OCR0 = 128; // 비교일치 기준 값. 65ns * 1024 = 66us >> 128번 했을 때 비교기 1번 카운트 됨
	// 16MHz => T = 65ns, 65ns * 1024 (분주비) = 66560ns = 66us * 128 (OCR 값) = 8448us * 128 (비교일치 횟수)= 1082ms = 1s

	sei(); // 전역적 인터럽트 비트 set하려면 sei() 함수 사용
}


int main(void)
{
	LCD_init();					// 텍스트 LCD 초기화
	
	LCD_write_string("Clock");	// 문자열 출력
	
	_delay_ms(500);	
	
	LCD_clear();				// 화면 지움
	
	// 화면에 보이는 영역은 기본값으로 0~1행, 0~15열로 설정되어 있다.
	Timer_Compare_INT();
	

	while(1);
	return 0;
}
