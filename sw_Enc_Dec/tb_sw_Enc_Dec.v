`timescale 1ns / 1ps

module tb_sw_Enc_Dec();
    reg sw1;
    reg sw0;
    reg [3:0] in;
    reg clk;
    wire [3:0] out;
        
    always #10 clk = ~clk;
    
    initial begin
    clk = 0;
    sw1=0;
    sw0=0;
    in = 4'b0000;
    
    #1000;
    
    #20; @(posedge clk);  sw1 =1; sw0 = 0; 
    #20; in = 4'b0001;
    #20; in = 4'b0010;
    #20; in = 4'b0100;
    #20; in = 4'b1000;
    #20; in = 4'b0000;

    #20; @(posedge clk);  sw1 =0; sw0 = 1; 
    #20; in = 4'b0000;
    #20; in = 4'b0001;
    #20; in = 4'b0010;
    #20; in = 4'b0011;
    #20; in = 4'b0000;
    
    #20; @(posedge clk);  sw1 =1; sw0 = 1; 
    #20; @(posedge clk);  sw1 =0; sw0 = 0; 
    #20;
    $finish;

    end

    //call DUT
    sw_Enc_Dec u_sw_Enc_Dec(
    .sw1(sw1), .sw0(sw0), .in(in), .clk(clk), .out(out)
    );

endmodule
