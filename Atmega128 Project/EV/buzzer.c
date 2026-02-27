/*
 * buzzer.c
 *
 * Created: 2025-09-04 오후 2:45:27
 *  Author: me
 */ 
#include <avr/io.h>
#include <util/delay.h>
#include "buzzer.h"
#define BUZZER_OUT PORTB
#define BUZZER_DDR DDRB
#define BUZZER PB7
void timer1_init(void)
{
	TCCR1A = 0x82;
	TCCR1B = 0x1B;
	TCCR1C = 0x00;
	TCNT1 = 0;
	ICR1 = 0;
	OCR1C = 0;
}
void buzzer_out(unsigned char buz)
{
	unsigned int frequency_table[4] = { 0, 506, 568, 716 };
	ICR1 = frequency_table[buz];
	OCR1C = ICR1 / 2;
}
void buzzer_init(void)
{
	BUZZER_DDR = 1 << BUZZER;
	BUZZER_OUT |= 1 << BUZZER;
	timer1_init();
}