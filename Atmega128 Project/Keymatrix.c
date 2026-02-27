/*
 * Keymatrix.c.c
 *
 * Created: 2025-04-21 오후 2:44:51
 * Author : me
 */ 

#define F_CPU 16000000L
#include <avr/io.h>
#include <util/delay.h>

#define Q0 PORTB.0
#define Q1 PORTB.1
#define Q2 PORTB.2
#define Q3 PORTB.3
#define FndDisplay(cmd) PORTA = numbers[cmd];
#define Key_data_input PINC
#define Key_data_output PORTC

uint8_t numbers[] = {0xc0, 0xf9, 0xa4, 0xb0, 0x99, 0x92, 0x82, 0xd8, 0x80, 0x98, 0x88, 0x83, 0xc6, 0xa1, 0x86, 0x8e, 0x7f};
uint8_t sel[] = {0b1110, 0b1101, 0b1011, 0b0111};
 
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

	uint8_t base = 0;
	int k =0;
	int t1 = 40;
	int il;
	int sip;
		
		while (1)
		{
			k = KeyMatrix();
			if (k<10) {il = k; sip = 0;}
				if (k>=10) {il = k % 10; sip = k/10;}
			
			
			for (int t = 0; t < t1; t++) {
				for (int i = 0; i < 4; i++) {
					switch (i) {
						case 0:
						PORTA = sel[0];
						PORTB = numbers[k];
						break;
						case 1:
						PORTA = sel[1];
						PORTB = numbers[sip];
						break;
						case 2:
						PORTA = sel[2];
						PORTB = numbers[0];
						break;
						case 3:
						PORTA = sel[3];
						PORTB = numbers[0];
						break;
					}
					_delay_us(50); // 깜빡임 방지를 위해 delay 늘릴 수도 있음
				}
			}
			
		}	

}

//KEY Matrix 함수
int KeyMatrix()
{
	int keyout = 0xfe; // 키 매트릭스 신호 1111 1110
	
	for(int i = 0; i<4 ; i++)
	{
		Key_data_output = keyout; // Port C 에 1111 1110 출력 ( 0 4 8 C 즉 1열이 enable)
		_delay_ms(1);
		
        switch (Key_data_input & 0xf0) {
	        case 0xe0: return 0 + i;  // 첫 번째 행에서 키가 눌린 경우
	        case 0xd0: return 4 + i;  // 두 번째 행에서 키가 눌린 경우
	        case 0xb0: return 8 + i;  // 세 번째 행에서 키가 눌린 경우
	        case 0x70: return 12 + i; // 네 번째 행에서 키가 눌린 경우
        }

        // 다음 열로 이동
        keyout = (keyout << 1) | 0x01; // 1111 1110 -> 1111 1101 -> 1111 1011 -> 1111 0111
        
	}
	return 0;
}

