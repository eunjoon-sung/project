`timescale 1ns / 1ps
/*
※ Signal
· MCLK: master clk 제어프로세서가 카메라로 공급
· PCLK : 한 픽셀을 위한 클럭
· RESET: 카메라 리셋
· PWDN : 이미지 센서 OFF 시 사용. High 면 동작함
· HREF: "한 줄 완성되는 동안 계속 누르고 있는 버튼" (Gate)
· HSYNC: "한 줄 완성되었을 때 '찰칵' 하고 한 번 누르는 버튼" (Pulse)
· VSYNC : VSYNC 신호는 프레임과 프레임 사이의 '공백' 기간(V-Blanking)을 정의. 한 프레임 완성되면 pulse 신호로 잠시 1되었다가 다시 0됨
ex. 160x120 이미지 프레임 → pclk = 160*120번 진동 / HSYNC = 120번 진동 / VSYNC = 1번 진동
*/

module Camera_read(
    input wire rst,
	input wire p_clock,
	input wire vsync,
	input wire href,
	input wire [7:0] p_data, // 12bit : RGB 444 --> 8 + 4
	output reg [11:0] pixel_data =0,
	output reg pixel_valid = 0, // data 완성을 알려주는 신호
	output reg frame_done = 0,
	output wire [9:0] o_line_cnt,
	output wire vsync_en
    );
    assign o_pixel_flag = pixel_flag; // ILA 용
    assign o_line_cnt = line_cnt;

// Red: 이전 바이트(buf)의 상위 4비트
    wire [3:0] R_4bit = p_data_buf[7:4];             
    // Green: 이전 바이트(buf)의 하위 3비트 + 현재 바이트(d2)의 최상위 비트
    wire [3:0] G_4bit = {p_data_buf[2:0], p_data_d2[7]}; 
    // Blue: 현재 바이트(d2)의 하위 비트들
    wire [3:0] B_4bit = p_data_d2[4:1];
    
/*  // 상위 하위 비트 스왑 용
    wire [3:0] R_4bit = p_data_d2[7:4];                // Red: 현재 데이터(상위)
    wire [3:0] G_4bit = {p_data_d2[2:0], p_data_buf[7]};  // Green: 섞임 (순서 반전)
    wire [3:0] B_4bit = p_data_buf[4:1];            // Blue: 버퍼(하위)
 */ 
    wire o_p_data_buf = p_data_buf;
	reg [7:0] p_data_buf;
	reg pixel_flag = 0; // pixel 상위, 하위비트 구분
	reg [1:0] state = 0;
	reg [1:0] next_state;
    
    reg [9:0]line_cnt = 0;
    
    assign vsync_en = vsync_d1 & (~vsync_d2);
    
    // metastability 방지
    reg href_d1 = 0;
    reg href_d2 = 0;
    reg vsync_d1 = 0;
    reg vsync_d2 = 0;
    reg [7:0] p_data_d1, p_data_d2 =0;

			
	localparam IDLE = 0; // vsync 0인 상태
	localparam CAPTURING = 1;  // 데이터 캡쳐 및 합치기. href는 한 줄 동안 1 유지
	localparam END = 2; // vsync 신호 pulse 되는 상태
	
	// FSM
	// 1. seqeuntial logic
	
	always @(posedge p_clock or posedge rst) begin
	   if (rst) begin
	       state <= 0;
	       pixel_data <= 0;
	       pixel_valid <= 0;
	       frame_done <= 0;
	       p_data_buf <= 0;
	       pixel_flag <= 0;
	       href_d1 <= 0;
           href_d2 <= 0;
           vsync_d1 <= 0;
           vsync_d2 <= 0;
           p_data_d1 <= 0;
           p_data_d2 <= 0;
           line_cnt <= 0;
	   end
	   else begin
            state <= next_state;
            vsync_d1 <= vsync;
            vsync_d2 <= vsync_d1;
            
            href_d1 <= href;
            href_d2 <= href_d1;
            
            p_data_d1 <= p_data;
            p_data_d2 <= p_data_d1;

            case (state)
                IDLE: begin
                    frame_done <= 0;
                    pixel_valid <= 0;
                    pixel_flag <= 0;
                    p_data_buf <= 0;
                    line_cnt <= 0;
                end
    
                CAPTURING: begin
                    frame_done <= 0;
                    
                    if (href_d1 && (~href_d2)) begin
                        line_cnt <= line_cnt + 1;
                    end
                    

                    if (href_d2 == 1) begin
                        if (pixel_flag == 0) begin
                           p_data_buf[7:0] <= p_data_d2[7:0]; // R 데이터 넣기
                           pixel_valid <= 0;
                           pixel_flag <= 1;
                        end
                        else begin
                           pixel_flag <= 0;
                           pixel_valid <= 1;
                           pixel_data <= { R_4bit, G_4bit, B_4bit };
                           //pixel_data <= {p_data_buf[3:0], p_data[7:0]};
                           // ✅ pixel_data <= p_data_buf; 이렇게 하면 pixel_data에 정확한 값 안들어감. 그래서 "직접 조립(Concatenation)" 방식 씀.
                           // data buf는 R 비트 버퍼로만 사용할거니까 4비트로 바꿈
                        end
                    end
                    else begin //  한 줄 종료
                        pixel_flag <= 0;
                        pixel_valid <= 0;
                    end
                end
                
                END: begin
                    frame_done <= 1;
                    line_cnt <= 0;
                end
                
            endcase
		end
	end

	// 2. combinational logic
	always @(*) begin
		next_state = state;

		case (state)
			IDLE: begin
				if (vsync_en == 1) begin
					next_state = CAPTURING;
				end
			end

			CAPTURING: begin
                if (line_cnt == 480) begin
                    next_state = END;
                end
			end
			
			END: begin
					next_state = IDLE;
			end

			default: begin
				next_state = IDLE;
			end
		endcase
	end

endmodule
