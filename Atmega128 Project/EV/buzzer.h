/*
 * IncFile1.h
 *
 * Created: 2025-09-04 오후 2:45:55
 *  Author: me
 */ 

 #ifndef __BUZZER_H
 #define __BUZZER_H
 enum {
	 NONE,
	 BEEP,
	 DING,
	 DONG
 };

 void timer1_init(void);
 void buzzer_out(unsigned char buz);
 void buzzer_init(void);
 #endif // __BUZZER_H