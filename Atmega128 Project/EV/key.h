/*
 * key.h
 *
 * Created: 2025-09-04 오후 2:56:41
 *  Author: me
 */ 

#ifndef __KEY_H
#define __KEY_H
#define KEY_IN1 1
#define KEY_IN2 2
#define KEY_IN3 3
#define KEY_IN4 4
#define KEY_IN5 5
#define KEY_CLOSE 21
#define KEY_OPEN 22
#define KEY_EMERGENCY 23
#define KEY_TITLE 24
#define KEY_OUT1 11
#define KEY_OUT2 12
#define KEY_OUT3 13
#define KEY_OUT4 14
#define KEY_OUT5 15
#define KEY_UP 25
#define KEY_DOWN 26
unsigned char getkey(unsigned char keyin);
void key_init(void);
#endif // __KEY_H
