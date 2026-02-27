/*
 * Calculator.c
 *
 * Created: 2025-04-24 오후 21:44:51
 * Author : me
 */ 

 #define F_CPU 16000000L
 #include <avr/io.h>
 #include <util/delay.h>
 
 #define Q0 PORTB.0
 #define Q1 PORTB.1
 #define Q2 PORTB.2
 #define Q3 PORTB.3
 #define Key_data_input PINC
 #define Key_data_output PORTC
 
 uint8_t numbers[] = {0xc0, 0xf9, 0xa4, 0xb0, 0x99, 0x92, 0x82, 0xd8, 0x80, 0x98, 0x88, 0x83, 0xc6, 0xa1, 0x86, 0x8e, 0x7f};
 uint8_t sel[] = {0b1110, 0b1101, 0b1011, 0b0111};
 // 함수선언
 int KeyMatrix(void);
 int cal(int k);
 void Display(int op);
 
 int main(void)
 {
    DDRA = 0xff; // PORT A 설정, 출력으로 사용
    DDRB = 0xff;
    DDRC = 0x0f; // PORT C 설정, PORT 0123 출력 4567 입력으로 사용
    DDRD = 0xff;
     
    PORTA = 0xff; // port A 초기값 설정
    PORTB = 0xff;
    PORTC = 0x00;
    PORTD = 0xff;
    uint8_t k;
    uint8_t d =0;
    int prev_op = 0;
    int op = 0;
    int total = 0;
	int signal = 0; // -1 : minus, +1: plus, 0: turn off
	int display_val = 0;
     
        while (1)
        {
            k = KeyMatrix(); //입력 받기
            d = cal(k);
			switch(k){
				case 3: //clear
				prev_op = 0;
				op = 0;
				total = 0;
				signal = 0;
				display_val = 0;
				break;
				
				case 7: //enter
				if (signal == 1)
					total += prev_op;
				else if(signal == -1)
					total -= prev_op;
				display_val = total;
				prev_op =0;
				op=0;
				signal =0;
				break;
				
				case 11: //minus
				if (signal == 0 && prev_op != 0){ //-만 수정필요. 처음 값을 빼버리면 안됨
					total = prev_op;
					}
				else{
					total -= prev_op;
					}
				op = 0;
				signal = -1;
				display_val = total;
				break;
				
				case 15: //plus
				total += prev_op;
				signal = 1;
				op = 0;
				display_val = total;
				break;
			
				case 30: // 입력 X
				break;
				
				default: // 입력 o
				op = (10 * op) + d;
				prev_op = op;
				display_val = op;
				break;
			}
			if (op> 9999){
				op = 0;
				prev_op = 0;
				display_val = 0;
			}
			Display(display_val);
			d = 0 ;
		}
 }
 
 // 스위치 입력 받기
 int KeyMatrix()
 {
	 int keyout = 0xfe;
	 static int prev_key = -1;
	 static uint8_t released = 1;

	 for (int i = 0; i < 4; i++) {
		 Key_data_output = keyout;
		 _delay_ms(1);

		 int curr_key = -1;

		 switch (Key_data_input & 0xf0) {
			 case 0xe0: curr_key = 0 + i; break;
			 case 0xd0: curr_key = 4 + i; break;
			 case 0xb0: curr_key = 8 + i; break;
			 case 0x70: curr_key = 12 + i; break;
		 }

		 if (curr_key != -1) {
			 if (released) {
				 released = 0;
				 prev_key = curr_key;
				 return curr_key;
			 }
			 } else if (i == 3 && prev_key != -1) {  // 모든 열을 다 돌고 나서만 released 처리
			 released = 1;
			 prev_key = -1;
		 }

		 keyout = (keyout << 1) | 0x01;
	 }
	 return 30;
 }

 // 계산기 숫자 매핑
 int cal(int k)
 {
     switch (k){
         case 3: //3 clear
         return 16; break;
         case 4:
         return 1; break;
         case 5:
         return 2; break;
         case 6:
         return 3; break;
         case 7: // enter
         return 16; break;
         case 8:
         return 4; break;
         case 9:
         return 5; break;
         case 10:
         return 6; break;
         case 11: // minus
         return 16; break;
         case 12:
         return 7; break;
         case 13:
         return 8; break;
         case 14:
         return 9; break;
         case 15: // plus
         return 16; break;
         default:
         return 0; break;
     }
 }

 // 디스플레이 출력 함수
void Display(int op){
    uint8_t display[]= {0xc0, 0xc0, 0xc0, 0xc0}; // display 출력값
    int a0 = op % 10; // 1의 자리
    int a1 = (op / 10) % 10; //  10의 자리
    int a2 = (op / 100) % 10; // 100의 자리
    int a3 = (op / 1000) % 10;  // 1000의 자리
    display[0] = numbers[a0];
    display[1] = numbers[a1];
    display[2] = numbers[a2];
    display[3] = numbers[a3];
	for(int repeat = 0; repeat <8; repeat++){
		for (int i = 0; i < 4; i++) {
			switch (i) {
				case 0:
				PORTA = sel[0];
				PORTB = display[0];
				break;
				case 1:
				PORTA = sel[1];
				PORTB = display[1];
				break;
				case 2:
				PORTA = sel[2];
				PORTB = display[2];
				break;
				case 3:
				PORTA = sel[3];
				PORTB = display[3];
				break;
			}
		_delay_us(2000); // 깜빡임 방지를 위해 delay 늘릴 수도 있음
		}
	}
}
