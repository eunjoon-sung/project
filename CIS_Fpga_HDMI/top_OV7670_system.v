`timescale 1ns / 1ps

module top_OV7670_system(
    input wire sys_clk,       // 보드 기본 클럭 (예: 50MHz or 100MHz)
    input wire sys_rst_n,     // 보드 리셋 버튼 (Active Low 가정)
    
    // OV7670 Camera Interface
    input wire ov7670_pclk,
    input wire ov7670_vsync,
    input wire ov7670_href,
    input wire [7:0] ov7670_data,
    
    output wire ov7670_xclk,  // 카메라에 공급할 24~25MHz 클럭 (MCLK)
    output wire ov7670_sioc,  // I2C Clock
    inout  wire ov7670_siod,  // I2C Data
    output wire ov7670_pwdn,  // Power Down (0)
    output wire ov7670_reset, 
    
    // --- Debug LED (옵션) ---
    output wire [3:0] led,
    
    // --- HDMI 출력 ---
    output wire hdmi_oen,
    output wire hdmi_clk_p,
    output wire hdmi_clk_n,
    output wire [2:0] hdmi_data_p,
    output wire [2:0] hdmi_data_n
    );
    
    // ILA 파형
    ila_0 ila (
    .clk(sys_clk),
    .probe0(w_bram_addr),
    .probe1(w_bram_data),
    .probe2(w_bram_we),
    .probe3(ov7670_href)
    );
    
    // -------------------------------------------------------
    // 1. 시스템 리셋 처리 (Active Low -> Active High 변환 등)
    // -------------------------------------------------------
    wire rst = ~sys_rst_n; 

    reg [19:0] power_on_timer = 0; // 약 20ms 대기용 타이머
    reg camera_reset_reg = 0;      // 카메라 리셋 제어 레지스터 (초기값 0: 리셋 상태)

    always @(posedge sys_clk) begin
        if (!sys_rst_n || !locked) begin
            // 리셋 버튼을 누르거나, 클럭이 불안정하면 -> 카메라를 리셋시킨다(0).
            power_on_timer <= 0;
            camera_reset_reg <= 0; 
        end
        else begin
            // 리셋이 풀리고 클럭이 안정되면 -> 시간을 잰다.
            if (power_on_timer < 1000000) begin // 약 10ms~20ms 대기 (50MHz 기준)
                power_on_timer <= power_on_timer + 1;
                camera_reset_reg <= 0; // 아직은 리셋 유지 (기다려!)
            end
            else begin
                camera_reset_reg <= 1; 
            end
        end
    end

    
    // -------------------------------------------------------
    // 2. Clock Wizard (기본 50MHz)
    // -------------------------------------------------------
    wire clk_25Mhz; 
    wire clk_125Mhz;
    wire locked; // PLL 락 신호
    
    clk_wiz_0 u_clock_gen (
        .clk_out1(clk_25Mhz),     // 25MHz for Logic & Camera XCLK
        .reset(rst),
        .locked(locked),
        .clk_in1(sys_clk),
        .clk_out2(clk_125Mhz)   // 125Mhz for HDMI 2.0
    );
    
    // 카메라 기본 신호 연결
    assign ov7670_xclk = clk_25Mhz; // 카메라에게 MCLK 공급
    assign ov7670_pwdn = 0;       // 항상 켜짐
    assign ov7670_reset = camera_reset_reg;      // (주의: 회로도에 따라 0일수도 1일수도 있음. 보통 1=Reset이면 0이어야 함)
    
    // -------------------------------------------------------
    // 3. Camera Configuration (I2C 설정)
    // -------------------------------------------------------
    
    wire o_SCCB_ready;
    wire config_done;
    wire w_sioc;
    wire w_siod;
    
    assign ov7670_siod = w_siod;
    assign ov7670_sioc = w_sioc;    
    // Camera_configure 연결
    Camera_configure #(.CLK_FREQ(25000000)) u_config (
        .rst(!camera_reset_reg),
        .clk(clk_25Mhz),      // [핵심] 위에서 만든 25MHz를 넣어줌!
        .start(1'b1),
        .sioc(w_sioc),
        .siod(ov7670_siod),
        .done(config_done),
        .o_SCCB_ready(o_SCCB_ready)
         );

    // -------------------------------------------------------
    // 4. Data Capture Pipeline
    // -------------------------------------------------------
    
    wire [16:0] w_bram_addr;
    wire [11:0] w_bram_data;
    wire w_bram_we = bram_we;
    wire w_frame_done = frame_done;
    
    Camera_to_SRAM u_Camera(
        .p_clock(ov7670_pclk),
        .rst(!camera_reset_reg),
        .vsync(ov7670_vsync),
        .href(ov7670_href),
        .p_data(ov7670_data),
        .bram_addr(w_bram_addr),
        .bram_data(w_bram_data),
        .bram_we(bram_we),
        .frame_done(frame_done)
    );
    
    // (E) BRAM (Storage)
    // Port A: Write Only (Camera)
    // Port B: Read Only (HDMI)
 
   
    blk_mem_gen_0 u_buffer (
        .ena(1'b1),
        .clka(ov7670_pclk),
        .wea(w_bram_we),       // IP 설정에 따라 [0:0] 벡터일 수도 있음
        .addra(w_bram_addr),
        .dina(w_bram_data),
        
        // Port B는 나중에 HDMI 모듈 연결할 곳 !
        // Port B (읽기)
        .clkb(clk_25Mhz),
        .addrb(w_rd_addr),  // 타이밍 생성기가 계산한 주소
        .doutb(w_bram_data_out), // 나온 데이터
        .enb(1'b1) // 항상 켜둠
    );
  
   // -------------------------------------------------------
    // 5. 비디오 출력 파트 (SRAM -> Timing Gen -> HDMI)
    // -------------------------------------------------------
    /*
    // (A) Timing_generator
    wire [16:0] w_rd_addr;
    wire [23:0] w_rgb_data;
    wire w_hsync, w_vsync, w_de;
    wire [11:0] w_bram_data_out;
    wire [9:0] o_h_count,o_v_count;
    
    Video_timing_generator u_timing_gen (
        .clk(clk_25Mhz), 
        .rst(!camera_reset_reg),
        .sram_data(w_bram_data_out), // SRAM Port B dout
        
        .rd_addr(w_rd_addr),         // -> SRAM Port B addr
        .rgb_data(w_rgb_data),
        .hsync(w_hsync),
        .vsync(w_vsync),
        .de(w_de),
        .o_h_count(o_h_count),
        .o_v_count(o_v_count)
    );
    
    // (B) HDMI 인코더 (병렬 -> 직렬 변환)
    assign hdmi_oen = 1; // HDMI Output Enable
    HDMI_Tx u_hdmi (
        .PXLCLK_I(clk_25Mhz),
        .PXLCLK_5X_I(clk_125Mhz), // 5배 빠른 클럭
        .LOCKED_I(camera_reset_reg),
        .RST_I(!camera_reset_reg),
        
        // 타이밍 제너레이터에서 만든 신호 연결
        .VGA_HS_I(w_hsync),
        .VGA_VS_I(w_vsync),
        .VGA_DE_I(w_de),
        .VGA_RGB_I(w_rgb_data), // {R, G, B} 순서
        
        // 실제 HDMI 포트로 나가는 신호
        .HDMI_CLK_P(hdmi_clk_p),
        .HDMI_CLK_N(hdmi_clk_n),
        .HDMI_DATA_P(hdmi_data_p),
        .HDMI_DATA_N(hdmi_data_n)
    );
    */

    // -------------------------------------------------------
    // 5. 비디오 출력 파트 + Chroma-Key 
    // (SRAM -> Timing Gen -> Background_gen -> Chromakey mixer (VIO로 조절)-> HDMI)
    // -------------------------------------------------------

        // (A) Timing_generator
    wire [16:0] w_rd_addr;
    wire [23:0] w_rgb_data;
    wire w_hsync, w_vsync, w_de;
    wire [11:0] w_bram_data_out;
    wire [9:0] o_h_count,o_v_count;
    
    Video_timing_generator u_timing_gen (
        .clk(clk_25Mhz), 
        .rst(!camera_reset_reg),
        .sram_data(w_bram_data_out), // SRAM Port B dout
        
        .rd_addr(w_rd_addr),         // -> SRAM Port B addr
        .rgb_data(w_rgb_data),
        .hsync(w_hsync),
        .vsync(w_vsync),
        .de(w_de),
        .o_h_count(o_h_count),
        .o_v_count(o_v_count)
    );
    
    wire [23:0] w_bg_data;
    wire [7:0] G_min;
    wire [7:0] RG_max;
    wire [23:0] w_mixed_data;
    wire o_hsync, o_vsync, o_de;
    
    // Chroma-Key Module
    Background_gen u_Back (
    .clk(clk_25Mhz),
    .rst(!camera_reset_reg),
    .h_count(o_h_count),
    .v_count(o_v_count),
    .bg_data(w_bg_data)
    );
    
    vio_0 u_vio (
      .clk(clk_25Mhz),        // 클럭 연결
      .probe_out0(G_min),    // wire G_min에 연결 (8bit)
      .probe_out1(RG_max)    // wire RG_max에 연결 (8bit)
    );
    
    Chroma_key_mixer u_Chroma (
    .clk(clk_25Mhz),
    .rst(!camera_reset_reg),
    .rgb_data(w_rgb_data),
    .bg_data(w_bg_data),
    .i_hsync(w_hsync),
    .i_vsync(w_vsync),
    .i_de(w_de),
    .G_min(G_min),
    .RG_max(RG_max),
    .mixed_data(w_mixed_data),
    .o_hsync(o_hsync),
    .o_vsync(o_vsync),
    .o_de(o_de)
    
    );
    
    // (B) HDMI 인코더 (병렬 -> 직렬 변환)
    // 이 모듈이 없으면 모니터 연결 불가!
    assign hdmi_oen = 1'b1; // HDMI Output Enable
    HDMI_Tx u_hdmi (
        .PXLCLK_I(clk_25Mhz),
        .PXLCLK_5X_I(clk_125Mhz), // 5배 빠른 클럭
        .LOCKED_I(camera_reset_reg),
        .RST_I(!camera_reset_reg),
        
        // 타이밍 제너레이터에서 만든 신호 연결  [이 부분 크로마키 모듈로 인해 수정]
        .VGA_HS_I(o_hsync),
        .VGA_VS_I(o_vsync),
        .VGA_DE_I(o_de),
        .VGA_RGB_I(w_mixed_data), // {R, G, B} 순서
        
        // 실제 HDMI 포트로 나가는 신호
        .HDMI_CLK_P(hdmi_clk_p),
        .HDMI_CLK_N(hdmi_clk_n),
        .HDMI_DATA_P(hdmi_data_p),
        .HDMI_DATA_N(hdmi_data_n)
    );

    
    
    // Debugging LEDs
    assign led[0] = config_done; // 설정 완료되면 켜짐
    assign led[1] = w_frame_done;// 프레임마다 깜빡임
    assign led[2] = w_bram_we; // FIFO 꽉 차면 켜짐 (에러)
    assign led[3] = locked;      // 클럭 락 되면 켜짐

endmodule