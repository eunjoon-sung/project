`timescale 1ns / 1ps

module tb_UART_Rx_fsm;

    reg clk;
    reg rst;
    reg rx;
    wire [7:0] rx_data;
    wire tx_start;
    wire rw_bit;
    wire [6:0] to_tx;

    UART_Rx_fsm u_UART_Rx_fsm(
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .rx_data(rx_data),
        .tx_start(tx_start),
        .rw_bit(rw_bit),
        .to_tx(to_tx)
    );

    // 16 MHz clock (62.5 ns period)
    initial clk = 0;
    always #31.25 clk = ~clk; // half period 31.25ns

    parameter CLK_PERIOD_NS = 62.5;
    parameter BAUD_DIV = 104; // DUT 내부 설정과 맞춤
    parameter BIT_PERIOD = BAUD_DIV * CLK_PERIOD_NS * 16; // 약 104 * 62.5ns(비트 1개 지속 시간)
	
	initial begin
		$dumpfile("tb_UART_Rx_fsm.vcd");
		$dumpvars(0, tb_UART_Rx_fsm);
	end
    initial begin
        rst = 1; rx = 1; #(BIT_PERIOD / 100);
        rst = 0; #(BIT_PERIOD / 100);

        // UART frame transmit (one bit per BIT_PERIOD)
        
      // READ TEST
        rx = 0; #(BIT_PERIOD); // start bit
        rx = 1; #(BIT_PERIOD); // RW bit

        // addr bits 0 1 0
        rx = 0; #(BIT_PERIOD);
        rx = 1; #(BIT_PERIOD);
        rx = 0; #(BIT_PERIOD);

        // data bits 1 0 1 0
        rx = 1; #(BIT_PERIOD);
        rx = 0; #(BIT_PERIOD);
        rx = 1; #(BIT_PERIOD);
        rx = 0; #(BIT_PERIOD);

        // parity bit 0
        rx = 0; #(BIT_PERIOD);

        // stop bit 1
        rx = 1; #(BIT_PERIOD);

        #(BIT_PERIOD);
        
      // WRITE TEST
        rx = 0; #(BIT_PERIOD); // start bit
        rx = 0; #(BIT_PERIOD); // RW bit
        
        // addr bits 1 1 0
        rx = 1; #(BIT_PERIOD);
        rx = 1; #(BIT_PERIOD);
        rx = 0; #(BIT_PERIOD);

        // data bits 1 1 0 1
        rx = 1; #(BIT_PERIOD);
        rx = 1; #(BIT_PERIOD);
        rx = 0; #(BIT_PERIOD);
        rx = 1; #(BIT_PERIOD);

        // parity bit 1
        rx = 1; #(BIT_PERIOD);

        // stop bit 1
        rx = 1; #(BIT_PERIOD);
        
        
        $finish;
    end

endmodule
