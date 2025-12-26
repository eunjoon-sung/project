// dc_motor.v
`timescale 1ns / 1ps

module dc_motor(
    input clk,
    input inc,
    input dec,
    input rst,
    output reg pwm_out,
    output reg nsleep
    );
    
    reg [17:0] count; // 200,000 이상 가능
    reg [17:0] duty_cycle = 1000; // 기본 duty cycle
    reg [7:0] i =0; // 100 까지 세는 카운터
    
    always @(posedge clk) begin
        if (rst) begin
            count <= 0;
            duty_cycle <= 1000;
            i <= 0;
            pwm_out <= 0;
            nsleep <= 1;
         end
        else begin
            count <= count + 1;
            
            // PWM 출력 제어
            if (count < duty_cycle) begin
                pwm_out <= 1'b1;
            end
            else begin
                pwm_out <= 1'b0;
            end
            
            if (count >= 2000) begin
                count <=0;
            end
            // inc가 100 번 연속 된 경우 duty 증가하도록 설계
            // duty cycle 은 1950과 50 사이에서 유지되도록 설계
            if ((inc == 1)&&(duty_cycle < 1950)) begin
                i <= i+1;
                if (i >= 100) begin
                    duty_cycle <= duty_cycle +1;
                    i<=0;
                end
            end
            // dec가 100번 연속되면 duty 감소
            else if((dec == 1)&&(duty_cycle > 50)) begin
                i<= i+1;
                if (i >= 100) begin
                    duty_cycle <= duty_cycle -1;
                    i<=0;
                end
            end
            else begin
                i<=0;
            end
            
            nsleep<= 1'b1; // 항상 on  
        end
       end
endmodule
