`timescale 1ns / 1ps
// 들어오는 좌표에 맞춰서 좌표에 맞는 배경을 생성하는 모듈
// 일단 체크무늬로 만들어볼거임
module Background_gen(
	input wire clk,
	input wire rst,
	input wire [9:0]h_count, // x 좌표
	input wire [8:0]v_count, // y 좌표
	
	output reg [15:0] bg_data // background data
	);

    always @(*) begin
        if (h_count < 320 && v_count < 240) begin
            if (h_count[6] == 0 ^ v_count[6] == 0) begin// XOR 연산 사용
                bg_data = 16'h00_0F; // blue
            end
            else begin
                bg_data = 16'h0F_FF; // white
            end
        end
        else begin
            bg_data = 16'h00_00;
        end
    end
	
endmodule
