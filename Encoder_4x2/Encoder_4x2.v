// Encoder_4x2.v

`timescale 1ns / 1ps

module Encoder_4x2(
    input [3:0] D,
    output reg [1:0] B
    );
    
    always @(*) begin
        case (D)
            4'b0001: B <= 2'b00;
            4'b0010: B <= 2'b01;
            4'b0100: B <= 2'b10;
            4'b1000: B <= 2'b11;
            default: B <= 2'b00;
        endcase
    end
endmodule
