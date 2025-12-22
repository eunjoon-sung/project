`timescale 1ns / 1ps

module tb_UART_Tx_fsm;

    // Testbench signals
    reg clk;
    reg rst;
    reg tx_start;
    reg [7:0] to_tx;
    wire tx_out;
    wire busy;

    // Instantiate the Design Under Test (DUT)
    // DUT: The module you want to test
    UART_Tx_fsm tb_UART_Tx_fsm(
        .tx_start(tx_start),
        .to_tx(to_tx),
        .clk(clk),
        .rst(rst),
        .tx_out(tx_out),
        .busy(busy)
    );

    // Clock Generation
    // A clock with a period of 10ns (100MHz) for simulation purposes
    always #5 clk = ~clk;

    // Stimulus Generation
    initial begin
        // Initialize all signals
        clk = 0;
        rst = 1;
        tx_start = 0;
        to_tx = 8'b0;

        // Apply reset for a short period
        #10 rst = 0;

        // Monitor key signals for debugging
        $monitor("Time=%0t, rst=%b, clk=%b, tx_start=%b, to_tx=%h, busy=%b, tx_out=%b",
                 $time, rst, clk, tx_start, to_tx, busy, tx_out);

        // --- Test Case 1: Send a single byte (8'h55) ---
        #20;
        $display("-----------------------------------------");
        $display("Sending byte: 8'h55");
        to_tx = 8'h55;
        tx_start = 1;

        // Wait for one clock cycle to let FSM capture the start signal
        @(posedge clk);
        tx_start = 0;

        // Wait until transmission is complete (busy flag goes low)
        @(negedge busy);
        $display("Transmission of 8'h55 completed.");
        #10;

        // --- Test Case 2: Send another byte (8'hAA) immediately after ---
        $display("-----------------------------------------");
        $display("Sending byte: 8'hAA");
        to_tx = 8'hAA;
        tx_start = 1;
        @(posedge clk);
        tx_start = 0;
        @(negedge busy);
        $display("Transmission of 8'hAA completed.");
        #10;

        // --- Test Case 3: Send a third byte with a short delay ---
        $display("-----------------------------------------");
        $display("Sending byte: 8'hF0");
        to_tx = 8'hF0;
        tx_start = 1;
        @(posedge clk);
        tx_start = 0;
        @(negedge busy);
        $display("Transmission of 8'hF0 completed.");
        #10;
        $display("-----------------------------------------");
        $display("Simulation finished.");

        // End of simulation
        $finish;
    end
endmodule
