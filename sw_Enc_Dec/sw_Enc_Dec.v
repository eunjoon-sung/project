`timescale 1ns / 1ps

module sw_Enc_Dec(
    input sw1,
    input sw0,
    input [3:0] in,
    input clk,
    output reg [3:0] out = 4'b0000
    );
    
    reg [31:0]count = 0;
    reg [1:0] sw = 0;
    
    always @(posedge clk) begin
        count <=  count + 1;
        
        if (sw1 == 1 && sw0 == 1) begin // Reset
        sw = 0;
        end
        else if (sw1 == 0 && sw0 == 1) begin // Decoder 동작
        sw = 1;
        end
        else if (sw1 == 1 && sw0 == 0)begin // Encoder 동작
        sw = 2;
        end
        // 0 0 이면 그 전 값 유지
        
       
        if (sw == 2) begin // Encoder 동작
        count <= 0;
            case (in)
                4'b0001: out <= 4'b0000;
                4'b0010: out <= 4'b0001;
                4'b0100: out <= 4'b0010;
                4'b1000: out <= 4'b0011;
                default: out <= 4'b0000;
            endcase
        end
        
        else if (sw == 1) begin //Decoder 동작
        count <= 0;
            case (in)
                4'b0000: out <= 4'b0001;
                4'b0001: out <= 4'b0010;
                4'b0010: out <= 4'b0100;
                4'b0011: out <= 4'b1000;
                default: out <= 4'b0000;
            endcase
        end

        else begin// 아무것도 안누른 경우 그냥 led switching만 하기
        
            if(count == 50000000) begin // if문 클럭이 f= 50Mhz이면 50,000,000일 때 1초씩. 
                    out[0] <= ~out[0];
                    if (out[3] == 1)begin
                        out[3] <= ~out[3];
                        end
            end
            else if(count == 100000000) begin 
                out[0] <= ~out[0];
                out[1] <= ~out[1];
            end
            else if(count == 150000000) begin 
                out[1] <= ~out[1];
                out[2] <= ~out[2];
            end
            else if(count == 200000000) begin 
                out[2] <= ~out[2];
                out[3] <= ~out[3];
            end
            else if(count == 250000000) begin
                out[3] <= ~out[3];
                count <= 0; // 꺼짐상태로 대기모드
            end
        end
    end
endmodule
