`timescale 1ns / 1ps

module Chroma_key_mixer(
    input wire clk,
	input wire rst,
	input wire [23:0] rgb_data,
	input wire [23:0] bg_data, // from Background_gen.v
	input wire i_hsync, // from Video_timing_gen.v
	input wire i_vsync,
	input wire i_de,
	
	// Threshold
	input wire [7:0]G_min,
	input wire [7:0]RG_max,
	
	output reg [23:0] mixed_data,
	output wire o_hsync,
	output wire o_vsync,
	output wire o_de
    );
    
    wire [7:0] R_data = rgb_data[23:16];
    wire [7:0] G_data = rgb_data[15:8];
    wire [7:0] B_data = rgb_data[7:0];
    
    wire [7:0] margin = 8'd20; // 마진이 클수록 더 엄격하게 녹색을 찾게됨.
    
    // 한 클럭 지연 맞춰줌
    reg vsync_r1;
    reg hsync_r1;
    reg de_r1;
    
    assign o_vsync = vsync_r1;
    assign o_hsync = hsync_r1;
    assign o_de = de_r1;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mixed_data <= 0;
            vsync_r1 <= 0;
            hsync_r1 <= 0;
            de_r1 <= 0;
        end
        else begin
            vsync_r1 <= i_vsync;
            hsync_r1 <= i_hsync;
            de_r1 <= i_de;
            
            // 크로마키 판별 (수정)
            if (R_data <= RG_max && G_data >= G_min && B_data <= RG_max && ({1'b0, G_data} >= {1'b0, R_data} + margin) && ({1'b0, G_data} >= {1'b0, B_data} + margin)) begin
                mixed_data <= bg_data;
            end
            else begin
                mixed_data <= rgb_data;
            end

        end
    end

endmodule