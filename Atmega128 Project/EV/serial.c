/*
 * serial.c
 *
 * Created: 2025-09-04 오후 2:46:48
 *  Author: me
 */ 
 #include <avr/io.h>
 #include <util/delay.h>
 #include "serial.h"
 ////// 추가
 volatile unsigned char serial_flag = 0;
 volatile unsigned char serial_buf[20] = {0};
 //////
 void serial_transmit(unsigned char data)
 {
	 while( !( UCSR1A & (1 << UDRE1)) );
	 UDR1 = data;
 }
 void serial_string(char *str)
 {
	 while( *str ) serial_transmit(*str++);
 }
 unsigned char serial_receive(void)
 {
	 while ( !(UCSR1A & (1 << RXC1)) );
	 return UDR1;
 }
 void serial_init(unsigned int baudrate)
 {
	 UCSR1A = 0x00;
	 UCSR1B = 0x08;
	 UCSR1C = 0x06;
	 UBRR1H = baudrate >> 8;
	 UBRR1L = baudrate & 0x0FF;
 }
