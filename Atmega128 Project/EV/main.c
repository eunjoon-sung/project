/*
 * 3_EV.c
 *
 * Created: 2025-09-04 오후 2:33:45
 * Author : me
 */ 

 #include <avr/io.h>
 #include <avr/interrupt.h>
 #include <avr/eeprom.h>
 #include <util/delay.h>
 #include <stdio.h>
 #include <string.h>
 #include "photo.h"
 #include "dc_motor.h"
 #include "buzzer.h"
 #include "serial.h"
 #include "var.h"
 #include "fnd.h"
 #include "led.h"
 #include "lcd.h"
 #include "key.h"
 #define MAX_FLOOR	 5
 #define READY	'R'
 #define CLOSE	'C'
 #define OPEN	'O'
 
 struct floor {
	 unsigned char in;
	 unsigned char out_up;
	 unsigned char out_down;
 };
 
  extern volatile char key_flag;
  extern volatile int weight;
  extern volatile unsigned char serial_flag, serial_buf[20];
  volatile unsigned char cur_floor, out_floor, elevator_dir, target_floor, updn;
  volatile unsigned char door_dir, door_state, door_flag;
  volatile unsigned char move_flag, move_tick, move_sec;
  volatile unsigned char warning_flag, warning_tick, emergency_flag, emergency_tick;
  volatile struct floor elevator[MAX_FLOOR];
  volatile char floor_title[5][15];
  
enum {
	UP = 1,
	DOWN
};

enum {
	FLOOR1 = 1,
	FLOOR2,
	FLOOR3,
	FLOOR4,
	FLOOR5
};

