`timescale 1ns / 1ps

module tb_dc_motor();

    reg clk;
    reg inc;
    reg dec;
    reg rst;
    wire pwm_out;
    wire nsleep;
    
    always #0.01 clk = ~clk;
    
    initial begin
        $dumpfile("test_out.vcd");         // VCD 파일 지정
        $dumpvars(0, tb_dc_motor);         // 신호 덤프 시작
        $monitor("time=%0t inc=%b dec=%b pwm_out=%b", $time, inc, dec, pwm_out);

        rst =1;
        clk =0;
        inc =0;
        dec =0;
        #10;
        rst=0;
        #2000; inc =1;
        #4000; inc =0;
        #4000; dec =1;
        #4000; dec =0;
        
        #1000;
        $finish;
    end
    // call dut
    dc_motor u_dc_motor(
    .clk(clk),.inc(inc),.dec(dec),.pwm_out(pwm_out),.nsleep(nsleep),.rst(rst)
    );

endmodule