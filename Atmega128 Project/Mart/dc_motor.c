/*
 * dc_motor.c
 *
 * Created: 2025-09-04 오후 3:15:50
 *  Author: me
 */ 
#include <avr/io.h>
#include <util/delay.h>
#include "dc_motor.h"
#define DCMOTOR_OUT PORTA
#define DCMOTOR_DDR DDRA
void dcmotor_spin(char direction)
{
	DCMOTOR_OUT &= ~0x03;
	if( direction == LEFT ) DCMOTOR_OUT |= LEFT;
	else if( direction == RIGHT ) DCMOTOR_OUT |= RIGHT;
}
void dcmotor_init(void)
{
	DCMOTOR_DDR |= 0x03;
}