ISR(TIMER0_OVF_vect)
{
	TCNT1 = 256 - 250;
	if( move_flag ) {
		move_tick++;
		if( move_tick == 250 ) {
			move_tick = 0;
			move_sec++;
		}
	}
	if( warning_flag ) {
		if( ++warning_tick == 250 ) warning_tick = 0;
	}
	if( emergency_flag ) {
		if( ++emergency_tick == 250 ) emergency_tick = 0;
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
	photo_init();
	dcmotor_init();
	buzzer_init();
	serial_init(B9600);
	var_init();
	fnd_init();
	led_init();
	lcd_init();
	key_init();
	timer0_init();
}
 void variable_init(void)
 {
	 int i, j;
	 cur_floor = FLOOR1;
	 out_floor = 0;
	 updn = 0;
	 door_state = CLOSE;
	 door_dir = 0;
	 door_flag = 0;
	 elevator_dir = STOP;
	 target_floor = cur_floor;
	 move_flag = 0;
	 warning_flag = 0;
	 emergency_flag = 0;
	 memset(floor_title, 0x00, sizeof(floor_title));
	 if( eeprom_read_byte(0) == 107 ) {
		 for( i = 0; i < 5; i++ ) {
			 for( j = 0; j < 13; j++ ) floor_title[i][j] = eeprom_read_byte((0x10 * (i + 1)) + j);
		 }
	 }
	 memset((char *)elevator, 0, sizeof(elevator));
 }
  void start_elevator(void)
  {
	  led_light(LED_OFF);
	  lcd_gotoxy(0, 0);
	  lcd_string("Elevator System ");
	  lcd_gotoxy(0, 1);
	  lcd_string("Loading");
	  dcmotor_spin(LEFT);
	  fnd_out(1);
	  _delay_ms(1000);
	  lcd_data_write('!');
	  dcmotor_spin(STOP);
	  fnd_out(0);
	  _delay_ms(1000);
	  lcd_data_write('!');
	  dcmotor_spin(RIGHT);
	  fnd_out(1);
	  _delay_ms(1000);
	  dcmotor_spin(STOP);
  }
void init_screen(void)
{
	lcd_command_write(LCD_CLEAR);
	lcd_gotoxy(0, 0);
	printf("%1dF:%s", cur_floor, floor_title[cur_floor - 1]);
	lcd_gotoxy(0, 1);
	printf("W:%3dkg  %c ", weight, door_state);
	for( int i = 0; i < 5; i++ ) {
		if( elevator[i].in ) lcd_data_write(i + '1');
		else
		lcd_data_write(' ');
	}
}
void led_out(void)
{
	PORTG = 0xFF;
	for( int i = 0; i < 5; i++ ) {
		if( elevator[i].out_up || elevator[i].out_down ) led_light(0x01 << i);
	}
}
   
void floor_check(void)
{
	int i;
	if( cur_floor == FLOOR1 )
		elevator_dir = UP;
	else if( cur_floor == FLOOR5 ) 
		elevator_dir = DOWN;
			
	if( elevator_dir == UP ) {
		for( i = cur_floor; i < 5; i++ ) {
			if( elevator[i].in || elevator[i].out_up ) {
				target_floor = i + 1;
				updn = UP;
				break;
			}
		}
		if( i == 5 ) {
			for( i = 4; i > (cur_floor - 1); i-- ) {
				if( elevator[i].out_down ) {
					target_floor = i + 1;
					elevator_dir = UP;
					updn = DOWN;
					break;
				}
			}
			if( i == (cur_floor - 1) ) elevator_dir = DOWN;
		}
	}
	else if( elevator_dir == DOWN ) {
		for( i = (cur_floor - 1); i >= 0; i-- ) {
			if( elevator[i].in || elevator[i].out_down ) {
				target_floor = i + 1;
				updn = DOWN;
				break;
			}
		}
		if( i == -1 ) {
			for( i = 0; i < (cur_floor - 1); i++ ) {
				if( elevator[i].out_up ) {
					target_floor = i + 1;
					elevator_dir = DOWN;
					updn = UP;
					break;
				}
			}
			if( i == (cur_floor - 1) ) elevator_dir = UP;
		}
	}
}
	 
	void move_elevator(void)
	{
		if( !move_flag && !door_flag ) {
			if( elevator_dir ) {
				move_tick = 0;
				move_sec = 0;
				move_flag = 1;
			}
		}
		else if( move_flag && !door_flag ) {
			if( move_sec == 2 ) {
				move_sec = 0;
				if( elevator_dir == UP )
				cur_floor++;
				else if( elevator_dir == DOWN ) cur_floor--;
				if( cur_floor == target_floor ) {
					door_flag = 1;
					move_flag = 0;
				}
				init_screen();
				fnd_out(cur_floor);
			}
		}
	}
	void move_door(void)
	{
		if( !move_flag ) {
			move_tick = 0;
			move_sec = 0;
			door_dir = READY;
			door_state = CLOSE;
			move_flag = 1;
		}
		else {
			if( move_sec == 1 ) {
				if( door_dir == READY ) {
					move_tick = 0;
					move_sec = 0;
					door_dir = OPEN;
					door_state = OPEN;
					dcmotor_spin(LEFT);
					buzzer_out(DING);
				}
				else if( (door_dir == OPEN) || (door_dir == CLOSE) ) {
					if( move_tick >= 125 ) buzzer_out(DONG);
				}
			}
			else if( move_sec == 3 ) {
				if( door_dir == OPEN ) {
					move_tick = 0;
					move_sec = 0;
					door_dir = STOP;
					dcmotor_spin(STOP);
					buzzer_out(0);
				}
				else if( door_dir == STOP ) {
					if( door_state == OPEN ) {
						if( warning_flag ) move_sec = 0;
						else {
							move_tick = 0;
							move_sec = 0;
							door_dir = CLOSE;
							dcmotor_spin(RIGHT);
							buzzer_out(DING);
						}
					}
				}
				else if( door_dir == CLOSE ) {
					door_state = CLOSE;
					door_dir = STOP;
					dcmotor_spin(STOP);
					buzzer_out(NONE);
					elevator[cur_floor - 1].in = 0;
					if( (cur_floor == FLOOR1) || (cur_floor == FLOOR5) ) {
						elevator[cur_floor - 1].out_up = 0;
						elevator[cur_floor - 1].out_down = 0;
					}
					else {
						if( updn == UP ) elevator[cur_floor - 1].out_up = 0;
						else if( updn == DOWN ) elevator[cur_floor - 1].out_down = 0;
					}
					lcd_gotoxy(cur_floor + 10, 1);
					lcd_data_write(' ');
					led_out();
					door_flag = 0;
					move_flag = 0;
				}
			}
		}
		if( !warning_flag ) {
			lcd_gotoxy(9, 1);
			lcd_data_write(door_state);
		}
	}
	 
	void weight_check(void)
	{
		if( !warning_flag ) {
			////////////////////////////////////////////////////////////////////////////////
			// [문제 1] 무게 표시
			// (7) 가변저항(VR1)으로 무게를 입력받는다. 무게가 99kg을 초과할 시 99kg이하로
			//무게가 내려갈 때까지 “요구사항 (1)”에서 설정한 경보음이 1초 간격으로
			// 울리고, 모든 스위치가 HOLD 되고, 문은 열린 상태를 유지, LCD 두 번째 줄에는
			// 다음과 같이 'OVER WEIGHT!!!가 출력된다.
			///////////////////////////////////////////////////////////////////////////////
			 
		if( weight > 99 ) {
			lcd_gotoxy(0, 1);
			lcd_string("  OVER WEIGHT!!!  ");
			warning_flag = 1;
			warning_tick = 0;
		}
		}
		else {
				if (weight <= 99) {
					buzzer_out(NONE);
					init_screen();
					move_tick = 0;
					move_sec = 0;
					warning_flag = 0;
			}
		}
	}
	//////////////////////////////////////////////////////////////////////////////////////
	// [문제 2] 비상스위치 동작
	// (8) 엘리베이터가 이동하는 중에 ‘비상’ SW를 누르면 PC에서 ‘ESC’ 키를 누르기
	//전 까지 모든 스위치가 HOLD 되고 “요구사항 (1)”에서 설정한 경보음이 1초
	//간격으로 울리고 LCD 두 번째 줄에 다음과 같이 출력한다.
	//////////////////////////////////////////////////////////////////////////////////////
	void emergency(void)
	{
		if (serial_receive() == 0x1B)
		{
			buzzer_out(NONE);
			init_screen();
			emergency_flag = 0;
		}
	}

	////////////////////////////////////////////////////////////////////////////////////////
	// [문제 3] Title Set 동작
	// (9) 엘리베이터 문이 닫혀 있을 때 ‘TITLE SET’ 스위치를 누르고, PC의 키보드를
	// 이용하여 다음과 같이 실행되게 하시오. 단, ‘TITLE SET’ 스위치를 누르면
	// 모든 스위치 입력은 받을 수 없게 되고 5층까지 TITLE 입력 후 다시 작동되게 하시오.
	///////////////////////////////////////////////////////////////////////////////////////
	void title_set(void)
	{
		int i, j;
		unsigned char ch;
		serial_transmit('\f');
		serial_string(">>>  INPUT FLOOR TITLE\r\n\r\n");
		for( i = 0; i < 5; i++ ) {
			serial_transmit(i + 0x31);  // ASCII '1' ~ '5'
			serial_string("F : ");
			j = 0; // i 바뀔 때마다 j 초기화

			// PC로 부터 입력받기
			while( 1 ) {
				if( serial_flag ) {
					ch =  serial_receive(); // 한글자씩
					serial_flag = 0;
					
					if( ch == '\r' || j == 15) {
						floor_title[i][j] = '\0';
						break;
					}
					else floor_title[i][j++] = ch;
				}
			}
			serial_string("\r\n"); // 줄바꿈
		}
		eeprom_write_byte(0, 107);
		for (i = 0; i < 5; i++){
			for (j = 0; j < 15; j++) {
				eeprom_write_byte((0x10) * (i+1) + j, floor_title[i][j]);
			}
		}
		
		init_screen();
	}
	  
	int main(void)
	{
		unsigned char key = 0;
		
		mcu_init();
		variable_init();
		sei();
		
		fdevopen((void *)lcd_data_write, 0);
		
		var_start();
		start_elevator();
		
		init_screen();
		
		while( 1 ) {
			key = getkey(key);
			if( key_flag ) {
				switch( key ) {
					case KEY_IN1 :
					case KEY_IN2 :
					case KEY_IN3 :
					case KEY_IN4 :
					case KEY_IN5 :
						if( key != cur_floor ) {
							elevator[key - 1].in = 1;
							lcd_gotoxy(key + 10, 1);
							lcd_data_write(key + '0');
						}
						break;
					
					case KEY_OUT1 :
					case KEY_OUT2 :
					case KEY_OUT3 :
					case KEY_OUT4 :
					case KEY_OUT5 :
						if( (key - 10) != cur_floor )  out_floor = key;
						break;
						
					case KEY_CLOSE :
					if( (door_state == OPEN) && (door_dir == STOP) ) {
							move_tick = 0;
							move_sec = 0;
							door_dir = CLOSE;
							dcmotor_spin(RIGHT);
					}
					case KEY_OPEN :
					if( (door_state == OPEN) && (door_dir == CLOSE) ) {
						dcmotor_spin(STOP);
						
						move_tick = 250 - move_tick;
						move_sec = 2 - move_sec;
						
						door_dir = OPEN;
						dcmotor_spin(LEFT);
					}
					break;
					case  KEY_EMERGENCY :
						lcd_gotoxy(0, 1);
						lcd_string("  EMERGENCY!!!  ");
						
						serial_transmit('\f');
						serial_string(">>>  ALERT EMERGENCY!!!!!\r\n");
						
						emergency_tick = 0;
						emergency_flag = 1;
						break;
						
					case KEY_TITLE :
						if( (door_state == CLOSE) && (door_dir == STOP) ) title_set();
						break;
						
					case KEY_UP :
						if( out_floor ) {
							if( out_floor != KEY_OUT5 ) elevator[out_floor - 11].out_up = 1;
							out_floor = 0;
						}
						led_out();
						break;
						
					case KEY_DOWN :
						if( out_floor ) {
							if( out_floor != KEY_OUT1 ) elevator[out_floor - 11].out_down = 1;
							out_floor = 0;
						}
						led_out();
						break;
				}
			}
			else {
				if( key == KEY_OPEN ) {
					if( (door_state == OPEN) && (door_dir == STOP) ) {
						move_tick = 0;
						move_sec = 0;
					}
				}
			}
			
			floor_check();
			if( cur_floor != target_floor ) move_elevator();
			if( door_flag ) move_door();
			if( (door_state == OPEN) && (door_dir == STOP) ) weight_check();
			
			///////////
			if (warning_flag) {
				if (warning_tick == 0) buzzer_out(BEEP);  // 부저 켜기
			} else buzzer_out(NONE);
			//////////
			
			if( (door_state == OPEN) && (door_dir == CLOSE) ) {
				if( photo_check() ) {
					dcmotor_spin(STOP);
					
					move_tick = 250 - move_tick;
					move_sec = 2 - move_sec;
					
					door_dir = OPEN;
					dcmotor_spin(LEFT);
				}
			}
			
			////////////
			if( emergency_flag ) {
				emergency();
				
				if (emergency_tick == 0) buzzer_out(BEEP);
				else buzzer_out(NONE);
			}
			///////////
			
			fnd_out(cur_floor);
		}
		return 0;
	}