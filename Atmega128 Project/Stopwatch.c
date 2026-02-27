/*
 * Stopwatch.c
 *

 7segment 사용
 _ . / _ _ . / _ (분/ 초 / 0.1초)
 버튼 2개 한 개는 UP, 한번 더 누르면 STOP. 한 개는 Clear
 
 * Created: 2025-05-12 오후 2:36:26
 * Author : me
 */ 

#define F_CPU 16000000L
#include <avr/io.h>
#include <avr/interrupt.h>
#include <util/delay.h>
#define Q0 PORTA.0
#define Q1 PORTA.1
#define Q2 PORTA.2
#define Q3 PORTA.3

uint8_t sel[] = {0b1110, 0b1101, 0b1011, 0b0111};
uint8_t numbers[] = {0xc0, 0xf9, 0xa4, 0xb0, 0x99, 0x92, 0x82, 0xd8, 0x80, 0x98, 0x88, 0x83, 0xc6, 0xa1, 0x86, 0x8e, 0x7f};
	
static int state = 0;
static int count = 0;
static int msec=0;
static int sec=0;
static int min=0;
// INT0, INT1 은 PD2 PD3 에 연결
void INIT_INT0(void){
	EIMSK |= ( 1 << INT0); //INT0 인터럽트 활성화
	EICRA |= ( 1 << ISC01); // 하강 엣지에서 인터럽트 발생
	sei(); //전역 인터럽트 허용
}

ISR(INT0_vect){ // INT0 external interrupt
	
	state = !state; // 상태 토글
}

void INIT_INT1(void){
	EIMSK |= ( 1 << INT1); //INT1 인터럽트 활성화
	EICRA |= ( 1 << ISC01); // 하강 엣지에서 인터럽트 발생
	sei(); //전역 인터럽트 허용
}

ISR(INT1_vect){ // INT1 external interrupt : Clear
	msec = 0;
	sec = 0;
	min = 0;	
}

void chattering(void){
	
	
}


ISR(TIMER0_COMP_vect) // Timer Compare Interrupt
{	
	if (state == 0) return; // state 0 일 경우 아무것도 안함: stop 상태
	
	count++; // 인터럽트 발생할 때마다 count up
	
	if ((count % 12) == 0)
		msec++;
		if (msec == 10){
			sec++;
			msec = 0;
		}
		if (sec == 60)
		{
			min++;
			sec = 0;
		}
		if (min == 10)
		{
			msec = 0;
			sec = 0;
			min = 0;
		}

	TCNT0 = 0; // 타이머 카운터 초기화	
}

void Compare_INT(void){
	
	TCCR0 |= (1 << CS02) | (1 << CS01) | (1 << CS00); // 분주비 1024로 설정 (1 1 1)
	
	TIMSK |= (1 << OCIE0); // 비교일치 interrupt 허용
	OCR0 = 128; // 비교일치 기준 값. 65ns * 1024 = 66us >> 128번 했을 때 비교기 1번 카운트 됨
    // 16MHz => T = 65ns, 65ns * 1024 (분주비) = 66560ns = 66us * 128 (OCR 값) = 8448us * 64 (비교일치 횟수)= 541ms = 0.5s

	sei();
}

void Display(int msec, int sec, int min){ // 7segment 출력
	uint8_t display[]= {0xc0, 0xc0, 0xc0, 0xc0}; // display 0 0 0 0
	int a0 = msec; // msec 자리
	int a1 = sec % 10; // sec 1의 자리
	int a2 = (sec / 10) % 10; // sec 10의 자리
	int a3 = min;  // min 자리
	display[0] = numbers[a0];
	display[1] = numbers[a1]&0x7f; // 0Xff 가 다 꺼짐 이므로 dot은 0x7f임. 도 | 이 아니라 &로 해줘야함
	display[2] = numbers[a2];
	display[3] = numbers[a3]&0x7f;
	for(int repeat = 0; repeat <10; repeat++){
		for (int i = 0; i < 4; i++) {
			switch (i) {
				case 0:
				PORTA = sel[0];
				PORTB = display[0];
				break;
				case 1:
				PORTA = sel[1];
				PORTB = display[1];
				break;
				case 2:
				PORTA = sel[2];
				PORTB = display[2];
				break;
				case 3:
				PORTA = sel[3];
				PORTB = display[3];
				break;
			}
		}
	}
}

int main(void)
{
	DDRA = 0xFF;
	DDRB = 0xFF;  // PB0~7 핀을 출력으로 설정
	PORTA = 0xff; // 초기값 설정
	PORTB = 0xff;

	int display[]= {0xFF,0xFF,0xFF,0xFF}; // 0xFF 해야 아무것도 안켜짐
	
	INIT_INT0(); // Stopwatch ON/OFF
	INIT_INT1();  // CLEAR
	Compare_INT(); // 타이머 자체는 계속 켜두되, INT0 신호 받아서 시작/정지하게 만들기

	while(1){Display(msec, sec, min);}
	return 0;
}
