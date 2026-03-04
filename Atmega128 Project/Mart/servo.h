/*
 * servo.h
 *
 * Created: 2025-09-04 오후 3:24:25
 *  Author: me
 */ 

 #ifndef __SERVO_H
 #define __SERVO_H
 void timer2_init(void);
 void servo_spin(char angle);
 void servo_init(void);
 #endif // __SERVO_H