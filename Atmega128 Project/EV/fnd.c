/*
 * fnd.c
 *
 * Created: 2025-09-04 오후 2:50:26
 *  Author: me
 */ 
 #include <avr/io.h>
 #include <avr/interrupt.h>
 #include <stdio.h>
 #include "Fnd.h"
 #define SEG_OUT PORTA
 #define SEG_DDR DDRA

 void fnd_out(unsigned char num)
 {
	 char segment[11] = {
		 0xC0, 0xF9, 0xA4, 0xB0, 0x99, 0x92, 0x82, 0xD8, 0x80, 0x90, 0xFF
	 };
	 SEG_OUT = segment[num];
 }
 void fnd_init(void)
 {
	 SEG_DDR = 0xFF;
	 fnd_out(10);
 }