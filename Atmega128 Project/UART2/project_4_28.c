/*
 * project_4_28.c
 *
 * Created: 2025-04-28 오후 4:12:52
 * Author : me
 
	오늘 과제
	toggle switch 사용해서 상태 3개 만들기
	1. up- count 0~9999 1초에 하나씩 9999면 정지
	2. down- count 0~9999 0이면 정지
	3. blink 현재 상태에서 깜빡깜빡
	UART 이용해서 mode 1, mode 2, mode 3 출력 및 데이터 바뀌는거 출력하기
	7segment에서도 동일하게 출력하기
*/ 

#define F_CPU 16000000L
#include <avr/io.h>
#include <util/delay.h>

#define Q0 PORTA.0
#define Q1 PORTA.1
#define Q2 PORTA.2
#define Q3 PORTA.3

#define D7 PINC.7
#define D6 PINC.6
#define D5 PINC.5
#define D4 PINC.4

uint8_t sel[] = {0b1110, 0b1101, 0b1011, 0b0111};
uint8_t numbers[] = {0xc0, 0xf9, 0xa4, 0xb0, 0x99, 0x92, 0x82, 0xd8, 0x80, 0x98, 0x88, 0x83, 0xc6, 0xa1, 0x86, 0x8e, 0x7f};
void Display(int data_1); // 함수 선언

void UART1_init(void)
{
	UBRR1H = 0;
	UBRR1L = 207; // 207 = (F_CPU / (8 * 9600)) - 1;
	
	UCSR1A |= _BV(U2X1);		// 2배속 모드
	
	UCSR1C |= 0x06; // 비동기, 8비트 데이터, 패리티 없음, 1비트 정지 비트 모드
	
	UCSR1B |= _BV(RXEN1);		// 송수신 가능
	UCSR1B |= _BV(TXEN1);
}

void UART1_transmit(char result[])
{
	int i = 0;
	// NULL 문자가 나올 때까지 반복하여 전송
	while (result[i] != '\0') {
		while (!(UCSR1A & (1 << UDRE1)));  // 송신 가능 대기
		UDR1 = result[i];      // 데이터 전송 하나에 한개씩만. 
		i++;
	}
}
/*
unsigned char UART1_receive(void)
{
	while( !(UCSR1A & (1<<RXC1)) );	// 데이터 수신 대기
	return UDR1;
}
*/
/*
unsigned char int_char(int data_1)
{
	static unsigned char buffer[10]={'0'}; // 전역변수 지정

	buffer[0] = (data_1 % 10) + '0'; // 1의 자리
	buffer[1] = (data_1 / 10) % 10 + '0'; //  10의 자리
	buffer[2] = (data_1 / 100) % 10 + '0'; // 100의 자리
	buffer[3] = (data_1 / 1000) % 10 + '0';  // 1000의 자리
	buffer[4] = '\0';
	return buffer; // buffer의 주소가 반환. 이 방식은 리턴값이 제대로 안들어갔는지 hercules에 출력 X
}*/
void int_char(int data_1, char buffer[]) // 직접 result 배열 값을 변경하는 함수로 바꾸니 됨.
{
	buffer[0] = (data_1 % 10) + '0';         // 1의 자리
	buffer[1] = (data_1 / 10) % 10 + '0';    // 10의 자리
	buffer[2] = (data_1 / 100) % 10 + '0';   // 100의 자리
	buffer[3] = (data_1 / 1000) % 10 + '0';  // 1000의 자리
	buffer[4] = '\0';  // 문자열 종료
}
void reverse(char str[], char* result){
	int k = 0;
	int len = 0;
	while (str[k] != '\0') {  // 문자열 길이 계산
		len++;
		k++;
	}
	
	for (int i = 0; i < len; i++) {
		result[i] = str[len - i - 1]; // 배열을 역순으로 result에 넣기
	}
	result[len] = '\0';  // 문자열 종료 문자 추가
}

int main(void)
{
	DDRA = 0xff; // PORT A 설정, led select 신호로 사용
	DDRB = 0xff; // PORT B, LED 출력으로 사용
	DDRC = 0x00; // Toggle switch 연결
	PORTA = 0xff; // 초기값 설정
	PORTB = 0xff;
	PORTC = 0xFF;
	
	uint8_t mode=0;
	// PIN C-toggle switch 매핑
		
	UART1_init();
	unsigned int data_1 = 0;
	static char buffer[10]={'0'}; // 전역변수 지정
	static char result[10]={'0'}; // 전역변수 지정
	char null[] = {'\n', '\r', '\0'};
	
	
	while(1)
	{
		int display[]= {0xFF,0xFF,0xFF,0xFF}; // 0xFF 해야 아무것도 안켜짐
		if ((PINC & 0xFF) == 0b11101111) mode = 1;  // 증가
		if ((PINC & 0xFF) == 0b11011111) mode = 2;  // 감소
		if ((PINC & 0xFF) == 0b10111111) mode = 3;  // 깜빡
		
		switch (mode)
		{
			case 1: // 1. up- count 0~9999 1초에 하나씩 9999면 정지
			/*
			if (a == 1){
				char string[10]= "MODE 1";
				char string_1[10] = {'0'};
				reverse(string, string_1);
				UART1_transmit(string_1);
				UART1_transmit(null);
			} // mode 1 시작시 한번만 출력
			*/
			data_1 = (data_1 + 1) % 10000;
			int_char(data_1, buffer);
			reverse(buffer, result);
			UART1_transmit(result);
			UART1_transmit(null);
			break;
			
			case 2: // 2. down- count 0~9999 0이면 정지
			/*if (a == -1){
				char string[10]= "MODE 2";
				char string_1[10] = {'0'};
				reverse(string, string_1);
				UART1_transmit(string_1);
				UART1_transmit(null);
			}*/
			
			if (data_1 == 0)
				data_1 = 0;
			else
				data_1 -=1;
			int_char(data_1, buffer);
			reverse(buffer, result);
			UART1_transmit(result);
			UART1_transmit(null);
			break;
			
			case 3: // 3. blink 현재 상태에서 깜빡깜빡
			/*if (a == 0){
				char string[10]= "MODE 3";
				char string_1[10] = {'0'};
				reverse(string, string_1);
				UART1_transmit(string_1);
				UART1_transmit(null);
			}*/
			for (int i = 0; i < 15; i++) {
			PORTB = 0xFF; }
			_delay_ms(50);
			for (int i = 0; i < 15; i++) {
			Display(data_1); }
			_delay_ms(50);
			break;
			
			default:
			Display(data_1);
		}
		
		if (mode != 3){
			for(int i=0; i<20; i++){
			Display(data_1);
			_delay_us(10);}
		}
		mode = 0;
		char string[10]= {'0'};
		char string_1[10] = {'0'};
		
	}
	return 0;
}

// 디스플레이 출력 함수
void Display(int data_1){
	uint8_t display[]= {0xc0, 0xc0, 0xc0, 0xc0}; // display 출력값
	int a0 = data_1 % 10; // 1의 자리
	int a1 = (data_1 / 10) % 10; //  10의 자리
	int a2 = (data_1 / 100) % 10; // 100의 자리
	int a3 = (data_1 / 1000) % 10;  // 1000의 자리
	display[0] = numbers[a0];
	display[1] = numbers[a1];
	display[2] = numbers[a2];
	display[3] = numbers[a3];
	for(int repeat = 0; repeat <10; repeat++){
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
