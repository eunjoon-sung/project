/*
 * photo.c
 *
 * Created: 2025-09-04 오후 3:22:53
 *  Author: me
 */ 
 #include <avr/io.h>
 #include <util/delay.h>
 #include "photo.h"
 #define PHOTO_IN PINF
 #define PHOTO_DDR DDRF
 unsigned char photo_check(void)
 {
	 return (PHOTO_IN & 0x01);
 }
 void photo_init(void)
 {
	 PHOTO_DDR &= ~0x01;
 }
