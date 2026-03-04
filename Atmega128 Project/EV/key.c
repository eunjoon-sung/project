/*
 * key.c
 *
 * Created: 2025-09-04 오후 2:53:37
 *  Author: me
 */ 
#include <avr/io.h>
#include <util/delay.h>
#include "key.h"
#define KEY_OUT PORTD
#define KEY_IN PINE
#define KEY_ODDR DDRD
#define KEY_IDDR DDRE

volatile char key_flag;

unsigned char getkey(unsigned char keyin)
{
	unsigned char key;
	key_flag = 0;
	KEY_OUT &= ~0x10;
	_delay_us(10);
	key = ~KEY_IN & 0xF0;
	if( key ) {
		_delay_ms(5);
		key = ~KEY_IN & 0xF0;
		if( key ) {
			if( key == 0x10 ) key = KEY_IN1;
			else if( key == 0x20 ) key = KEY_IN2;
			else if( key == 0x40 ) key = KEY_IN3;
			else if( key == 0x80 ) key = KEY_IN4;
		}
	}
	else {
		KEY_OUT &= ~0x20;
		_delay_us(10);
		key = ~KEY_IN & 0xF0;
		if( key ) {
			_delay_ms(5);
			key = ~KEY_IN & 0xF0;
			if( key ) {
				if( key == 0x10 ) key = KEY_IN5;
				else if( key == 0x20 ) key = KEY_CLOSE;
				else if( key == 0x40 ) key = KEY_OPEN;
				else if( key == 0x80 ) key = KEY_EMERGENCY;
			}
		}
		else {
			KEY_OUT &= ~0x40;
			_delay_us(10);
			key = ~KEY_IN & 0xF0;
			if( key ) {
				_delay_ms(5);
				key = ~KEY_IN & 0xF0;
				if( key ) {
					if( key == 0x10 ) key = KEY_TITLE;
					else if( key == 0x20 ) key = KEY_OUT1;
					else if( key == 0x40 ) key = KEY_OUT2;
					else if( key == 0x80 ) key = KEY_OUT3;
				}
			}
			else {
				KEY_OUT &= ~0x80;
				_delay_us(10);
				key = ~KEY_IN & 0xF0;
				if( key ) {
					_delay_ms(5);
					key = ~KEY_IN & 0xF0;
					if( key ) {
						if( key == 0x10 ) key = KEY_OUT4;
						else if( key == 0x20 ) key = KEY_OUT5;
						else if( key == 0x40 ) key = KEY_UP;
						else if( key == 0x80 ) key = KEY_DOWN;
					}
				}
			}
		}
	}
	if( key && (key != keyin) ) key_flag = 1;
	return key;
}
 void key_init(void)
 {
	 KEY_ODDR |= 0xF0;
	 KEY_OUT |= 0xF0;
	 KEY_IDDR &= 0xF0;
	 PORTE |= 0xF0;
  }