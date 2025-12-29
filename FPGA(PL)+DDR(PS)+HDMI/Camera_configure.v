`timescale 1ns / 1ps

module Camera_configure
    #(
    parameter CLK_FREQ=25000000
    )
    (
    input wire rst,       // 보드 리셋 버튼
    input wire clk, // 보드 50MHz 클럭 핀
    input wire start,
    output wire sioc,
    output wire siod,
    output wire done
    );
    
    // 내부 신호 선언
    wire [7:0] rom_addr;
    wire [15:0] rom_dout;
    wire [7:0] SCCB_addr;
    wire [7:0] SCCB_data;
    wire SCCB_start;
    wire SCCB_ready;
    wire SCCB_SIOC_oe;
    wire SCCB_SIOD_oe;
    
    // Open-Drain 출력 버퍼
    assign sioc = SCCB_SIOC_oe ? 1'b0 : 1'bZ;
    assign siod = SCCB_SIOD_oe ? 1'b0 : 1'bZ;

    
    // 2. ROM 모듈 (sys_rst와 clk_25Mhz 사용)
    OV7670_config_rom rom1(
        .clk(clk), 
        .addr(rom_addr),
        .dout(rom_dout),
        .rst(rst)  
        );
        
    // 3. FSM 모듈 (sys_rst와 clk_25Mhz 사용)
    OV7670_config #(.CLK_FREQ(CLK_FREQ)) config_1(
        .clk(clk), 
        .SCCB_interface_ready(SCCB_ready),
        .rom_data(rom_dout),
        .start(start),
        .rom_addr(rom_addr),
        .done(done),
        .SCCB_interface_addr(SCCB_addr),
        .SCCB_interface_data(SCCB_data),
        .SCCB_interface_start(SCCB_start),
        .rst(rst) 
        );
    
    // 4. SCCB 모듈 (sys_rst와 clk_25Mhz 사용)
    SCCB_interface #( .CLK_FREQ(CLK_FREQ)) SCCB1(
        .clk(clk), 
        .start(SCCB_start),
        .address(SCCB_addr),
        .data(SCCB_data),
        .ready(SCCB_ready),
        .SIOC_oe(SCCB_SIOC_oe),
        .SIOD_oe(SCCB_SIOD_oe),
        .rst(rst) 
        );
    
endmodule