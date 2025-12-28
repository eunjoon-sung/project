`timescale 1ns / 1ps

module UART_top(
    input wire clk_in,      // External input clock (e.g., 50MHz)
    input wire rx_in,       // Received data from external source
    output wire tx_out,     // Transmitted data to external source
    input wire rst,
    output wire [3:0] led_cmd // led control
    );
    parameter NUM_CYCLES_PER_BIT = 10417;
    
    wire clk_wiz_out;
    wire tx_start;
    wire [7:0] to_tx;
    wire busy;
    wire parity_error;
    wire rw_bit;
    wire [2:0] state;
    wire [3:0] bit_index;
    wire [7:0] rx_data;

    clk_wiz_0 clk_wiz_inst (
        .clk_in1(clk_in),       // Connect input clock
        .clk_out1(clk_wiz_out)
    );

    // UART RX module
    UART_Rx_fsm u_UART_Rx_fsm (
        .clk(clk_wiz_out),    // Use the 16MHz clock
        .rst(rst),
        .rx(rx_in),           // Input from external source
        .tx_start(tx_start),  // Output: Pulse to start transmission
        .rw_bit(rw_bit),            // Unconnected port, as its value is used internally
        .to_tx(to_tx),        // Output: Data to be transmitted
        .parity_error(parity_error),
        .state(state),
        .bit_index(bit_index),
        .rx_data(rx_data)
    );
    
    // UART TX module
    UART_Tx_fsm u_UART_Tx_fsm (
        .clk(clk_wiz_out),     // Use the 16MHz clock
        .rst(rst),
        .to_tx(to_tx),         // Input: Data from UART_Rx_fsm
        .tx_start(tx_start),   // Input: Pulse from UART_Rx_fsm
        .busy(busy),           // Output: Indicates TX is busy
        .tx_out(tx_out)        // Output to external source
    );
    
    // ILA
        ILA_0 u_ILA_0 (
        .clk        (clk_wiz_out),
        .probe0     (rx_in),
        .probe1     (to_tx),
        .probe2     (led_cmd),
        .probe3     (state), 
        .probe4     (tx_out)        
            );
            
    // LED Control
        led_control u_led_control (
        .rx_data(rx_data),
        .clk(clk_wiz_out),
        .rst(rst),
        .led_cmd(led_cmd)        
        );

endmodule
