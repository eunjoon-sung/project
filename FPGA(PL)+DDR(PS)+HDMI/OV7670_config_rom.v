`timescale 1ns / 1ps

module OV7670_config_rom(
    input wire rst,
    input wire clk,
    input wire [7:0] addr,
    output reg [15:0] dout
    );
    //FFFF is end of rom, FFF0 is delay
    always @(posedge clk or posedge rst) begin
        if (rst) dout <= 0;
			case(addr) 
			0:  dout <= 16'h12_80; //reset
			1:  dout <= 16'hFF_F0; // delay
			2:  dout <= 16'h12_04; // COM7,     set RGB color output
			3:  dout <= 16'h11_80; // CLKRC     internal PLL matches input clock
			4:  dout <= 16'h0C_00; // COM3,     default settings
			5:  dout <= 16'h3E_00; // COM14,    no scaling, normal pclock
			6:  dout <= 16'h04_00; // COM1,     disable CCIR656
			7:  dout <= 16'h40_d0; //COM15,     RGB444, full output range [주의] c0으로 하면 화면 이상하게 나옴
			8:  dout <= 16'h3a_04; //TSLB       set correct output data sequence (magic)
			9:  dout <= 16'h14_18; //COM9       MAX AGC value x4
	/*
			10: dout <= 16'h4F_B3; //MTX1       all of these are magical matrix coefficients
			11: dout <= 16'h50_B3; //MTX2
			12: dout <= 16'h51_00; //MTX3
			13: dout <= 16'h52_3D; //MTX4
			14: dout <= 16'h53_A7; //MTX5
			15: dout <= 16'h54_E4; //MTX6
			16: dout <= 16'h58_9E; //MTXS
	*/
			10: dout <= 16'h4F_80; // MTX1 (기존 B3 -> 80)
			11: dout <= 16'h50_80; // MTX2 (기존 B3 -> 80)
			12: dout <= 16'h51_00; // MTX3 (유지)
			13: dout <= 16'h52_22; // MTX4 (기존 3D -> 22)
			14: dout <= 16'h53_5E; // MTX5 (기존 A7 -> 5E)
			15: dout <= 16'h54_80; // MTX6 (기존 E4 -> 80)
			16: dout <= 16'h58_9E; // MTXS (유지)       
			17: dout <= 16'h8c_00;
			18: dout <= 16'hA2_02;
			
			17: dout <= 16'h8c_00;
			18: dout <= 16'hA2_02;
			
			19: dout <= 16'h3D_C0; //COM13      sets gamma enable, does not preserve reserved bits, may be wrong?
			20: dout <= 16'h17_14; //HSTART     start high 8 bits
			21: dout <= 16'h18_02; //HSTOP      stop high 8 bits //these kill the odd colored line
			22: dout <= 16'h32_80; //HREF       edge offset
			23: dout <= 16'h19_03; //VSTART     start high 8 bits
			24: dout <= 16'h1A_7B; //VSTOP      stop high 8 bits
			25: dout <= 16'h03_0A; //VREF       vsync edge offset
			26: dout <= 16'h0F_41; //COM6       reset timings
			27: dout <= 16'h1E_00; //MVFP       disable mirror / flip //might have magic value of 03
			28: dout <= 16'h33_0B; //CHLF       //magic value from the internet
			29: dout <= 16'h3C_78; //COM12      no HREF when VSYNC low
			30: dout <= 16'h69_00; //GFIX       fix gain control
			31: dout <= 16'h74_00; //REG74      Digital gain control
			32: dout <= 16'hB0_84; //RSVD       magic value from the internet *required* for good color
			33: dout <= 16'hB1_0C; //ABLC1
			34: dout <= 16'h13_E7; // COM8: AGC(게인), AEC(노출) 켜기! (필수)
			// [AWB(화이트밸런스)를 위한 필수 튜닝 값]
			// 이게 없으면 E7을 켜도 색이 이상할 수 있습니다.
		
			// AWB 제어 레지스터 (Advanced AWB)
			// 파란색/빨간색의 이득(Gain) 범위를 지정합니다.
			35: dout <= 16'h01_F0; // BLUE Gain
			36: dout <= 16'h02_F0; // RED Gain
			37: dout <= 16'h6F_9F; // Simple AWB Control Enable // [추가]
			default: dout <= 16'hFF_FF;         //mark end of ROM
		endcase
    end
endmodule
