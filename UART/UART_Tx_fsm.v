`timescale 1ns / 1ps

module UART_Tx_fsm(
    input tx_start,
    input [7:0]to_tx,
    input clk,
    input rst,
    output reg tx_out,
    output reg busy    // 송신 flag
    );
    reg [10:0] shift_reg;
    reg [1:0] state;
    reg [1:0] next_state;
    reg [12:0] clk_cnt = 0; // 시스템 클럭 16Mhz과 전송 속도 맞추기 위함
    reg [3:0] bit_index = 0;

    parameter IDLE = 2'b00, // 아무것도 수신 x, rst 누른 후 상태
              LOAD = 2'b01, // rx단에서 보낸 rw bit, addr, data 가져오기 , bit reverse, 패리티 체크
              SEND = 2'b10; // 송신
	parameter BAUD_BIT = 1667; // (16MHz / 9600)

// clk 카운트 (Tx 이므로 sampling 할 필요 없음)
	always @(posedge clk or posedge rst) begin
    if (rst) begin // reset을 가장 최우선 적으로 처리하는 게 좋음. (rst || state == IDLE) 이렇게 하면 안됨
        clk_cnt <= 0;
        bit_index <= 0;
    end else if (state == SEND) begin // send 상태일 때만 clk_cnt 동작
        if (clk_cnt == BAUD_BIT - 1) begin
            clk_cnt <= 0;
            if (bit_index == 10) begin
                bit_index <= 0; // 모든 비트(0-10) 전송이 완료되면 비트 인덱스 리셋
            end else begin
                bit_index <= bit_index + 1;
            end
        end else begin
            clk_cnt <= clk_cnt + 1;
        end
    end else begin // IDLE or LOAD 상태
        clk_cnt <= 0;
        bit_index <= 0;
    end
end

// bit reverse (LSB(제일 마지막에 위치한 비트)부터 보내지므로 순서 바꿀 필요 있음)
    function [7:0] reverse_bits;
        input [7:0] in;
        integer i;
        begin
            for (i = 0; i < 8; i = i + 1)
                reverse_bits[i] = in[7 - i];
        end
    endfunction

// parity 오류 검출
    function parity_even;
        input [7:0] data;  // addr + data
        integer i;
        reg result;
        begin
            result = 0;
            for (i = 0; i < 8; i = i + 1)
                result = result ^ data[i];  // XOR로 1의 개수 판단
                parity_even = result;  // 1이면 홀수, 0이면 짝수
            end
    endfunction
	


	///// fsm //////
	// 1. state register
	always @(posedge clk or rst) begin
		if (rst) begin 
			state <= IDLE;
		end
		else begin
			state <= next_state;
		end
	end

	// 2. next-state logic
	always @(*) begin
		case (state)
			IDLE: begin
				if (tx_start) begin
					next_state = LOAD; // tx_start 신호가 들어오면 LOAD 상태로 전환
				end
				else begin
					next_state = IDLE;
				end
			end
			LOAD: begin
				next_state = SEND;
			end
			SEND: begin
				if (bit_index == 10) begin
					next_state = IDLE;
				end
				else begin
					next_state = SEND;
				end
			end
		endcase
	end
	// 3. output logic
	always @(posedge clk) begin
	case (state)
		IDLE: begin
			busy <= 0;
			shift_reg <= 0;
			tx_out <= 1'b1;
		end
		LOAD: begin
			shift_reg <= {1'b1, parity_even(to_tx), reverse_bits(to_tx), 1'b0}; // 거꾸로 해야 보낼 때 의도한 대로 보내짐
			busy <= 1;
		end
		SEND: begin
			if (bit_index < 10) begin
				if (clk_cnt == BAUD_BIT - 1) begin
					tx_out <= shift_reg[bit_index];
				end
				else begin
					tx_out <= tx_out; // clk_cnt가 BAUD_BIT - 1이 아닐 때는 tx_out을 유지
				end
			end
			else begin
				if (bit_index == 10) begin
					tx_out <= 1'b1;
					busy <= 0; // 송신 완료 후 busy 플래그를 0으로 설정
				end
			end
		end
	endcase
end
endmodule