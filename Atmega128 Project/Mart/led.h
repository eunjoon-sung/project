/*
 * led.h
 *
 * Created: 2025-09-04 오후 3:22:17
 *  Author: me
 */ 
 #ifndef __LED_H
 #define __LED_H
 #define NONE 0x00
 #define RED 0x20
 #define GREEN 0x40
 #define YELLOW 0x80
 #define ALL 0xE0
 void led_light(unsigned char color);
 void led_init(void);
 #endif // __LED_H