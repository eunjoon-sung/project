// 문자열 보내기
// main.c
#define F_CPU 16000000L
#include <avr/io.h>
#include "UART1.c"

int main(void)
{
	UART1_init();				// UART1 초기화
	char str[] = "Test using UART1 Library";
	uint8_t num = 128;
	
	UART1_print_string(str); // 문자열 출력
	UART1_print_string("\n\r");
	
	UART1_print_1_byte_number(num); // 1바이트 크기 정수 출력
	UART1_print_string("\n\r");
	
	while(1)
	{
	}
	
	return 0;
}


