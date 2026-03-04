/*
 * key.h
 *
 * Created: 2025-09-04 오후 3:17:08
 *  Author: me
 */ 

#ifndef __KEY_H
#define __KEY_H
#define KEY_1 '1'
#define KEY_2 '2'
#define KEY_3 '3'
#define KEY_4 '4'
#define KEY_5 '5'
#define KEY_6 '6'
#define KEY_7 '7'
#define KEY_8 '8'
#define KEY_9 '9'
#define KEY_0 '0'
#define KEY_PLUS 1
#define KEY_ENTER 2
#define KEY_MENU 3
#define KEY_CHANGE 4
#define KEY_LOBBY 5
unsigned char getkey(unsigned char keyin);
void key_init(void);
#endif // __KEY_H