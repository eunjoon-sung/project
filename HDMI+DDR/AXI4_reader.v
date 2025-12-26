`timescale 1ns / 1ps
// DDR 메모리에서 AXI4 인터페이스로 데이터를 읽어와 FIFO에 담고 VTG 모듈로 픽셀 데이터 전달하는 모듈

module AXI4_reader(
    input wire rst,
    input wire clk_100Mhz, // fifo write clk (axi)
    input wire clk_25Mhz,  // fifo read clk
    input wire frame_done, // 한 프레임마다 청소
    
    input wire de, // from VTG. data enable
    output wire fifo_empty,
    output wire [15:0] pixel_data, // from FIFO to VTG
    
    // AXI master port
    // 1. 주소 채널
    output reg [AXI_ADDR_WIDTH - 1:0] ARADDR,
    output reg ARVALID,
    input wire ARREADY,
    output wire ARLEN,   // 상자를 몇 개나 연속으로 보낼지
    output wire ARSIZE,  // 한 번 전송할 때 8바이트(64비트, 픽셀 4개)를 실어라
    output wire ARBURST,
    
    // 2. 데이터 채널
    input wire RVALID,
    output reg RREADY,
    input wire RLAST,
    input wire [AXI_DATA_WIDTH -1 : 0] RDATA // fifo input
    
    );
    
    // AXI4 Master parameter, constant
    parameter AXI_ADDR_WIDTH = 32;
    parameter AXI_DATA_WIDTH = 64;
    parameter FRAME_BASE_ADDR = 32'h0000_0000; // DDR 시작 주소
    
    reg [AXI_ADDR_WIDTH -1 : 0] ADDR_OFFSET; // 한 프레임 만들 동안 주소 300번 증가 (256 pixel * 300 = 76800 )

    // AXI Constants
    assign ARLEN   = 8'd63;    // 64 Burst
    assign ARSIZE  = 3'b011;   // 8 Byte (64bit)
    assign ARBURST = 2'b01;    // INCR
    
    // FSM state
    reg [1:0] state;
    reg [1:0] next_state;
    
    parameter IDLE = 0;
    parameter ADDR_SEND = 1;
    parameter DATA_READ = 2;
    
    // fifo
    wire fifo_full;
    wire prog_full; // 900 정도 차면 axi에게 멈추라는 신호 줌, 다시 900 보다 낮아지면 ddr에서 데이터 읽음
    // wire fifo_empty; 밖으로 뺌
    wire fifo_rd_en;
    
    assign fifo_rd_en = de;
    
    // 1. sequential logic
    always @(posedge clk_100Mhz) begin
        if (rst) begin
            state <= 0;
            next_state <= 0;
            ARADDR <= FRAME_BASE_ADDR;
            ADDR_OFFSET <= 0;
        end
        else begin
            state <= next_state;
            
            if (frame_done) begin // 한 프레임 끝나면 주소 초기화
                ADDR_OFFSET <= 0;
            end
            
            case (state)
                IDLE: begin
                    if (!prog_full) begin
                        ARADDR <= FRAME_BASE_ADDR + ADDR_OFFSET;
                    end
                end
                
                ADDR_SEND: begin
                    ARVALID <= 1;
                    if (ARREADY) begin
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
        .rd_data_count(),
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
