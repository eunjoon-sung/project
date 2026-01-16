`timescale 1ns / 1ps
// From AXI4 Reader to VTG 모듈

module Video_timing_generator(
    input wire clk,
    input wire rst,
    input [15:0] pixel_data, // from AXI reader : data
    
    output wire hsync,
    output wire vsync,
    output wire de, // DATA Enable 신호. 화면 나오는 구간에 1 됨. To HDMI_Tx

    output wire rd_enable, // fifo 읽어오는 신호
    output reg [23:0] rgb_data // R,G,B 각각 8비트. why 8bit?? HDMI 규격이 최소 8비트(RGB888)를 기본으로 사용하기 때문
    );

    // upscaling을 위한 자체 좌표 생성
    reg [9:0] h_count; // 0~799
    reg [9:0] v_count; // 0~524
    
    // [line buffer] 320개 픽셀을 저장할 메모리 선언 (FPGA에서 BRAM으로 합성됨)
    reg [15:0] line_buffer [0:319]; // 320개 * 16bit
    wire [15:0] buff_out; // 한 픽셀
    wire [8:0] buff_addr = h_count[9:1]; // 2로 나눔 (shift right)

    assign buff_out = line_buffer[buff_addr];

    reg state;
    reg next_state;
    
    assign hsync = !(h_count >= 656 && h_count <= 751);
    assign vsync = !(v_count >= 490 && v_count <= 491);
    assign de = !(h_count >= 640 || v_count >= 480);
    
    assign rd_enable = (h_count[0] == 1 && v_count[0] == 0) && !(h_count >= 640 || v_count >= 480); // fifo 읽어오는 신호
    

    localparam IDLE = 0;
    localparam SENDING = 1;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= 0;
            h_count <= 0;
            v_count <= 0;
            rgb_data <= 0;
        end
        else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    h_count <= 0;
                    v_count <= 0;
                    rgb_data <= 0;
                end

                SENDING: begin
                   // 좌표(주소) 생성
                    h_count <= h_count + 1;
                    if (h_count == 799) begin
                        h_count <= 0;
                        v_count <= v_count + 1;
                        
                        if (v_count == 524) begin
                            v_count <= 0;
                        end
                    end
                    
                    if (de) begin // 화면 나오는 구간일 때만 픽셀 데이터 처리
                        if (v_count[0] == 0) begin //  짝수줄
                            if (h_count[0] == 1) begin
                                line_buffer[buff_addr] <= pixel_data; // 라인버퍼에 한 줄 (320) 저장
                            end

                            rgb_data[23:16] <= {pixel_data[15:11], 3'b000}; // R
                            rgb_data[15:8]  <= {pixel_data[10:5],  2'b00};  // G
                            rgb_data[7:0]   <= {pixel_data[4:0],   3'b000}; // B
                        end
                        else if (v_count[0] == 1) begin // 홀수줄
                            // 라인 버퍼에 저장된 거 읽어서 출력
                            rgb_data[23:16] <= {buff_out[15:11], 3'b000};   // R
                            rgb_data[15:8]  <= {buff_out[10:5],  2'b00};    // G
                            rgb_data[7:0]   <= {buff_out[4:0],   3'b000};   // B
                        end
                    end
                    else begin
                        rgb_data <= 0; // 화면 안 나오는 구간에서는 검은색
                    end
                end
            endcase
        end
    end
    
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (!rst) begin
                    next_state = SENDING;
                end
            end
            SENDING: begin
                if (rst) begin
                    next_state = IDLE;
                end
            end
        endcase
    end
    
endmodule
