`timescale 1ns / 1ps

module Camera_to_SRAM(
    input wire rst,
    input wire p_clock, 
    input wire vsync,   
    input wire href,    
    input wire [7:0] p_data, 
    
    output reg [16:0] bram_addr, 
    output reg [11:0] bram_data, 
    output reg bram_we,
    output reg frame_done
    );

    // 내부 변수
    reg [9:0] x_count;
    reg [8:0] y_count;
    reg [7:0] p_data_buf;
    reg pixel_flag; // 0: 상위, 1: 하위
    
    // 신호 동기화 (CDC & Edge)
    reg href_r1, href_r2;
    reg vsync_r1, vsync_r2;
    reg [7:0] p_data_r1, p_data_r2;

    // 초기화
    initial begin
        bram_addr = 0;
        bram_data = 0; 
        bram_we = 0;
        x_count = 0; 
        y_count = 0; 
        pixel_flag = 0;
    end

    // 단일 always 블록 (FSM 없음 -> 멈출 일 없음)
    always @(posedge p_clock or posedge rst) begin
        if (rst) begin
            x_count <= 0;
            y_count <= 0;
            bram_addr <= 0; 
            bram_data <= 0; 
            bram_we <= 0;
            pixel_flag <= 0; 
            frame_done <= 0;
            href_r1 <= 0; 
            href_r2 <= 0;
            vsync_r1 <= 0; 
            vsync_r2 <= 0;
            p_data_r1 <= 0; 
            p_data_r2 <= 0;
        end
        else begin
            // 입력 신호 파이프라인
            href_r1 <= href;   
            href_r2 <= href_r1;
            vsync_r1 <= vsync; 
            vsync_r2 <= vsync_r1;
            p_data_r1 <= p_data; 
            p_data_r2 <= p_data_r1;

            // vsync로 프레임 사이 강제 리셋
            if (vsync_r2 == 1'b1) begin
                x_count <= 0;
                y_count <= 0;
                bram_addr <= 0;
                pixel_flag <= 0;
                bram_we <= 0;
                frame_done <= 1;
            end
            else begin
                frame_done <= 0;

                // HREF Rising Edge: 라인 리셋
                if (href_r2 == 0 && href_r1 == 1) begin 
                    x_count <= 0;
                    if (y_count < 480) begin 
						y_count <= y_count + 1; 
					end
                    pixel_flag <= 0;
                end

                if (href_r2 == 1) begin
                    if (pixel_flag == 0) begin
                        p_data_buf <= p_data_r2;
                        pixel_flag <= 1;
                        bram_we <= 0;
                    end
                    else begin
                        pixel_flag <= 0;
                        // 짝수 픽셀만 골라내기 (Downscaling)
                        if (x_count[0] == 0 && y_count[0] == 0) begin
							bram_data <= {p_data_r2[3:0], p_data_buf}; // 바이트 스왑
                            //bram_data <= {p_data_buf[3:0], p_data_r2};
                            bram_addr <= ((y_count[8:1] << 8) + (y_count[8:1] << 6)) + x_count[9:1]; // 카운터 안쓰고 주소기반 addr 계산
                            bram_we <= 1;
                        end
                        else begin
                            bram_we <= 0;
                        end
                        x_count <= x_count + 1;
                    end
                end
                else begin
                    bram_we <= 0; // HREF 없으면 쓰기 금지
                end
            end
        end
    end

endmodule