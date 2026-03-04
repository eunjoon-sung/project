/*
 * 3_MART.c
 *
 * Created: 2025-09-04 오후 3:15:14
 * Author : me
 */ 

 #include <avr/io.h>
 #include <avr/interrupt.h>
 #include <util/delay.h>
 #include <stdio.h>
 #include <string.h>
 #include "lcd.h"
 #include "key.h"
 #include "photo.h"
 #include "dc_motor.h"
 #include "servo.h"
 #include "led.h"
 extern volatile char key_flag;
 volatile unsigned char hour, minute, sec, tsec = 0;
 volatile unsigned long total_money;
 ISR(TIMER0_OVF_vect)
 {
	 TCNT0 = 256 - 250;
	 if( ++tsec == 250 ) {
		 tsec = 0;
		 if( ++sec == 60 ) {
			 sec = 0;
			 if( ++minute == 60 ) {
				 minute = 0;
				 if( ++hour == 24 ) hour = 0;
			 }
		 }
	 }
 }
void timer0_init(void)
{
	TCCR0 = 0x06;
	TCNT0 = 256 - 250;
	TIMSK |= 0x01;
}
void mcu_init(void)
{
	lcd_init();
	key_init();
	photo_init();
	dcmotor_init();
	servo_init();
	led_init();
	timer0_init();
	sei();
	total_money = 0;
}
void start_market(void)
{
	int i;
	lcd_gotoxy(0, 0);
	lcd_string("    MARKET	");
	lcd_gotoxy(0, 1);
	lcd_string("    SYSTEM	");
	dcmotor_spin(STOP);
	servo_spin(0);
	for( i = 0; i < 2; i++ ) {
		led_light(ALL);
		lcd_command_write(LCD_ON);
		_delay_ms(500);
		
		led_light(NONE);
		lcd_command_write(LCD_OFF);
		_delay_ms(500);
	}
	lcd_command_write(LCD_ON);
}
void init_screen(void)
{
	lcd_gotoxy(0, 0);
	lcd_string("  WELCOME!!   ");
	lcd_gotoxy(0, 1);
	lcd_string(" 08:00:00 ");
}
	 
#define INPUT_MODE 1
#define CHANGE_MODE 2
#define SEC_COUNT 3
	 
