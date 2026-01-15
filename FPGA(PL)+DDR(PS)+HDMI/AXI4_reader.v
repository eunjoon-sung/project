`timescale 1ns / 1ps

module AXI4_reader(
    input wire rst,
    input wire clk_100Mhz, // fifo write clk (axi)
    input wire clk_25Mhz,  // fifo read clk
    
    input wire rd_enable, // from VTG.
    output wire fifo_empty,
    output wire [15:0] pixel_data, // from FIFO to VTG
    
    // AXI master port
    // 1. 주소 채널
    output reg [AXI_ADDR_WIDTH - 1:0] ARADDR,
    output reg ARVALID,
    input wire ARREADY,
    output wire [7:0] ARLEN,
    output wire [2:0] ARSIZE,
    output wire [1:0] ARBURST,
    
    // 2. 데이터 채널
    input wire RVALID,
    output reg RREADY,
    input wire RLAST,
    input wire [AXI_DATA_WIDTH -1 : 0] RDATA, // fifo input
    output wire [3:0] ARCACHE,
    
    input wire buf_select,
    input wire vsync_start_pulse,
    
    // Debugging
    output reg [1:0] state,
    output reg [AXI_ADDR_WIDTH -1 : 0] ADDR_OFFSET // 한 프레임 만들 동안 주소 300번 증가 (256 pixel * 300 = 76800 )
    );
    
    // AXI4 Master parameter, constant
    parameter AXI_ADDR_WIDTH = 32;
    parameter AXI_DATA_WIDTH = 64;
    
    // 더블 프레임 버퍼
    wire [31:0] FRAME_BASE_ADDR;
    reg buf_select_reg;
    
    always @(posedge clk_100Mhz) begin
        if (rst) begin
            buf_select_reg <= 0;
        end
        else begin
            buf_select_reg <= buf_select;
        end
    end
    assign FRAME_BASE_ADDR = (buf_select_reg)? 32'h0100_0000 : 32'h0110_0000;    

    // AXI Constants
    assign ARLEN   = 8'd63;    // 64 Burst
    assign ARSIZE  = 3'b011;   // 8 Byte (64bit)
    assign ARBURST = 2'b01;    // INCR
    assign ARCACHE = 4'b1111;
    
    // FSM state
    reg [1:0] next_state;
    
    parameter IDLE = 0;
    parameter ADDR_SEND = 1;
    parameter DATA_READ = 2;
    
    // fifo
    wire fifo_full;
    wire prog_full; // 900 정도 차면 axi에게 멈추라는 신호 줌, 다시 900 보다 낮아지면 ddr에서 데이터 읽음
    // wire fifo_empty; 밖으로 뺌
    wire fifo_rd_en;
    
    assign fifo_rd_en = rd_enable;
    
    
    // 100MHz 도메인에서 신호 동기화 (2 FF sync)
    reg vsync_sync_d1, vsync_sync_d2;
    always @(posedge clk_100Mhz) begin
        vsync_sync_d1 <= vsync_start_pulse;
        vsync_sync_d2 <= vsync_sync_d1;
    end
    
    // 1. sequential logic
    always @(posedge clk_100Mhz) begin
        if (rst) begin
            state <= 0;
            ARADDR <= FRAME_BASE_ADDR;
            ADDR_OFFSET <= 0;
            ARVALID <= 0;  // 리셋 시 0으로 초기화
            RREADY <= 0;   // 리셋 시 0으로 초기화
        end
        else begin
            state <= next_state;
            
            if (vsync_sync_d2) begin // 한 프레임 끝나면 주소 초기화
                ADDR_OFFSET <= 0;
            end
            
            case (state)
                IDLE: begin
                    if (prog_empty) begin // FIFO Threshold : prog_empty 사용으로 수정함. 충분히 비었음 일 때 출발
                        ARADDR <= FRAME_BASE_ADDR + ADDR_OFFSET;
                    end
                end
                            
                ADDR_SEND: begin
                    // 기본적으로 1을 띄움
                    if (ARVALID == 0) begin
                        ARVALID <= 1;
                    end
                    
                    // 핸드셰이크 성립(둘 다 1) 시에만 내림
                    if (ARVALID && ARREADY) begin
                        ARVALID <= 0;
                    end
                end
                
                DATA_READ: begin // pixel 256개 한번에 fifo로 들어옴 (burst = 64)
                    RREADY <= 1;  // RVALID == 1 이면 fifo의 wr_en 신호 on
                    if (RLAST && RVALID) begin
                        ADDR_OFFSET <= ADDR_OFFSET + 32'd512; // 픽셀 하나당 16bit -> 주소 공간 2byte 필요. 
                        RREADY <= 0;
                    end
                end
            endcase
        end
    end
    
    
    // 2. combinational logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (!prog_full) begin
                    next_state = ADDR_SEND;
                end
            end
            
            ADDR_SEND: begin
                if (ARVALID == 1 && ARREADY == 1) begin
                    next_state = DATA_READ;
                end
            end
            
            DATA_READ: begin
                if (RLAST && RVALID) begin
                    next_state = IDLE;
                end
            end
        endcase
    
    end

    
    fifo_generator_1 u_fifo_reader (
        .rst(rst),
        .wr_data_count(),
        .prog_full(prog_full),
        
        .wr_clk(clk_100Mhz),
        .full(fifo_full),
        .din(RDATA),
        .wr_en(RVALID && RREADY),
        .wr_rst_busy(),
        
        .rd_clk(clk_25Mhz),
        .empty(fifo_empty),
        .dout(pixel_data),
        .rd_en(fifo_rd_en), // VTG에서 읽어가고 나서 1을 띄움 (FWFT)
        .rd_rst_busy()
    );
    
endmodule
