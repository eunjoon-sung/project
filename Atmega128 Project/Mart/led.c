/*
 * led.c
 *
 * Created: 2025-09-04 오후 3:21:57
 *  Author: me
 */ 
 #include <avr/io.h>
 #include <util/delay.h>
 #include "led.h"
 #define LED_OUT PORTA
 #define LED_DDR DDRA
 void led_light(unsigned char color)
 {
	 LED_OUT |= 0xE0;
	 if( color == RED )
	 LED_OUT &= ~RED;
	 else if( color == GREEN ) LED_OUT &= ~GREEN;
	 else if( color == YELLOW ) LED_OUT &= ~YELLOW;
	 else if( color == ALL ) LED_OUT &= ~ALL;
 }
 void led_init(void)
 {
	 LED_DDR |= 0xE0;
	 LED_OUT |= 0xE0;
 }