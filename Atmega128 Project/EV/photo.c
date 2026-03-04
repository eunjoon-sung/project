 #include <avr/io.h>
 #include <util/delay.h>
 #include "photo.h"
 #define PHOTO_IN PINF
 #define PHOTO_DDR DDRF
 unsigned char photo_check(void)
 {
	 return (PHOTO_IN & 0x02);
 }
 void photo_init(void)
 {
	 PHOTO_DDR &= ~0x02;
 }