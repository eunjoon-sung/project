`timescale 1ns / 1ps
// 만약 Stream 데이터를 DDR에 넣고 싶다면? -> 누군가가 중간에서 "주소표"를 붙여줘야 함. 주소가 필수인 "Memory Mapped" 방식
// 그게 이 모듈의 역할
// VDMA의 핵심 기능(Stream to MM)을 구현하는 모듈울 설계

module AXI4_writer(
    input wire pclk,
    input wire clk_100Mhz,
    input wire rst,
    input wire [15:0] mixed_data, // from Chroma_key_mixer.v
    input wire pixel_valid, // from Camera_capture.v
    input wire frame_done, 
    input wire [31:0] FRAME_BASE_ADDR, // for Double / Triple Frame Buffer
    
    // AXI master port
    // 1. 주소 채널
    output reg [AXI_ADDR_WIDTH -1 : 0] AWADDR,
    output reg AWVALID,
    input wire AWREADY,
    output wire [7:0] AWLEN, // burst 길이 0-255
    output wire [2:0] AWSIZE, // data size
    output wire [1:0] AWBURST, //  burst type
    output wire [3:0] AWCACHE,
    output wire [2:0] AWPROT,
    
    // 2. 데이터 채널
    output wire [AXI_DATA_WIDTH -1 : 0] WDATA,
    output reg WVALID,
    input wire WREADY,
    output reg WLAST, // 마지막 Data
    output wire [7:0] WSTRB, // Write Strobe
    
    // 3. 응답 채널
    input wire BVALID,
    output wire BREADY,
    input wire [1:0] BRESP, // [추가] 이거 빠져서 AXI 통신 먹통이었음.
    
    output wire o_prog_full,
    output reg [1:0] state,
    output reg [AXI_ADDR_WIDTH -1 : 0] ADDR_OFFSET
    );
    
    assign o_prog_full = prog_full;
    
    reg [1:0] next_state = 0;
    reg [7:0] data_count = 0; // 64개 세는 용도
        
    // AXI4 Master parameter, constant
    parameter AXI_ADDR_WIDTH = 32;
    parameter AXI_DATA_WIDTH = 64;

    assign AWLEN   = 8'd79;     // 64 burst
    assign AWSIZE  = 3'b011;   // 8 byte (64 bit)
    assign AWBURST = 2'b01;    // INCR (주소 증가 모드)
    assign AWCACHE = 4'b0011; // DDR 컨트롤러 활성화 
    assign AWPROT  = 3'b000;  // 보안 검사 통과용
    assign WSTRB   = 8'hFF;    // 모든 바이트 유효
    
    // WREADY신호에 바로 전달되어야 하므로 wire로 연결해줌
    assign WDATA = fifo_data;
    assign fifo_rd_en = (state == DATA_SEND) && (WREADY == 1) && (WVALID == 1); // WVALID가 1이 되어야 실제로 데이터를 쏠 수 있으므로, 그때부터 FIFO를 읽어야 함
    assign BREADY = 1;
    
    // fifo
    wire fifo_full;
    wire prog_full; // 253 까지 차면 출발신호 보냄
    wire fifo_empty;
    wire [63:0] fifo_data;
    wire fifo_rd_en;
    wire [8:0] rd_data_count;
    
    // fifo reset 신호
    reg [3:0] reset_stretch_cnt; // 펄스를 늘리기 위한 카운터
    wire fifo_reset_safe;        // 최종적으로 사용할 안전한 리셋 신호
    assign fifo_reset_safe = (reset_stretch_cnt > 5);
        
    localparam IDLE = 0;
    localparam ADDR_SEND = 1;
    localparam DATA_SEND = 2;
    localparam WAIT_RES = 3;
    
    // frame_done을 펄스로 변환
    reg frame_done_d1;
    reg frame_done_d2;
    wire frame_done_pulse = (frame_done_d1 == 1'b1 && frame_done_d2 == 1'b0);
    
    always @(posedge clk_100Mhz) begin
        frame_done_d1 <= frame_done;
        frame_done_d2 <= frame_done_d1;
    end
    
    // 1. sequential logic
    always @(posedge clk_100Mhz or posedge rst) begin
        if (rst) begin
            state <= 0;
            data_count <= 0;
            AWADDR <= FRAME_BASE_ADDR;
            ADDR_OFFSET <= 0;
            AWVALID <= 0; WVALID <= 0;
        end
        else begin
            if (frame_done_pulse) begin
                reset_stretch_cnt <= 8'd20; 
                ADDR_OFFSET <= 0;
            end
            else if (reset_stretch_cnt > 0) begin
                reset_stretch_cnt <= reset_stretch_cnt - 1;
            end
            else if (frame_done_pulse || reset_stretch_cnt > 0) begin
                    state <= IDLE;
                    data_count <= 0;
            end
            else begin
                state <= next_state;
    
                case (state)
                    IDLE: begin
                        data_count <= 0;
                        AWVALID <= 0;
                        AWADDR <= FRAME_BASE_ADDR + ADDR_OFFSET;
                    end
                    
                    ADDR_SEND: begin // 주소는 64번 동안 자동으로 8씩 증가하며 알아서 써짐 (64bit -> 8 byte)
                        if (AWVALID && AWREADY) begin // valid, ready 둘 다 1인 순간 모두 전송됨
                            AWVALID <= 0;
                        end
                        else begin
                            AWVALID <= 1;
                        end
                    end
                    
                    DATA_SEND: begin
                        WVALID <= 1;
                        if (fifo_rd_en) begin // "FWFT mode" 이므로 이 신호는 데이터 받았다는 확인 신호임. wdata는 이미 나와있는 상태.
                            data_count <= data_count + 1;
                            
                            if (data_count == 78) begin
                                WLAST <= 1'b1;
                            end
                            
                            if (data_count == 79) begin
                                data_count <= 0;
                                WLAST <= 0;
                                WVALID <= 0; // 64번 데이터 전송 (총 256픽셀)
                            end
                        end
                    end
                    
                    WAIT_RES: begin
                        if (BREADY && BVALID == 1) begin
                            if (ADDR_OFFSET < 32'd152960) begin // 32'd153088 (64 burst)
                                ADDR_OFFSET <= ADDR_OFFSET + 32'd640;//32'd512;
                            end
                        end
                    end
                endcase
            end
        end
    end
    
    // 2. combinational logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (prog_full) begin
                    next_state = ADDR_SEND;
                end
            end
            
            ADDR_SEND: begin
                if (AWREADY == 1 && AWVALID == 1) begin
                    next_state = DATA_SEND;
                end
            end
            
            DATA_SEND: begin
                if (data_count == 79 && WREADY == 1) begin
                    next_state = WAIT_RES;
                end
            end
            
            WAIT_RES: begin
                if (BREADY == 1 && BVALID == 1) begin
                    next_state = IDLE;
                end
            end
        endcase
    end
    
    
    // FIFO DUT
    fifo_generator_0 u_fifo_writer(
        .rst(rst || fifo_reset_safe),
        .rd_data_count(rd_data_count),
        .prog_full(prog_full),
        
        .wr_clk(pclk),
        .full(fifo_full),
        .din(mixed_data),
        .wr_en(pixel_valid),
        .wr_rst_busy(),
        
        .rd_clk(clk_100Mhz),
        .empty(fifo_empty),
        .dout(fifo_data),
        .rd_en(fifo_rd_en), // AXI가 읽어갈 때 1을 띄움 -- > FIFO로 들어감
        .rd_rst_busy()
    );
 
endmodule
