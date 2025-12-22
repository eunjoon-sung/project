module HDMI_Tx(
    input PXLCLK_I,       // 25MHz (Pixel Clock)
    input PXLCLK_5X_I,    // 125MHz (Serial Clock)
    input LOCKED_I,       // Clock Locked
    input RST_I,          // Reset

    input VGA_HS_I,       // HSYNC
    input VGA_VS_I,       // VSYNC
    input VGA_DE_I,       // Data Enable
    input [23:0] VGA_RGB_I, // {R, G, B} 8bit씩

    output HDMI_CLK_P,    // HDMI Clock (+)
    output HDMI_CLK_N,    // HDMI Clock (-)
    output [2:0] HDMI_DATA_P, // HDMI Data (+) R,G,B
    output [2:0] HDMI_DATA_N  // HDMI Data (-)
);

    wire [9:0] TMDS_red, TMDS_green, TMDS_blue;
    
    // 1. 8b/10b 인코딩 (아까 만든 파일 사용)
    TMDS_encoder encode_R(.clk(PXLCLK_I), .VD(VGA_RGB_I[23:16]), .CD(2'b00), .VDE(VGA_DE_I), .TMDS(TMDS_red));
    TMDS_encoder encode_G(.clk(PXLCLK_I), .VD(VGA_RGB_I[15:8]),  .CD(2'b00), .VDE(VGA_DE_I), .TMDS(TMDS_green));
    TMDS_encoder encode_B(.clk(PXLCLK_I), .VD(VGA_RGB_I[7:0]),   .CD({VGA_VS_I, VGA_HS_I}), .VDE(VGA_DE_I), .TMDS(TMDS_blue));

    // 2. 직렬화 및 출력 버퍼 (OSERDESE2 + OBUFDS)
    // Zynq/Artix-7 전용 Primitive 사용
    reg [4:0] TMDS_mod5 = 0;
    reg [9:0] TMDS_shift_red = 0, TMDS_shift_green = 0, TMDS_shift_blue = 0, TMDS_shift_clk = 0;
    
    always @(posedge PXLCLK_5X_I) begin
        if (RST_I) TMDS_mod5 <= 0;
        else TMDS_mod5 <= (TMDS_mod5 == 4) ? 0 : TMDS_mod5 + 1;
    end

    wire shift_load = (TMDS_mod5 == 4);

    always @(posedge PXLCLK_5X_I) begin
        if (shift_load) begin
            TMDS_shift_red   <= TMDS_red;
            TMDS_shift_green <= TMDS_green;
            TMDS_shift_blue  <= TMDS_blue;
            TMDS_shift_clk   <= 10'b1111100000; // Clock Pattern
        end else begin
            TMDS_shift_red   <= TMDS_shift_red   >> 1;
            TMDS_shift_green <= TMDS_shift_green >> 1;
            TMDS_shift_blue  <= TMDS_shift_blue  >> 1;
            TMDS_shift_clk   <= TMDS_shift_clk   >> 1;
        end
    end

    // 차동 신호 출력 (OBUFDS)
    OBUFDS OBUFDS_red  (.I(TMDS_shift_red[0]),   .O(HDMI_DATA_P[2]), .OB(HDMI_DATA_N[2]));
    OBUFDS OBUFDS_green(.I(TMDS_shift_green[0]), .O(HDMI_DATA_P[1]), .OB(HDMI_DATA_N[1]));
    OBUFDS OBUFDS_blue (.I(TMDS_shift_blue[0]),  .O(HDMI_DATA_P[0]), .OB(HDMI_DATA_N[0]));
    OBUFDS OBUFDS_clk  (.I(TMDS_shift_clk[0]),   .O(HDMI_CLK_P),     .OB(HDMI_CLK_N));

endmodule