/*
 * test1.c
 *
 * Created: 2025-04-14 오후 1:56:45
 * Author : me
 */ 

#include <avr/io.h>
//#include <mega128.h>
#include <util/delay.h>
#define F_CPU 16000000

int main(void)
{
    DDRA = 0xff; //porta 출력설정
	PORTA = 0x00; //porta = 0000 0000
	unsigned char led = 0X01;
	char direc = 0; //0은 상승 1은 하강
    while (1) 
    {
		PORTA = led;
		if (direc == 0){
			if(led == 0X80)
				direc = !direc;
			else{
			led = led <<1;
			_delay_ms(1000);
			}
		}

		else{
			if (led == 0x01)
				direc = !direc;
			else{
			led = led >>1;
			_delay_ms(1000);
			}
		}
		if (led == 0x01){
			direc = !direc;
		}
    }
}

