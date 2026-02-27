/*
 * segment_ex.c.c
 *
 * Created: 2025-04-21 오전 9:29:43
 * Author : me
 */ 

#define F_CPU 16000000L
#include <avr/io.h>
#include <util/delay.h>

#define Q0 PORTB.0
#define Q1 PORTB.1
#define Q2 PORTB.2
#define Q3 PORTB.3
#define FND PORTA

uint8_t numbers[] = {0xc0, 0xf9, 0xa4, 0xb0, 0x99, 0x92, 0x82, 0xd8, 0x80, 0x98, 0x88, 0x83, 0xc6, 0xa1, 0x86, 0x8e, 0x7f}; // 디스플레이에 표시될 숫자 0,1,2,3,...,F,'.' 을 HEX로 표현
uint8_t sel[] = {0b1110, 0b1101, 0b1011, 0b0111};
	
int main(void)
{
	
	PORTA = 0x00;
	DDRA = 0xff;
	DDRB = 0xff;

	uint8_t base = 0;
	uint8_t il = 0;
	uint8_t sip = 0;
	uint8_t back = 0;
	uint8_t chun = 0;
	int t1 = 40;
	
	  while (1)
	  {	
		  if (base < 10) {
			  il = base;
			  sip = 0;
			  back = 0;
			  chun = 0;
			  } else if (base < 100) {
			  il = base % 10;
			  sip = base / 10;
			  back = 0;
			  chun = 0;
			  } else if (base < 1000) {
			  il = base % 10;
			  sip = (base / 10) % 10;
			  back = base / 100;
			  chun = 0;
			  } else if (base < 10000) {
			  il = base % 10;
			  sip = (base / 10) % 10;
			  back = (base / 100) % 10;
			  chun = base / 1000;
		  }
		   
		  for (int t = 0; t < t1; t++) {
			  for (int i = 0; i < 4; i++) {
				  switch (i) {
					  case 0:
					  PORTA = sel[0];
					  PORTB = numbers[il];
					  break;
					  case 1:
					  PORTA = sel[1];
					  PORTB = numbers[sip];
					  break;
					  case 2:
					  PORTA = sel[2];
					  PORTB = numbers[back];
					  break;
					  case 3:
					  PORTA = sel[3];
					  PORTB = numbers[chun];
					  break;
				  }
				  _delay_us(50);
			  }
		  }
		  base++;
	  }
}
