/*
 * led.c
 *
 * Created: 2025-09-04 오후 2:51:00
 *  Author: me
 */ 
#include <avr/io.h>
#include <util/delay.h>
#include "led.h"
#define LED_OUT PORTG
#define LED_DDR DDRG
void led_light(unsigned char led)
{
	LED_OUT &= ~led;
}
void led_init(void)
{
	LED_DDR = 0x1F;
	LED_OUT = 0x1F;
}