`timescale 1ns / 1ps
// Camera data read + Downscaling ---> To Chroma Key module
module Camera_capture(
    input wire rst,
    input wire p_clock, 
    input wire vsync,   
    input wire href,    
    input wire [7:0] p_data, 
    
    output reg [15:0] pixel_data, // 12 -> 16비트로 수정 (AXI 규격 맞춤)
    output reg frame_done, // 한 프레임 완성 알림
    output wire [9:0] o_x_count,
    output wire [8:0] o_y_count,
    output reg pixel_valid // 한 픽셀 완성 알림
    );
    
    
    assign o_x_count = x_count_d;
    assign o_y_count = y_count_d;
    
    
    // 내부 변수
    reg [9:0] x_count;
    reg [8:0] y_count;
    reg [7:0] p_data_buf;
    reg pixel_flag; // 0:상위, 1:하위
    
    // 다운스케일링된 좌표 (320*240)
    reg [9:0] x_count_d;
    reg [8:0] y_count_d;
    
    // 신호 동기화 (CDC & Edge)
    reg href_r1, href_r2;
    reg vsync_r1, vsync_r2;
    reg [7:0] p_data_r1, p_data_r2;

    // 초기화
    initial begin
        pixel_data = 0; 
        x_count = 0; 
        y_count = 0; 
        pixel_flag = 0;
        pixel_valid = 0;
    end

    // 단일 always 블록 (FSM 없음 -> 멈출 일 없음)
    always @(posedge p_clock or posedge rst) begin
        if (rst) begin
            x_count <= 0;
            y_count <= 0;
            pixel_data <= 0; 
            pixel_flag <= 0; 
            frame_done <= 0;
            href_r1 <= 0; 
            href_r2 <= 0;
            vsync_r1 <= 0; 
            vsync_r2 <= 0;
            p_data_r1 <= 0; 
            p_data_r2 <= 0;
            x_count_d <= 0;
            y_count_d <= 0;
            pixel_valid <= 0;
        end
        else begin
            // 입력 신호 파이프라인
            href_r1 <= href;   
            href_r2 <= href_r1;
            vsync_r1 <= vsync; 
            vsync_r2 <= vsync_r1;
            p_data_r1 <= p_data; 
            p_data_r2 <= p_data_r1;

            //vsync 프레임 강제 리셋
            if (vsync_r2 == 1'b1) begin
                x_count <= 0;
                y_count <= 0;
                pixel_flag <= 0;
                frame_done <= 1; // 중요! AXI Writer에게 주소 초기화 하라고 알림
                pixel_valid <= 0;
            end
            else begin
                frame_done <= 0;

                // HREF Falling Edge: 라인 리셋
                if (href_r2 == 0 && href_r1 == 1) begin 
                    x_count <= 0;
                    x_count_d <= 0; // [추가]
                    if (y_count < 480) y_count <= y_count + 1;
                    pixel_flag <= 0;
                end

                if (href_r2 == 1'b1 || pixel_flag == 1'b1) begin // [수정]
                    // 첫 번째 바이트
                    if (pixel_flag == 0) begin
                        p_data_buf <= p_data_r2;
                        pixel_flag <= 1;
                    end
                    else begin
                        pixel_flag <= 0;

                        
                        // 짝수 픽셀만 처리 (Downscaling)
                        if (x_count[0] == 0 && y_count[0] == 0 && x_count < 640 && y_count < 480) begin
                            
                            // B,G,R 순서로 조립
                            pixel_data <= {p_data_buf, p_data_r2};

                            x_count_d <= x_count[9:1]; // 다운스케일링 된 좌표
                            y_count_d <= y_count[8:1];
                            
                            pixel_valid <= 1;

                        end
                        else begin
                            pixel_valid <= 0;
                        end

                        x_count <= x_count + 1;
                    end
                end
                else begin
                    pixel_valid <= 0;
                end
            end
        end
    end

endmodule
