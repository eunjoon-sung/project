// tb_Encoder_4x2.v
`timescale 1ns / 1ps

module tb_Encoder_4x2();
    reg [3:0]D;
    wire [1:0]B;
    reg clk;
    always #10 clk = ~clk;

    //------여기서 부터 아래 선까지는 waveform을 보기위한 파일을 만드는 코드이다.---- 
   initial
   begin
    $dumpfile("test_out.vcd");                // 출력할 VCD 파일 이름
	$dumpvars(0, tb_Encoder_4x2);             // 정확한 top module 이름을 넣기!
	$monitor("D=%b -> B=%b", D, B);           // 정확한 신호명을 넣기!
   end
   //------------------------------------------------------------------------------
	
    initial begin
    clk = 0; // clk 초기화 필요
    D = 4'b0000;
    
    @(posedge clk); D = 4'b0000;
    @(posedge clk); D = 4'b0010;
    @(posedge clk); D = 4'b0100;
    @(posedge clk); D = 4'b1000;
    #20;
    $finish;
    end

    //call DUT
    Encoder_4x2 u_Encoder_4x2(
    .D(D),.B(B)
    );
        
endmodule
