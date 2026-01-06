`timescale 1ns / 1ps

module top_system(
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 sys_clk CLK" *)
(* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF m_axi_w:m_axi_r, ASSOCIATED_RESET sys_rst_n, FREQ_HZ 50000000" *)
    input wire sys_clk,       // 보드 기본 클럭 (예: 50MHz or 100MHz)
    input wire sys_rst_n,     // 보드 리셋 버튼 (Active Low 가정)
    
    output wire o_clk_100Mhz,
    
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
    output wire [2:0] hdmi_data_n,
    
    
    // 1. AXI Writer Port (To Zynq HP0)
    output wire [31:0] m_axi_w_awaddr,
    output wire        m_axi_w_awvalid,
    input  wire        m_axi_w_awready, // Master 입장에서 Ready는 입력
    output wire [7:0]  m_axi_w_awlen,
    output wire [2:0]  m_axi_w_awsize,
    output wire [1:0]  m_axi_w_awburst,
    output wire [63:0] m_axi_w_wdata,
    output wire        m_axi_w_wvalid,
    input  wire        m_axi_w_wready,  // Master 입장에서 Ready는 입력
    output wire        m_axi_w_wlast,
    output wire [7:0]  m_axi_w_wstrb,
    input  wire        m_axi_w_bvalid,  // Response는 입력!
    output wire        m_axi_w_bready,

    // 2. AXI Reader Port (To Zynq HP1)
    output wire [31:0] m_axi_r_araddr,
    output wire        m_axi_r_arvalid,
    input  wire        m_axi_r_arready, // Master 입장에서 Ready는 입력!
    output wire [7:0]  m_axi_r_arlen,
    output wire [2:0]  m_axi_r_arsize,
    output wire [1:0]  m_axi_r_arburst,
    input  wire [63:0] m_axi_r_rdata,   // 읽어온 데이터는 입력!
    input  wire        m_axi_r_rvalid,  // Valid 신호도 입력!
    output wire        m_axi_r_rready,
    input  wire        m_axi_r_rlast

    );
    
    assign o_clk_100Mhz = clk_100Mhz;
    
    // -------------------------------------------------------
    // 1. 시스템 리셋 처리 (Active Low -> Active High 변환 등)
    // -------------------------------------------------------
    wire rst = ~sys_rst_n; 

    reg [19:0] power_on_timer = 0; // 약 20ms 대기용 타이머
    reg camera_reset_reg = 0;      // 카메라 리셋 제어 레지스터 (초기값 0: 리셋 상태)

    always @(posedge clk_25Mhz) begin // 여기 수정@!
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
    wire clk_100Mhz;
    wire locked; // PLL 락 신호
    
    clk_wiz_0 u_clock_gen (
        .clk_in1(sys_clk),     // 25MHz for Capture Logic & Camera XCLK
        .reset(rst),
        .locked(locked),
        .clk_out1(clk_25Mhz),    
        .clk_out2(clk_125Mhz),   // 125Mhz for HDMI 2.0
        .clk_out3(clk_100Mhz)   // 100Mhz for DDR Memory
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
    // 4. Camera input data read + downscaling + Chroma key
    // -------------------------------------------------------

    wire [15:0] w_pixel_data; // 16비트로 수정
    wire w_frame_done; // 한 프레임 완성 알림
    wire [9:0] w_x_count;
    wire [8:0] w_y_count;
    wire w_pixel_valid; // 한 픽셀 완성 알림
   Camera_capture u_cap (
    .rst(!camera_reset_reg),
    .p_clock(ov7670_pclk),
    .vsync(ov7670_vsync),
    .href(ov7670_href),
    .p_data(ov7670_data),
    .pixel_data(w_pixel_data),
    .frame_done(w_frame_done),
    .o_x_count(w_x_count),
    .o_y_count(w_y_count),
    .pixel_valid(w_pixel_valid)
    );
        
    // Chroma-Key Module
    wire [15:0] w_bg_data;
    
    Background_gen u_Back (
    .clk(ov7670_pclk),
    .rst(!camera_reset_reg),
    .h_count(w_x_count),
    .v_count(w_y_count),
    .bg_data(w_bg_data)
    );
    
    wire [7:0] G_min;
    wire [7:0] RG_max;
    
    vio_0 u_vio (
      .clk(ov7670_pclk),                // 클럭 연결
      .probe_out0(G_min),    // wire G_min에 연결 (8bit)
      .probe_out1(RG_max)    // wire RG_max에 연결 (8bit)
    );
    
    wire [15:0] w_mixed_data;
    Chroma_key_mixer u_Chroma (
    .clk(ov7670_pclk),
    .rst(!camera_reset_reg),
    .rgb_data(w_pixel_data),
    .bg_data(w_bg_data),
    .i_pixel_valid(w_pixel_valid),
    .G_min(G_min),
    .RG_max(RG_max),
    .mixed_data(w_mixed_data),
    .o_pixel_valid(w_o_pixel_valid)
    
    );
    
    wire w_o_pixel_valid;

    // -------------------------------------------------------
    // 5. AXI4 WRITER (+ Asynchronous FIFO)
    // -------------------------------------------------------
    
    
    AXI4_writer u_AXI_wr(
        .pclk(ov7670_pclk),
        .clk_100Mhz(clk_100Mhz),
        .rst(!camera_reset_reg),
        .mixed_data(w_mixed_data), // from Chroma_key_mixer.v
        .frame_done(w_frame_done), // from Camera_capture.v
        .pixel_valid(w_o_pixel_valid),
    
        // 2. AXI Master Interface
        .AWADDR(m_axi_w_awaddr),
        .AWVALID(m_axi_w_awvalid),
        .AWREADY(m_axi_w_awready),
        .AWLEN(m_axi_w_awlen),
        .AWSIZE(m_axi_w_awsize),
        .AWBURST(m_axi_w_awburst),
        
        .WDATA(m_axi_w_wdata),
        .WVALID(m_axi_w_wvalid),
        .WREADY(m_axi_w_wready),
        .WLAST(m_axi_w_wlast),
        .WSTRB(m_axi_w_wstrb),
        
        .BVALID(m_axi_w_bvalid),
        .BREADY(m_axi_w_bready)
    );

    
    // -------------------------------------------------------
    // 6. AXI4 READER (+ Asynchronous FIFO)
    // -------------------------------------------------------

    // HDMI로 나갈 데이터 선
    wire [15:0] pixel_data;
    wire rd_enable;
    wire fifo_empty;
    
    
    AXI4_reader u_AXI_rd(
        // 1. System Inputs
        .clk_25Mhz(clk_25Mhz),          // [수정] 모듈 포트명에 맞춤 (외부 25MHz 연결)
        .clk_100Mhz(clk_100Mhz),   // AXI Clock
        .rst(!camera_reset_reg),
        .frame_done(w_frame_done), // 주소 리셋용 (VSync)
        
        // 2. Video Interface (VTG로 감)
        .pixel_data(pixel_data),
        .fifo_empty(fifo_empty),
        .rd_enable(rd_enable),
        
        // 3. AXI Master Read Interface (Writer와 다른 선 사용!)
        .ARADDR(m_axi_r_araddr), 
        .ARVALID(m_axi_r_arvalid),
        .ARREADY(m_axi_r_arready),
        .ARLEN(m_axi_r_arlen),
        .ARSIZE(m_axi_r_arsize),
        .ARBURST(m_axi_r_arburst),
    
        .RDATA(m_axi_r_rdata),
        .RVALID(m_axi_r_rvalid),
        .RREADY(m_axi_r_rready),
        .RLAST(m_axi_r_rlast)
        );
    
    // -------------------------------------------------------
    // 7. Video timing Generator.v + HDMI module
    // -------------------------------------------------------
    
    Video_timing_generator u_Video_timing_gen (
        .clk(clk_25Mhz),
        .rst(!camera_reset_reg),
        .pixel_data(pixel_data),
        .hsync(o_hsync),
        .vsync(o_vsync),
        .de(o_de),
        .rd_enable(rd_enable),
        .rgb_data(rgb_data)
    );
    
    
    wire o_hsync;
    wire o_vsync;
    wire o_de;
    wire [23:0] rgb_data;
    
        
    // (B) HDMI 인코더 (병렬 -> 직렬 변환)
    // 이 모듈이 없으면 모니터 연결 불가!
    assign hdmi_oen = 1'b1; // HDMI Output Enable
    HDMI_Tx u_hdmi (
        .PXLCLK_I(clk_25Mhz),
        .PXLCLK_5X_I(clk_125Mhz), // 5배 빠른 클럭
        .LOCKED_I(locked),
        .RST_I(!camera_reset_reg),
        
        // 타이밍 제너레이터에서 만든 신호 연결
        .VGA_HS_I(o_hsync),
        .VGA_VS_I(o_vsync),
        .VGA_DE_I(o_de),
        .VGA_RGB_I(rgb_data), // {R, G, B} 순서
        
        // 실제 HDMI 포트로 나가는 신호
        .HDMI_CLK_P(hdmi_clk_p),
        .HDMI_CLK_N(hdmi_clk_n),
        .HDMI_DATA_P(hdmi_data_p),
        .HDMI_DATA_N(hdmi_data_n)
    );
        // -------------------------------------------------------
    // 8. Debug LED (보험)
    // -------------------------------------------------------
    reg [25:0] beat_cnt;
    always @(posedge clk_25Mhz) beat_cnt <= beat_cnt + 1;
    
    assign led[0] = beat_cnt[25];  // Heartbeat (시스템 생존 확인)
    assign led[1] = locked;        // Clock PLL Lock
    assign led[2] = !fifo_empty;   // FIFO에 데이터가 있는지 (켜져야 좋음)
    assign led[3] = o_de;          // HDMI 데이터 출력 중인지
             
endmodule
