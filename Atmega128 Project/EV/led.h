/*
 * led.h
 *
 * Created: 2025-09-04 오후 2:51:15
 *  Author: me
 */ 


 #ifndef __LED_H
 #define __LED_H
 #define LED1 0x01
 #define LED2 0x02
 #define LED3 0x04
 #define LED4 0x08
 #define LED5 0x10
 #define LED_OFF 0x1F
 
 void led_light(unsigned char led);
 void led_init(void);
 #endif // __LED_H