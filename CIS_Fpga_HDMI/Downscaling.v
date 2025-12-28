`timescale 1ns / 1ps
// 640 * 480 ---->> 320 * 240
// Decimation(버리기) 방식

module Downscaling(
    input wire clk,
    input wire rst,
    input wire [11:0] fifo_dout,
    input wire fifo_empty, // fifo가 비어있는지 알려주는 신호
    output reg fifo_rd_en, // fifo에 data 요청하는 신호
    output reg [11:0] scaled_data,
    output reg scaled_valid,
    output wire [9:0]o_x_count,
    output wire [8:0]o_y_count
    );
    assign o_x_count = x_count;
    assign o_y_count = y_count;

    
    reg [9:0] x_count = 0; // 가로 픽셀 카운터 640
    reg [8:0] y_count = 0; // 세로 픽셀 카운터 480
    //wire [9:0] x_count_p = x_count - 1;
    //wire [8:0] y_count_p = y_count - 1;
    reg state = 0;
    reg next_state;
    reg fifo_rd_en_d1; // standard fifo의 데이터 아웃 한클럭 지연을 고려
    
    localparam IDLE = 0; // fifo_empty = 1
    localparam FIFO_READ = 1; // fifo_empty = 0. 계속 값이 들어옴. fifo에서 데이터 받으면 그걸로 계산 후 값 내보내기
    
    // FSM state
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            fifo_rd_en <= 0;
            scaled_data <= 0;
            scaled_valid <= 0;
            state <= IDLE;
            x_count <= 0;
            y_count <= 0;
            fifo_rd_en_d1 <= 0;
        end
        else begin
           state <= next_state;
           fifo_rd_en_d1 <= fifo_rd_en;
           
            case (state)
                IDLE: begin
                    fifo_rd_en <= 0;
                    fifo_rd_en_d1 <= 0;
                    scaled_data <= 0;
                    scaled_valid <= 0;
                    if (!fifo_empty) begin
                        fifo_rd_en <= 1;
                    end
                end
    
                FIFO_READ: begin
                    if (!fifo_empty) begin
                        fifo_rd_en <= 1;     // 읽기 요청
                    end
                    else begin
                        fifo_rd_en <= 0;
                    end
                
                    if (fifo_rd_en_d1) begin
                        x_count <= x_count + 1;
        
                        if (x_count == 639) begin
                            y_count <= y_count + 1;
                            
                            if (y_count == 479) begin
                                x_count <= 0;
                                y_count <= 0;
                            end
                        end
                        
                        // 짝수 픽셀만 골라내기
                        if (x_count % 2 == 0 && y_count % 2 == 0) begin
                            scaled_data <= fifo_dout;
                            scaled_valid <= 1;
                        end
                    end
                    else begin
                        scaled_valid <= 0;
                    end
                end
            endcase
        end
    end
    
    always @(*) begin
        next_state = state;
    
        case (state)
            IDLE: begin
                if (!fifo_empty) begin
                    next_state = FIFO_READ;
                end
            end
    
            FIFO_READ: begin
                if (fifo_empty) begin 
                    next_state = IDLE;
                end
            end
        endcase
    end
        
endmodule