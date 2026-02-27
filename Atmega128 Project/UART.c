// 통신 연결 확인을 위한 샘플 코드 (교수님 ver)
#define F_CPU 16000000L
#include <avr/io.h>
#include <util/delay.h>

#define Q0 PORTA.0
#define Q1 PORTA.1
#define Q2 PORTA.2
#define Q3 PORTA.3

uint8_t sel[] = {0b1110, 0b1101, 0b1011, 0b0111};
uint8_t numbers[] = {0xc0, 0xf9, 0xa4, 0xb0, 0x99, 0x92, 0x82, 0xd8, 0x80, 0x98, 0x88, 0x83, 0xc6, 0xa1, 0x86, 0x8e, 0x7f};

void UART1_init(void)
{
	UBRR1H = 0;
	UBRR1L = 207; // 207 = (F_CPU / (8 * 207)) - 1;
	
	UCSR1A |= _BV(U2X1);			// 2배속 모드
	
	UCSR1C |= 0x06; // 비동기, 8비트 데이터, 패리티 없음, 1비트 정지 비트 모드
	
	UCSR1B |= _BV(RXEN1);		// 송수신 가능
	UCSR1B |= _BV(TXEN1);
}

void UART1_transmit(char data)
{
	while( !(UCSR1A & (1 << UDRE1)) );	// 송신 가능 대기
	UDR1 = data;				// 데이터 전송
}

unsigned char UART1_receive(void)
{
	while( !(UCSR1A & (1<<RXC1)) );	// 데이터 수신 대기
	return UDR1;
}

int main(void)
{
	DDRA = 0xff; // PORT A 설정, 출력으로 사용
	DDRB = 0xff;
	PORTA = 0xff; // port A 초기값 설정
	PORTB = 0xff;

	
	UART1_init();
	unsigned int data_1 = 19;
	UART1_transmit(data_1);
	unsigned int received_data = UART1_receive();
	
	while(1)
	{
		if (received_data >= 0) {
			Display(received_data);  // 수신된 문자 ('0'~'9')를 숫자로 변환하여 출력
		}
		_delay_ms(1);  // 500ms 대기 (디스플레이 변경을 위해)

	}
	
	return 0;
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
	 for(int repeat = 0; repeat <7; repeat++){
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
