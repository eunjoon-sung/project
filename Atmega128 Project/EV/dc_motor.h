/*
 * dc_motor.h
 *
 * Created: 2025-09-04 오후 2:44:15
 *  Author: me
 */ 


#ifndef __DC_MOTOR_H
#define __DC_MOTOR_H
#define STOP 0
#define LEFT 0x20
#define RIGHT 0x40
void dcmotor_spin(char direction);
void dcmotor_init(void);
#endif // __DC_MOTOR_H