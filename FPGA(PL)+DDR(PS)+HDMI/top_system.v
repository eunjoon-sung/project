`timescale 1ns / 1ps

module top_system(

    input wire sys_clk,
    input wire sys_rst_n,     // 보드 리셋 버튼 (Active Low 가정)
    
    input wire clk_25Mhz,
    input wire clk_125Mhz,
    // 1. 이 포트는 m_axi_w와 m_axi_r 인터페이스의 기준 클럭이며, 주파수는 100MHz임을 선언
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF m_axi_w:m_axi_r, FREQ_HZ 100000000" *)
    // 2. 이 포트가 '클럭' 신호임을 비바도에게 확정해줌
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk_100Mhz CLK" *)
    input wire clk_100Mhz,
    input wire locked, // PLL 락 신호
        
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
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axi_w AWADDR" *)
    (* mark_debug = "true" *) (* keep = "true" *)
    output wire [31:0] m_axi_w_awaddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axi_w AWVALID" *)
    output wire        m_axi_w_awvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axi_w AWREADY" *)
    input  wire        m_axi_w_awready, 
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axi_w AWLEN" *)
    output wire [7:0]  m_axi_w_awlen,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axi_w AWSIZE" *)
    output wire [2:0]  m_axi_w_awsize,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axi_w AWBURST" *)
    output wire [1:0]  m_axi_w_awburst,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axi_w AWCACHE" *)
    output wire [3:0]  m_axi_w_awcache,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axi_w AWPROT" *)
    output wire [2:0]  m_axi_w_awprot,
    
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axi_w WDATA" *)
    (* mark_debug = "true" *) (* keep = "true" *)
    output wire [63:0] m_axi_w_wdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axi_w WVALID" *)
    output wire        m_axi_w_wvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axi_w WREADY" *)
    input  wire        m_axi_w_wready,  
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axi_w WLAST" *)
    output wire        m_axi_w_wlast,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axi_w WSTRB" *)
    output wire [7:0]  m_axi_w_wstrb,
    
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axi_w BVALID" *)
    input  wire        m_axi_w_bvalid,  
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axi_w BREADY" *)
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
    
    // ILA
    // Verilog는 Scalar(wire)를 Vector(wire [0:0])에 연결해도 에러를 내지 않습니다.
    ila_0 your_ila_instance (
    .clk(clk_100Mhz),             // 반드시 클럭 연결
    .probe0(m_axi_r_araddr),  // 1비트 wire를 그냥 꽂으세요
    .probe1(m_axi_r_arvalid),
    .probe2(m_axi_r_arready),
    .probe3(m_axi_r_rdata),
    .probe4(m_axi_r_rvalid),
    .probe5(r_state),
    .probe6(m_axi_r_rready),
    .probe7(m_axi_r_rlast),
    .probe8(r_ADDR_OFFSET),
    .probe9(w_frame_done),
    .probe10(fifo_empty),
    .probe11(rd_enable)
    
);
    

    // -------------------------------------------------------
    // 1. 시스템 리셋 처리 (Active Low -> Active High 변환 등)
    // -------------------------------------------------------
    wire rst = ~sys_rst_n; 

    reg [20:0] power_on_timer = 0; 
    reg camera_reset_reg = 0; 
    
    // clk_25Mhz가 아닌, 항상 뛰는 sys_clk으로 감시
    always @(posedge clk_100Mhz) begin
        if (!sys_rst_n) begin
            // 물리적 리셋 버튼이 눌리면 즉시 초기화
            power_on_timer <= 0;
            camera_reset_reg <= 0; 
        end
        else if (!locked) begin
            // 클럭 위저드가 아직 불안정하면 리셋 유지
            power_on_timer <= 0;
            camera_reset_reg <= 0;
        end
        else begin
            // 클럭이 안정된(locked) 후에야 타이머 작동
            if (power_on_timer < 2000000) begin // 100MHz 기준이므로 20ms를 채우려면 카운트 값을 2,000,000으로 늘려야 합니다.
                power_on_timer <= power_on_timer + 1;
                camera_reset_reg <= 0; 
            end
            else begin
                camera_reset_reg <= 1; // 20ms 후에 리셋 해제
            end
        end
    end
    
    // -------------------------------------------------------
    // 2. Clock Wizard (기본 50MHz)
    // -------------------------------------------------------
    
    /*
    // Block Design 에서 선언해줄거임
    clk_wiz_0 u_clock_gen (
        .clk_in1(sys_clk),     // 25MHz for Capture Logic & Camera XCLK
        .reset(rst),
        .locked(locked),
        .clk_out1(clk_25Mhz),    
        .clk_out2(clk_125Mhz),   // 125Mhz for HDMI 2.0
        .clk_out3(clk_100Mhz)   // 100Mhz for DDR Memory
    );
    */
        
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
      .clk(clk_100Mhz),                // 클럭 연결
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
    wire w_prog_full;
    wire [1:0] w_state;
    wire [31:0] ADDR_OFFSET;
    
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
        .AWCACHE(m_axi_w_awcache),
        .AWPROT(m_axi_w_awprot),
        
        .WDATA(m_axi_w_wdata),
        .WVALID(m_axi_w_wvalid),
        .WREADY(m_axi_w_wready),
        .WLAST(m_axi_w_wlast),
        .WSTRB(m_axi_w_wstrb),
        
        .BVALID(m_axi_w_bvalid),
        .BREADY(m_axi_w_bready),
        
        .writer_done(writer_done),
        .buf_select(buf_select), // from top

        
        .o_prog_full(w_prog_full), // debugging 용,
        .state(w_state),
        .ADDR_OFFSET(ADDR_OFFSET)
    );
    wire writer_done;
    wire buf_select;
    reg buf_select_reg;
    reg writer_done_reg;
    
    // wire 신호 클럭에 동기화시킴
    
    always @(posedge clk_100Mhz or posedge rst) begin
        if (rst) begin
            buf_select_reg <= 0;
            writer_ready_flag <= 0;
        end else begin
            // 1. Writer가 완료되면 1
            if (writer_done) begin
                writer_done_reg <= 1;
            end
            // 2. Reader가 화면을 새로 그리려는 시점(0,0)에 flag on이면 스왑
            if (vsync_sync2 && writer_done_reg) begin
                buf_select_reg <= ~buf_select_reg;
                writer_done_reg <= 0;
            end
        end
    end

    // -------------------------------------------------------
    // 6. AXI4 READER (+ Asynchronous FIFO)
    // -------------------------------------------------------

    // HDMI로 나갈 데이터 선
    wire [15:0] pixel_data;
    wire rd_enable;
    wire fifo_empty;
    
    // for debug
    wire [1:0] r_state;
    wire [31:0] r_ADDR_OFFSET;
    
    
    AXI4_reader u_AXI_rd(
        // 1. System Inputs
        .clk_25Mhz(clk_25Mhz),          // [수정] 모듈 포트명에 맞춤 (외부 25MHz 연결)
        .clk_100Mhz(clk_100Mhz),   // AXI Clock
        .rst(!camera_reset_reg),
        
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
        .RLAST(m_axi_r_rlast),
        
        .buf_select(buf_select), // from top
        .vsync_sync2(vsync_sync2), // from VTG
        
        
        .state(r_state),
        .ADDR_OFFSET(r_ADDR_OFFSET)
        );
    
    // -------------------------------------------------------
    // 7. Video timing Generator.v + HDMI module
    // -------------------------------------------------------
    
    wire vsync_start_pulse;
    // 25Mhz -> 100Mhz 도메인 동기화
    always @(posedge clk_100Mhz) begin
        vsync_sync1 <= vsync_start_pulse;
        vsync_sync2 <= vsync_sync1;
    end
    
    Video_timing_generator u_Video_timing_gen (
        .clk(clk_25Mhz),
        .rst(!camera_reset_reg),
        .pixel_data(pixel_data),
        .hsync(o_hsync),
        .vsync(o_vsync),
        .de(o_de),
        .rd_enable(rd_enable),
        .rgb_data(rgb_data),
        .vsync_start_pulse(vsync_start_pulse)

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
