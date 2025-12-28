`timescale 1ns / 1ps
// 들어오는 좌표에 맞춰서 좌표에 맞는 배경을 생성하는 모듈
// 일단 체크무늬로 만들어볼거임
module Background_gen(
	input wire clk,
	input wire rst,
	input wire [9:0]h_count, // x 좌표
	input wire [9:0]v_count, // y 좌표
	
	output reg [23:0] bg_data // background data
	);

    always @(*) begin
        if (h_count < 640 && v_count < 480) begin
            if (h_count[6] == 0 ^ v_count[6] == 0) begin // XOR 연산 사용 (같으면 0, 다르면 1)
                bg_data = 24'h00_00_FF; // blue
            end
            else begin
                bg_data = 24'hFF_FF_FF; // white
            end
        end
        else begin
            bg_data = 24'h00_00_00;
        end
    end
	
endmodule