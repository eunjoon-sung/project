//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2025.1 (win64) Build 6140274 Thu May 22 00:12:29 MDT 2025
//Date        : Tue Feb  3 21:58:33 2026
//Host        : DESKTOP-K5FJDPT running 64-bit major release  (build 9200)
//Command     : generate_target design_1_wrapper.bd
//Design      : design_1_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module design_1_wrapper
   (DDR_addr,
    DDR_ba,
    DDR_cas_n,
    DDR_ck_n,
    DDR_ck_p,
    DDR_cke,
    DDR_cs_n,
    DDR_dm,
    DDR_dq,
    DDR_dqs_n,
    DDR_dqs_p,
    DDR_odt,
    DDR_ras_n,
    DDR_reset_n,
    DDR_we_n,
    FIXED_IO_ddr_vrn,
    FIXED_IO_ddr_vrp,
    FIXED_IO_mio,
    FIXED_IO_ps_clk,
    FIXED_IO_ps_porb,
    FIXED_IO_ps_srstb,
    hdmi_clk_n_0,
    hdmi_clk_p_0,
    hdmi_data_n_0,
    hdmi_data_p_0,
    hdmi_oen_0,
    led_0,
    ov7670_data_0,
    ov7670_href_0,
    ov7670_pclk_0,
    ov7670_pwdn_0,
    ov7670_reset_0,
    ov7670_sioc_0,
    ov7670_siod_0,
    ov7670_vsync_0,
    ov7670_xclk_0,
    sys_clk_0,
    sys_rst_n_0);
  inout [14:0]DDR_addr;
  inout [2:0]DDR_ba;
  inout DDR_cas_n;
  inout DDR_ck_n;
  inout DDR_ck_p;
  inout DDR_cke;
  inout DDR_cs_n;
  inout [3:0]DDR_dm;
  inout [31:0]DDR_dq;
  inout [3:0]DDR_dqs_n;
  inout [3:0]DDR_dqs_p;
  inout DDR_odt;
  inout DDR_ras_n;
  inout DDR_reset_n;
  inout DDR_we_n;
  inout FIXED_IO_ddr_vrn;
  inout FIXED_IO_ddr_vrp;
  inout [53:0]FIXED_IO_mio;
  inout FIXED_IO_ps_clk;
  inout FIXED_IO_ps_porb;
  inout FIXED_IO_ps_srstb;
  output hdmi_clk_n_0;
  output hdmi_clk_p_0;
  output [2:0]hdmi_data_n_0;
  output [2:0]hdmi_data_p_0;
  output hdmi_oen_0;
  output [3:0]led_0;
  input [7:0]ov7670_data_0;
  input ov7670_href_0;
  input ov7670_pclk_0;
  output ov7670_pwdn_0;
  output ov7670_reset_0;
  output ov7670_sioc_0;
  inout ov7670_siod_0;
  input ov7670_vsync_0;
  output ov7670_xclk_0;
  input sys_clk_0;
  input sys_rst_n_0;

  wire [14:0]DDR_addr;
  wire [2:0]DDR_ba;
  wire DDR_cas_n;
  wire DDR_ck_n;
  wire DDR_ck_p;
  wire DDR_cke;
  wire DDR_cs_n;
  wire [3:0]DDR_dm;
  wire [31:0]DDR_dq;
  wire [3:0]DDR_dqs_n;
  wire [3:0]DDR_dqs_p;
  wire DDR_odt;
  wire DDR_ras_n;
  wire DDR_reset_n;
  wire DDR_we_n;
  wire FIXED_IO_ddr_vrn;
  wire FIXED_IO_ddr_vrp;
  wire [53:0]FIXED_IO_mio;
  wire FIXED_IO_ps_clk;
  wire FIXED_IO_ps_porb;
  wire FIXED_IO_ps_srstb;
  wire hdmi_clk_n_0;
  wire hdmi_clk_p_0;
  wire [2:0]hdmi_data_n_0;
  wire [2:0]hdmi_data_p_0;
  wire hdmi_oen_0;
  wire [3:0]led_0;
  wire [7:0]ov7670_data_0;
  wire ov7670_href_0;
  wire ov7670_pclk_0;
  wire ov7670_pwdn_0;
  wire ov7670_reset_0;
  wire ov7670_sioc_0;
  wire ov7670_siod_0;
  wire ov7670_vsync_0;
  wire ov7670_xclk_0;
  wire sys_clk_0;
  wire sys_rst_n_0;

  design_1 design_1_i
       (.DDR_addr(DDR_addr),
        .DDR_ba(DDR_ba),
        .DDR_cas_n(DDR_cas_n),
        .DDR_ck_n(DDR_ck_n),
        .DDR_ck_p(DDR_ck_p),
        .DDR_cke(DDR_cke),
        .DDR_cs_n(DDR_cs_n),
        .DDR_dm(DDR_dm),
        .DDR_dq(DDR_dq),
        .DDR_dqs_n(DDR_dqs_n),
        .DDR_dqs_p(DDR_dqs_p),
        .DDR_odt(DDR_odt),
        .DDR_ras_n(DDR_ras_n),
        .DDR_reset_n(DDR_reset_n),
        .DDR_we_n(DDR_we_n),
        .FIXED_IO_ddr_vrn(FIXED_IO_ddr_vrn),
        .FIXED_IO_ddr_vrp(FIXED_IO_ddr_vrp),
        .FIXED_IO_mio(FIXED_IO_mio),
        .FIXED_IO_ps_clk(FIXED_IO_ps_clk),
        .FIXED_IO_ps_porb(FIXED_IO_ps_porb),
        .FIXED_IO_ps_srstb(FIXED_IO_ps_srstb),
        .hdmi_clk_n_0(hdmi_clk_n_0),
        .hdmi_clk_p_0(hdmi_clk_p_0),
        .hdmi_data_n_0(hdmi_data_n_0),
        .hdmi_data_p_0(hdmi_data_p_0),
        .hdmi_oen_0(hdmi_oen_0),
        .led_0(led_0),
        .ov7670_data_0(ov7670_data_0),
        .ov7670_href_0(ov7670_href_0),
        .ov7670_pclk_0(ov7670_pclk_0),
        .ov7670_pwdn_0(ov7670_pwdn_0),
        .ov7670_reset_0(ov7670_reset_0),
        .ov7670_sioc_0(ov7670_sioc_0),
        .ov7670_siod_0(ov7670_siod_0),
        .ov7670_vsync_0(ov7670_vsync_0),
        .ov7670_xclk_0(ov7670_xclk_0),
        .sys_clk_0(sys_clk_0),
        .sys_rst_n_0(sys_rst_n_0));
endmodule
