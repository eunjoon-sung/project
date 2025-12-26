`timescale 1ns / 1ps

module top_system(
    input wire sys_clk,       // 100MHz or 50MHz System Clock
    input wire sys_rst_n,     // Active Low Reset
    
    // OV7670 Camera Interface
    input wire ov7670_pclk,
    input wire ov7670_vsync,
    input wire ov7670_href,
    input wire [7:0] ov7670_data,
    
    output wire ov7670_xclk,  // MCLK (25MHz)
    output wire ov7670_sioc,  
    inout  wire ov7670_siod,  
    output wire ov7670_pwdn,  
    output wire ov7670_reset, 

    // HDMI Interface
    output wire hdmi_oen,
    output wire hdmi_clk_p,
    output wire hdmi_clk_n,
    output wire [2:0] hdmi_data_p,
    output wire [2:0] hdmi_data_n,
    
    // [DEBUG] LED for Status Check
    output wire [3:0] led 
    );
    
    // -------------------------------------------------------
    // 1. System Reset & Clock Logic
    // -------------------------------------------------------
    wire rst_in = ~sys_rst_n; // Active High 변환

    wire clk_25Mhz;  // Pixel Clock
    wire clk_100Mhz; // AXI Clock
    wire clk_125Mhz; // HDMI Serial Clock (5x)
    wire locked;     // PLL Lock Signal

    // Clock Wizard
    clk_wiz_0 u_clock_gen (
        .reset(rst_in),
        .locked(locked),
        .clk_in1(sys_clk),
        .clk_out1(clk_25Mhz),   
        .clk_out2(clk_100Mhz),     
        .clk_out3(clk_125Mhz)   
    );

    // Power-on Reset Sequence for Camera
    reg [19:0] power_on_timer = 0;
    reg camera_reset_reg = 1; // 1: Reset Active

    always @(posedge clk_25Mhz) begin
        if (!locked) begin
            power_on_timer <= 0;
            camera_reset_reg <= 1; // Reset holding
        end
        else begin
            if (power_on_timer < 200000) begin // Wait for stable clock
                power_on_timer <= power_on_timer + 1;
                camera_reset_reg <= 1; 
            end
            else begin
                camera_reset_reg <= 0; // Reset Release (Active High Reset이었다면 0으로 풀어줌)
            end
        end
    end
    
    // Global System Reset (Logic용)
    wire sys_rst = camera_reset_reg; 

    // Camera Control Signals
    assign ov7670_xclk  = clk_25Mhz; 
    assign ov7670_pwdn  = 0;       
    assign ov7670_reset = sys_rst;      

    // -------------------------------------------------------
    // 2. Camera Configuration (I2C)
    // -------------------------------------------------------
    wire w_sioc, w_siod_out;
    assign ov7670_sioc = w_sioc;
    assign ov7670_siod = w_siod_out; // Inout 처리는 하위 모듈이나 Tristate 버퍼 필요 (생략)

    Camera_configure #(.CLK_FREQ(25000000)) u_config (
        .rst(sys_rst),
        .clk(clk_25Mhz),      
        .start(1'b1),
        .sioc(w_sioc),
        .siod(ov7670_siod), // Inout port passing
        .done(),
        .o_SCCB_ready()
    );

    // -------------------------------------------------------
    // 3. Image Capture & Chroma Key Pipeline
    // -------------------------------------------------------
    wire [15:0] w_cam_pixel_data;
    wire w_cam_valid;
    wire w_frame_done;
    wire [9:0] w_x_count, w_y_count;
    
    Camera_capture u_Camera(
        .p_clock(ov7670_pclk),
        .rst(sys_rst),
        .vsync(ov7670_vsync),
        .href(ov7670_href),
        .p_data(ov7670_data),
        .pixel_data(w_cam_pixel_data),
        .pixel_valid(w_cam_valid),
        .o_x_count(w_x_count),
        .o_y_count(w_y_count),
        .frame_done(w_frame_done)
    );
    
    wire [15:0] w_bg_data;
    Background_gen u_Back (
        .clk(clk_25Mhz),
        .rst(sys_rst),
        .h_count(w_x_count),
        .v_count(w_y_count),
        .bg_data(w_bg_data)
    );

    wire [7:0] G_min, RG_max;
    vio_0 u_vio (
        .clk(clk_25Mhz),
        .probe_out0(G_min),
        .probe_out1(RG_max)
    );

    wire [15:0] w_mixed_data;
    wire w_mixed_valid;

    Chroma_key_mixer u_Chroma (
        .clk(clk_25Mhz),
        .rst(sys_rst),
        .rgb_data(w_cam_pixel_data),
        .bg_data(w_bg_data),
        .i_pixel_valid(w_cam_valid),
        .G_min(G_min),
        .RG_max(RG_max),
        .mixed_data(w_mixed_data),
        .o_pixel_valid(w_mixed_valid)
    );

    // -------------------------------------------------------
    // 4. AXI4 Writer & Reader (Connecting Memory)
    // -------------------------------------------------------
    
    // Writer: DDR에 쓰기
    AXI4_writer u_AXI4_writer (
        .pclk(clk_25Mhz),
        .clk_100Mhz(clk_100Mhz),
        .rst(sys_rst),
        .mixed_data(w_mixed_data),   // Chroma Key 결과물 입력
        .pixel_valid(w_mixed_valid), // Valid 신호
        .frame_done(w_frame_done)
        // Master AXI Port는 내부 Wrapper 처리 가정
    );

    // [중요 수정] Reader와 VTG 연결
    wire [15:0] w_axi_rdata; // Reader에서 읽어온 데이터
    wire w_vtg_rd_en;        // VTG가 요청하는 Read Enable 신호

    AXI4_reader u_AXI4_reader (
        .pclk(clk_25Mhz),
        .clk_100Mhz(clk_100Mhz),
        .rst(sys_rst),
        
        // [수정됨] 주소 입력(rd_addr) 삭제 -> Read Enable(rd_enable) 입력으로 변경
        .rd_enable(w_vtg_rd_en),   // From VTG
        .rgb_data_out(w_axi_rdata) // To VTG (16bit)
        
        // Master AXI Port는 내부 Wrapper 처리 가정
    );

    // -------------------------------------------------------
    // 5. Video Timing Generator (with Line Buffer Upscaling)
    // -------------------------------------------------------
    
    wire w_hsync, w_vsync, w_de;
    wire [23:0] w_final_rgb; // HDMI로 보낼 최종 24bit 데이터
    
    Video_timing_generator u_timing_gen (
        .clk(clk_25Mhz), 
        .rst(sys_rst),
        
        // Data Interface (FIFO Style)
        .pixel_data(w_axi_rdata), // From AXI Reader
        .rd_enable(w_vtg_rd_en),  // To AXI Reader (Control Signal)
        
        // Output to HDMI
        .hsync(w_hsync),
        .vsync(w_vsync),
        .de(w_de),
        .rgb_data(w_final_rgb) // 24-bit Upscaled Data
        
    );
    
    // -------------------------------------------------------
    // 6. HDMI Transmitter
    // -------------------------------------------------------
    
    assign hdmi_oen = 1'b1;

    HDMI_Tx u_hdmi (
        .PXLCLK_I(clk_25Mhz),
        .PXLCLK_5X_I(clk_125Mhz), // Serial Clock
        .LOCKED_I(locked),        // PLL Lock
        .RST_I(sys_rst),
        
        // [수정됨] VTG 출력을 연결 (카메라 직결 X)
        .VGA_HS_I(w_hsync),
        .VGA_VS_I(w_vsync),
        .VGA_DE_I(w_de),
        .VGA_RGB_I(w_final_rgb),  // {R, G, B} 888 Format
        
        // Physical Ports
        .HDMI_CLK_P(hdmi_clk_p),
        .HDMI_CLK_N(hdmi_clk_n),
        .HDMI_DATA_P(hdmi_data_p),
        .HDMI_DATA_N(hdmi_data_n)
    );


endmodule