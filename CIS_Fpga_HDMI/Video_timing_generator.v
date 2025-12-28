`timescale 1ns / 1ps

module Video_timing_generator(
    input wire clk,
    input wire rst,
    input [11:0] sram_data, // from SRAM : data
    
    output reg [16:0] rd_addr, // to SRAM : addr
    output wire hsync,
    output wire vsync,
    output wire de, // DATA Enable 신호. 화면 나오는 구간에 1됨
    output reg [23:0] rgb_data, // R,G,B 각각 8비트. why 8bit?? HDMI 규격이 최소 8비트(RGB888)를 기본으로 사용하기 때문
    // 디버깅용 출력
    output wire [9:0]o_h_count,
    output wire [9:0]o_v_count
    );
    
    assign o_h_count = h_count;
    assign o_v_count = v_count;
    
    
    // SRAM에게 보낼 좌표 (주소) 생성
    reg [9:0] h_count; // 0~799
    reg [9:0] v_count; // 0~524
    
    reg state;
    reg next_state;
    
    // 4 clk 지연을 위한 레지스터
    wire hsync_raw;
    reg hsync_r1;
    reg hsync_r2;
    reg hsync_r3;
    reg hsync_r4;
    wire vsync_raw;
    reg vsync_r1;
    reg vsync_r2;
    reg vsync_r3;
    reg vsync_r4;
    wire de_raw;
    reg de_r1;
    reg de_r2;
    reg de_r3;
    reg de_r4;
    
    
    assign hsync_raw = !(h_count >= 655 && h_count <= 751);
    assign vsync_raw = !(v_count >= 490 && v_count <= 491);
    assign de_raw = !(h_count >= 640 || v_count >= 480);
    
    assign hsync = hsync_r4;
    assign vsync = vsync_r4;
    assign de = de_r4;
    
    localparam IDLE = 0;
    localparam SENDING = 1;
    // 파이프라이닝 기법을 사용하기 위해 한 클럭에서 받고 내보내는 두 가지 일을 동시에 하도록 상태를 하나로 둠. (굳이 fsm 쓸 필요 x)
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= 0;
            h_count <= 0;
            v_count <= 0;
            rd_addr <= 0;
            rgb_data <= 0;
        end
        else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    h_count <= 0;
                    v_count <= 0;
                    rd_addr <= 0;
                    rgb_data <= 0;
                end
                SENDING: begin
                    // sram에서 읽어올 데이터의 좌표(주소) 생성
                    h_count <= h_count + 1;
                    if (h_count == 799) begin
                        h_count <= 0;
                        v_count <= v_count + 1;
                        
                        if (v_count == 524) begin
                            v_count <= 0;
                        end
                    end
                    
                    if (h_count < 640 && v_count < 480) begin
                        rd_addr <= ((v_count >> 1) * 320) + (h_count >> 1); // Upscaling : 나누기 2하면 됨 (right로 shift)
                    end
                    else begin
                        rd_addr <= 0;
                    end
                    
                    // raw 신호를 rgb data 전송에 맞춰 보내려면 총 4 클럭 기다려야 함 (레지스터 4개)
                    hsync_r1 <= hsync_raw;
                    hsync_r2 <= hsync_r1;
                    hsync_r3 <= hsync_r2;
                    hsync_r4 <= hsync_r3;
                    vsync_r1 <= vsync_raw;
                    vsync_r2 <= vsync_r1;
                    vsync_r3 <= vsync_r2;
                    vsync_r4 <= vsync_r3;
                    de_r1 <= de_raw;
                    de_r2 <= de_r1;
                    de_r3 <= de_r2;
                    de_r4 <= de_r3;
                    
                    if (de_r3 == 1) begin // sram에서 데이터 도착 그 다음 클럭에 hdmi로 보냄
                        rgb_data[23:16] <= {sram_data[11:8], 4'b0000};   // R
                        rgb_data[15:8] <= {sram_data[7:4], 4'b0000};   // G
                        rgb_data[7:0] <= {sram_data[3:0], 4'b0000};    // B
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
