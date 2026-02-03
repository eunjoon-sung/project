`timescale 1ns / 1ps

module Chroma_key_mixer(
    input wire clk,
	input wire rst,
	input wire [15:0] rgb_data, // from Camera_capture.v
	input wire [15:0] bg_data, // from Background_gen.v
    input wire i_pixel_valid,    // from Camera_capture.v
	
	// Threshold
	input wire [7:0]G_min,
	input wire [7:0]RG_max,
	
	output reg [15:0] mixed_data,
	output reg o_pixel_valid
    );
    
    // [수정] rgb_data 구조: {4'b0000, R[3:0], G[3:0], B[3:0]} ---> {R[3:0], G[3:0], B[3:0] , 4'b0000} 
    wire [7:0] R_data = {rgb_data[11:8], 4'b0000};
    wire [7:0] G_data = {rgb_data[7:4], 4'b0000};
    wire [7:0] B_data = {rgb_data[3:0], 4'b0000};
    
	wire [7:0] margin = 8'd40; // 마진이 클수록 더 엄격하게 녹색을 찾게됨. [수정] 3에서 40으로 대폭 상향

    
    always @(*) begin
        if (!i_pixel_valid) begin
            mixed_data = 0;
            o_pixel_valid = 0;
        end
        else begin
            o_pixel_valid = 1;
            // 크로마키 판별 (수정)
            if ( (R_data <= RG_max) && 
                 (B_data <= RG_max) && 
                 (G_data >= G_min) && 
                 (G_data >= R_data + margin) && 
                 (G_data >= B_data + margin) ) begin
                mixed_data = bg_data;
            end
            else begin
                mixed_data = rgb_data;
            end
        end
    end

endmodule
