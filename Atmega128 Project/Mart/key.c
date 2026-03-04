/*
 * key.c
 *
 * Created: 2025-09-04 오후 3:16:29
 *  Author: me
 */ 
 #include <avr/io.h>
 #include <util/delay.h>
 #include "key.h"
 #define KEY_OUT PORTD
 #define KEY_IN PIND
 #define KEY_DDR DDRD
 
 volatile char key_flag;
 
 unsigned char getkey(unsigned char keyin)
 {
	 unsigned char key;
	 key_flag = 0;
	 
	 KEY_OUT = ~0x01;
	 _delay_us(10);
	 key = ~KEY_IN & 0xF0;
	 if( key ) {
		 _delay_ms(5);
		 key = ~KEY_IN & 0xF0;
		 if( key ) {
			 if( key == 0x10 )
			 key = KEY_1;
			 else if( key == 0x20 ) key = KEY_2;
			 else if( key == 0x40 ) key = KEY_3;
			 else if( key == 0x80 ) key = KEY_PLUS;
		 }
	 }
	 else {
		 KEY_OUT = ~0x02;
		 _delay_us(10);
		 key = ~KEY_IN & 0xF0;
		 if( key ) {
			 _delay_ms(5);
			 key = ~KEY_IN & 0xF0;
			 if( key ) {
				 if( key == 0x10 )
				 key = KEY_4;
				 else if( key == 0x20 ) key = KEY_5;
				 else if( key == 0x40 ) key = KEY_6;
				 else if( key == 0x80 ) key = KEY_ENTER;
			 }
		 }
		 else {
			 KEY_OUT = ~0x04;
			 _delay_us(10);
			 key = ~KEY_IN & 0xF0;
			 if( key ) {
				 _delay_ms(5);
				 key = ~KEY_IN & 0xF0;
				 if( key ) {
					 if( key == 0x10 )
					 key = KEY_7;
					 else if( key == 0x20 ) key = KEY_8;
					 else if( key == 0x40 ) key = KEY_9;
					 else if( key == 0x80 ) key = KEY_MENU;
				 }
			 }
			 else {
				 KEY_OUT = ~0x08;
				 _delay_us(10);
				 key = ~KEY_IN & 0xF0;
				 if( key ) {
					 _delay_ms(5);
					 key = ~KEY_IN & 0xF0;
					 if( key ) {
						 if( key == 0x10 )
						 key = KEY_0;
						 else if( key == 0x40 ) key = KEY_CHANGE;
						 else if( key == 0x80 ) key = KEY_LOBBY;
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
	  KEY_OUT = 0xF0;
	  KEY_DDR = 0x0F;
  }