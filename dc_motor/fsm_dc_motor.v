// dc motor FSM으로 다시 코드 짜보기
`timescale 1ns / 1ps

module fsm_dc_motor(
	input clk,
    input inc,
    input dec,
    input rst,
    output reg pwm_out,
    output reg nsleep
);

reg [2:0]state;
reg [2:0]next_state;
reg [12:0]duty_cycle = 1000;
reg [12:0]count = 0;
reg [7:0]i = 0;

// state 정의
parameter IDLE = 3'b000, // 기본 duty cycle을 가짐. inc, dec 신호가 100번 카운트 되면 state 이동
INC = 3'b001, // inc == 1, duty cycle 증가
DEC = 3'b010, // dec == 1, duty cycle 감소
MAX = 3'b011, // duty cycle == 1950, 더이상 증가 x
MIN = 3'b100; // duty cycle == 50, 더이상 감소 x

// 클럭 사이클 만들기
always @(count or duty_cycle) begin
	if (count < duty_cycle) begin
		pwm_out <= 1;
	end
	else if (count >= duty_cycle) begin
		pwm_out <= 0;
	end
	else if (count == 2000) begin
		count <= 0;
	end
end

// next state logic
always @(posedge clk or rst) begin
	if (rst) begin
		duty_cycle = 1000;
		count = 0;
		i = 0;
	end
	else begin
		count <= count + 1;
		if (inc == 1 || dec == 1) begin
			i <= i+1;
		end

		case (state)
		IDLE: begin
			i = 0;
			duty_cycle = 1000;
			if (i == 100) begin
				if (inc == 1) next_state <= INC;
				else next_state <= DEC;
				i <=0;
			end
		end
		INC: begin
			i=0;
			if (i == 100) begin 
				duty_cycle <= duty_cycle + 1;
				i <=0;
			end
			if (duty_cycle == 1950) next_state <= MAX;
			if (dec == 1) next_state <= DEC; 
		end
		DEC: begin
			i=0;
			if (i == 100) begin 
				duty_cycle <= duty_cycle - 1;
				i <= 0;
			end
			if (inc == 1) next_state <= INC;
			if (duty_cycle == 50) next_state <= MIN;
		end
		MAX: begin
			if (dec == 1) next_state <= DEC;

		end
		MIN: begin 
			if (inc == 1) next_state <= INC;
		end
		endcase
	end
end


endmodule