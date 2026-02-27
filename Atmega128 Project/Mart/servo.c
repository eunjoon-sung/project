/*
 * servo.c
 *
 * Created: 2025-09-04 오후 3:23:25
 *  Author: me
 */ 
 #include <avr/io.h>
 #include <avr/interrupt.h>
 #include <util/delay.h>

 #define SERVO_OUT PORTB
 #define SERVO_DDR DDRB
 #define SERVO 0x80
 #define SERVO_PERIOD 200
 
  volatile unsigned char servo_angle, servo_count;
  
  ISR(TIMER2_OVF_vect)
  {
	  TCNT2 = 256 - 25;
	  servo_count = ++servo_count % SERVO_PERIOD;
	  if( servo_count < servo_angle ) SERVO_OUT |= SERVO;
	  else SERVO_OUT &= ~SERVO;
  }
  void timer2_init(void)
  {
	  TCCR2 = 0x03;
	  TCNT2 = 256 - 25;
	  TIMSK |= 0x40;
  }
  void servo_spin(unsigned char angle)
  {
	  if( angle == 0 ) servo_angle = 6;
	  else if( angle == 90 ) servo_angle = 15;
	  else if( angle == 180 )servo_angle = 24;
  }
  void servo_init(void)
  {
	  timer2_init();
	  SERVO_DDR |= 0x80;
	  servo_count = 0;
	  servo_spin(0);
  }
