/*
 * Interrupt.c
 *
 * Created: 2025-05-12 오전 10:07:23
 * Author : me
 * 인터럽트 발생하면 led 출력이 반전되는 코드 짜기
 */
/*
#define F_CPU 16000000L
#include <avr/io.h>
#include <avr/interrupt.h>

ISR(INT0_vect) // 외부 인터럽트 INT0 의 Port 번호 : PD0 , ATmega Pin : 25
{
	static int state;
	state = (state + 1) % 2; // LED 상태전환
	if (state == 0)
		PORTB &= ~(1 << PB0);  // LED 끄기 (PB0 핀을 LOW로 설정)
	else 
		PORTB |= (1 << PB0);   // LED 켜기 (PB0 핀을 HIGH로 설정)
}
void INIT_INT0(void){
	
	EIMSK |= (1 << INT0); //INT0 interrupt 활성화
	EICRA |= (1 << ISC01); // falling edge에서 interrupt 발생
	sei(); // 전역적 인터럽트 비트 set하려면 sei() 함수 사용
}
int main(void)
{
	DDRD &= ~(1 << PD0); // DDRD가 1이면 출력 0이면 입력. 따라서 DDRD &= ~(1 << PD0);는 PD0 핀을 입력으로 설정하는 코드
	DDRB |= (1 << PB0);  // PB0 핀을 출력으로 설정
	
	INIT_INT0(); // main 함수에서는 인터럽트 함수를 호출하여 interrupt를 활성화만 시킴. 별도로 호출하진 않음
	while(1){}
	
	
}
 */


/*
 * Overflow Interrupt.c
 *
 * Created: 2025-05-12 오전 10:07:23
 * Author : me
 * 오버플로우 인터럽트 발생하면 led 출력이 반전되는 코드
 */

/* 
#define F_CPU 16000000L
#include <avr/io.h>
#include <avr/interrupt.h>

ISR(TIMER0_OVF_vect) // Timer Overflow Interrupt
{
	static int state = 0;
	state = (state + 1) % 2; // LED 상태전환
	if (state == 0)
	PORTB &= ~(1 << PB0);  // LED 끄기 (PB0 핀을 LOW로 설정)
	else
	PORTB |= (1 << PB0);   // LED 켜기 (PB0 핀을 HIGH로 설정)
	
}
void Overflow_INT(void){
	
	TCCR0 |= (1 << CS02) | (1 << CS01) | (1 << CS00); // 분주비 1024로 설정 (1 1 1)
	TIMSK |= (1 << TOIE0); // overflow interrupt 허용
	sei(); // 전역적 인터럽트 비트 set하려면 sei() 함수 사용
}
int main(void)
{
	DDRB |= (1 << PB0);  // PB0 핀을 출력으로 설정
	
	Overflow_INT(); // main 함수에서는 인터럽트 함수를 호출하여 interrupt를 활성화만 시킴. 별도로 호출하진 않음
	while(1){}
	return 0;
}
*/


/*
 * 비교 일치 Interrupt.c
 *
 * Created: 2025-05-12 오전 10:07:23
 * Author : me
 * 비교일치 OCR 값 설정해서 인터럽트 발생 시간 조절. 인터럽트 발생 시 led 출력이 반전되는 코드
 */ 
#define F_CPU 16000000L
#include <avr/io.h>
#include <avr/interrupt.h>

static int state = 0;
static int count = 0;
ISR(TIMER0_COMP_vect) // Timer Compare Interrupt
{	
	count++; // 인터럽트 발생할 때마다 count up
	if (count == 128){
		count = 0;
		state = !state;
		
		if (state == 0)
			PORTB &= ~(1 << PB0);  // LED 끄기 (PB0 핀을 LOW로 설정)
		else
			PORTB |= (1 << PB0);   // LED 켜기 (PB0 핀을 HIGH로 설정)	
			
	} // count가 64번이 되면 led state 반전
	
	 TCNT0 = 0; // 타이머 카운터 초기화
}
void Compare_INT(void){
	
	TCCR0 |= (1 << CS02) | (1 << CS01) | (1 << CS00); // 분주비 1024로 설정 (1 1 1)
	
	TIMSK |= (1 << OCIE0); // 비교일치 interrupt 허용
	OCR0 = 128; // 비교일치 기준 값. 65ns * 1024 = 66us >> 128번 했을 때 비교기 1번 카운트 됨
	
	sei(); // 전역적 인터럽트 비트 set하려면 sei() 함수 사용
}
int main(void)
{
	DDRB |= (1 << PB0);  // PB0 핀을 출력으로 설정
	
	Compare_INT(); // main 함수에서는 인터럽트 함수를 호출하여 interrupt를 활성화만 시킴. 별도로 호출하진 않음
	while(1){}
	return 0;
}