void calculate_mode(unsigned char key_in)
{
	unsigned char key = key_in, oldsec = 0;
	char belt_on, mode, sec_count;
	int i, j;
	unsigned char pos = 0, buf[10];
	unsigned long money, unit_money, num;
	led_light(RED);
	lcd_command_write(LCD_CLEAR);
	lcd_gotoxy(0, 0);
	lcd_string("Calculate Mode");
	servo_spin(0);
	belt_on = 1;
	money = 0;
	mode = INPUT_MODE;
	while( 1 ) {
		key = getkey(key);
		if( key_flag ) {
			switch( key ) {
				case KEY_0 :
				case KEY_1 :
				case KEY_2 :
				case KEY_3 :
				case KEY_4 :
				case KEY_5 :
				case KEY_6 :
				case KEY_7 :
				case KEY_8 :
				case KEY_9 :
					if( mode != NONE ) {
						if( (mode == INPUT_MODE && pos < 6) || (mode == CHANGE_MODE && pos < 10) )
						{
							if( pos == 0 && key == KEY_0 );
							else {
								lcd_gotoxy(pos, 1);
								lcd_data_write(key);
								buf[pos++] = key - '0';
							}
						}
					}
					break;
					  
				case KEY_PLUS :
					if( mode == INPUT_MODE ) {
						if( pos ) {
							unit_money = 0;
							for( i = 0; i < pos; i++ ) {
								num = 1;
								for( j = 0; j < i; j++ ) num *= 10;
								unit_money += buf[pos - i - 1] * num;
							}
							if( unit_money > 200000L ) {
								for( i = 0; i < 3; i++ ) {
									lcd_gotoxy(0, 1);
									lcd_string(" ERROR! ");
									_delay_ms(500);
									lcd_gotoxy(0, 1);
									lcd_string("      ");
									_delay_ms(500);
								}
								return;
							}
							money += unit_money;
						}
						belt_on = 1;
					}
					break;
				
				case KEY_ENTER :
					if( mode == INPUT_MODE ) {
						if( pos ) {
							unit_money = 0;
							for( i = 0; i < pos; i++ ) {
								num = 1;
								for( j = 0; j < i; j++ ) num *= 10;
								unit_money += buf[pos - i - 1] * num;
							}
							money += unit_money;
						}
						if( money ) {
							lcd_gotoxy(0, 1);
							printf("= %10ld won", money);
							total_money += money; // 문제 2
							money = 0; // 다음 계산 때 더해지는거 방지
							mode = NONE;
						}
					}
					else if( mode == CHANGE_MODE ) {
				/////////////////////////////////////////////////////////////////////////////////////////////
				// [문제 1] “요구사항 (4)-(바)”에서 ‘SW14(거스름돈)’를 누르면, "Changes Mode" 모드로 전환하여
				// 동작
				////////////////////////////////////////////////////////////////////////////////////////////
						if( pos ) {
							unit_money = 0;
							for (i = 0; i< pos ; i++){
								num = 1;
								for( j = 0; j < i; j++ ) num *= 10;
								unit_money += buf[pos - i - 1] * num;
							}
							money = unit_money - money; // 거스름돈
						}
						if( money ) {
							lcd_gotoxy(0, 1);
							printf("= %10ld won", money);
							servo_spin(90);
							mode = SEC_COUNT;
						} 
						else {
							lcd_gotoxy(0, 1);
							printf("     ");
							mode = CHANGE_MODE;
						}
					}
					break;
					
			case KEY_CHANGE :
				if( mode == NONE ) {
					led_light(GREEN);
					lcd_gotoxy(0, 0);
					lcd_string("Changes Mode	 ");
					lcd_gotoxy(0, 1);
					lcd_string("       ");
					pos = 0;
					mode = CHANGE_MODE;
				}
				break;
				
			case KEY_LOBBY :
				if( mode == SEC_COUNT ) servo_spin(0);
				return;
			}
		}
		
		if( belt_on ) {
			dcmotor_spin(RIGHT);
			_delay_ms(3000);
			dcmotor_spin(STOP);
			
			lcd_gotoxy(0, 1);
			lcd_string("		");
			pos = 0;
			belt_on = 0;
		}
	
		if( mode == SEC_COUNT ) {
			if( oldsec != sec ) {
				oldsec = sec;
				sec_count++;
				if( sec_count > 5 ) {
					servo_spin(0);
					return;
				}
			}
		}
	}
}
void total_sales(void)
{
	unsigned char oldsec, count;
	led_light(YELLOW);
	lcd_gotoxy(0, 0);
	lcd_string("Total Sales");
	lcd_gotoxy(0, 1);
	printf("= %10ld won", total_money);
	////////////////////////////////////////////////////////////////////////////////////////
	// [문제 2] “요구사항 (3)”상태에서 "SW2(2)"를 누르면 총 판매한 금액이 LCD에 출력되게 하시오.
	///////////////////////////////////////////////////////////////////////////////////////
}
void menu_screen(void)
{
	unsigned char key = KEY_MENU;
	lcd_gotoxy(0, 0);
	lcd_string("1: Calculation  ");
	lcd_gotoxy(0, 1);
	lcd_string("2: Total Sales  ");
	while( 1 ) {
		key = getkey(key);
		if( key_flag ) {
			switch( key ) {
				case KEY_1 :
				calculate_mode(key);
				return;
				case KEY_2 :
				total_sales();
				return;
				case KEY_LOBBY :
				return;
			}
		}
	}
}
int main(void)
{
	char oldsec = 0xff;
	unsigned char key = 0;
	mcu_init();
	fdevopen((void *)lcd_data_write, 0);
	start_market();
	init_screen();
	hour = 8;
	minute = 0;
	sec = 0;
	while( 1 ) {
		key = getkey(key);
		if( key_flag ) {
			if( key == KEY_MENU ) {
				menu_screen();
				init_screen();
				led_light(NONE);
			}
		}
		if( photo_check() == 1) {
			//////////////////////////////////////////////////////////////////////
			// [문제 3] “요구사항 (2)”의 상태에서 포토인터럽트에 물체가 감지되면, 
			// “Calculate Mode”로 전환되고,
			// “요구사항 (4)”의 “Calculate Mode”로 전환되어 동작되게 하시오.
			/////////////////////////////////////////////////////////////////////
			calculate_mode(0);
			led_light(NONE);           // LED OFF
		}
		if( oldsec != sec ) {
			oldsec = sec;
			lcd_gotoxy(4, 1);
			printf("%02d:%02d:%02d", hour, minute, sec);
		}
	}
	return 0;
}