`timescale 1ns / 1ps
/*
              bit index
start 1 bit      1
R/W 1 bit        2 
address 3 bit    3 4 5
data 4 bit       6 7 8 9 
parity 1 bit     10
stop 1 bit       11
*/
module UART_Rx_fsm (
	input wire clk,
	input wire rst,
	input wire rx,             // UART Rx 선
	output reg [7:0] rx_data,  // 수신된 데이터
	output reg tx_start,       // REPLY flag
	output reg rw_bit,         // 1이면 R 0이면 W
	output reg [6:0] to_tx     // Tx로 보낼 주소와 데이터
);
reg [3:0] mem [0:7]; // 메모리 4bit 8개. 주소가 3bit로 들어오기 때문
reg [12:0] clk_cnt = 0; // 시스템 클럭 16Mhz과 전송 속도 맞추기 위함
reg [2:0] state;
reg [2:0] next_state;
reg [3:0] sampling_cnt;
reg s_done = 0; // sampling 완료 플래그
reg [3:0] bit_index = 0; // total 11bit
reg [2:0] addr_buffer = 0; // 읽은 주소 저장하는 버퍼
reg [3:0] data_buffer = 0; // 읽은 주소에 저장된 data를 저장하는 버퍼
reg [3:0] new_data = 0; // 새로 읽은 데이터 저장
reg rx_0, rx_1; // rx start, rx end 신호 감지
reg sampling_on = 0; // 104번 카운트 되면 on
wire rx_start; // start flag	
reg parity_bit;          // 수신된 패리티 비트 저장
reg parity_calc_result;  // 계산된 패리티 결과 저장
reg parity_error;        // 오류 플래그
reg [2:0] addr_tx; // tx단에 보낼 addr
reg [3:0] data_tx; // tx단에 보낼 data

// 시뮬레이션 초기화 블록 (합성 안됨)
initial begin
	mem[0] = 4'b0001;
	mem[1] = 4'b0010;
	mem[2] = 4'b0101; // 주소 2번에 0101 저장
end
// parameter 정의
parameter IDLE = 3'b000, // 아무것도 수신 x, rst 누른 후 상태, start bit 감지(계속 1이다가 0으로 바뀌는 순간)
			START = 3'b001, // start bit의 bit_index = 1, R/W 신호 읽기. bit_index = 2
			READ = 3'b010, // 주소에 해당하는 3bit 읽어서 data 가져오기, 가져온 data Tx로 보내기 -> REPLY
			WRITE = 3'b011, // 3bit 주소에서 읽어온 data를 register에 쓰기. Tx단으로 보내기 
			DEBUG = 3'b100, // 패리티 비트 체크 (오류 검출
			REPLY = 3'b101; // 송신 파트 준비
parameter BAUD_DIV = 104; // (16MHz / 9600) / 16 : 16배 오버샘플링. 1bit (1667번 진동하는 동안) 16번 체크한다는 뜻

/////// 보조 로직 블록 ///////
// 1. 전처리 블록 : rx 신호 변화 감지 블록 (state와 직접적 관련이 없는 전처리 로직이므로 따로 빼놓음. flag는 assign문으로 선언)
always @(posedge clk or posedge rst) begin // D FF 직렬연결. 두 개 존재
	if (rst) begin
		rx_0 <= 1;
		rx_1 <= 1;
	end
	else begin // 계속 rx 신호 변화 감지
		rx_0 <= rx; // rx_0은 현재 rx 신호
		rx_1 <= rx_0; // rx_1은 이전 rx 신호
	end

end
assign rx_start = ((state == IDLE) && ((rx_1 == 1)&&(rx_0 == 0)))? 1:0; // start flag

// 2. 카운터 / 타이밍 블록 : sampling 로직 블록
always @(posedge clk or posedge rst) begin
    if (rst || state == IDLE) begin
        clk_cnt <= 0;
        sampling_on <= 0;
        sampling_cnt <= 0;
        bit_index <= 0;
		s_done <= 0;
	end else begin
		if (state == START && bit_index == 0 && clk_cnt == 0 && sampling_cnt == 0) begin
			bit_index <= 1;
		end

		clk_cnt <= clk_cnt + 1;
		if (clk_cnt == BAUD_DIV) begin
			clk_cnt <= 0;
			sampling_on <= 1;
		end else begin
			sampling_on <= 0;
		end
		if (sampling_on) begin 
			sampling_cnt <= sampling_cnt + 1;
			if (sampling_cnt == 14)
				s_done <= 1; // 비트 인덱스 구분용
			if (sampling_cnt == 15) begin 
				sampling_cnt <= 0;
				s_done <= 0;
				if (bit_index > 0 && bit_index < 11)
					bit_index <= bit_index + 1;
				else if (bit_index >= 11)
					bit_index <= 0;   
			end
		end

    end
end

// 3. rx data 블록 : 수신된 데이터 처리 (clk 내에 있어야 정확한 데이터를 추출 가능)
always @(posedge clk or posedge rst) begin
	if (rst || state == IDLE) begin
		rx_data <= 0;
		bit_index <= 0;
		addr_buffer <= 0;
		data_buffer <= 0;
		rw_bit <= 0;
		parity_bit <= 0;
		parity_calc_result <= 0;
		parity_error <= 0;
	end else begin
		if (state == START && bit_index == 2) begin
			if(sampling_cnt == 8)
				rw_bit <= rx; // R/W 비트 읽기
		end
		if (state == READ || state == WRITE) begin
			if (bit_index >= 3 && bit_index <= 5) begin
				if (sampling_cnt == 8) begin
					case (bit_index)
						3: addr_buffer[2] <= rx; // 주소 비트 읽기
						4: addr_buffer[1] <= rx;
						5: addr_buffer[0] <= rx;
					endcase
				end
			end

			if (bit_index >= 6 && bit_index <= 9) begin // R / W 상태 둘 다 rx data 읽기
				if (sampling_cnt == 8) begin
					case (bit_index)
						6: data_buffer[3] <= rx; // 데이터 비트 읽기
						7: data_buffer[2] <= rx;
						8: data_buffer[1] <= rx;
						9: data_buffer[0] <= rx;
					endcase
				end
			end
		end
		if (state == DEBUG) begin
			if (bit_index == 10) begin
				if(sampling_cnt == 8) begin
					parity_bit <= rx; // 패리티 비트 읽기
				end
				rx_data <= {rw_bit, addr_buffer, data_buffer}; // 수신된 데이터 조합
				parity_calc_result <= parity_even(rx_data); // 패리티 비트 계산
				parity_error <= (parity_calc_result != parity_bit); // 패리티 오류 검출
			end
		end
	end
end

////// rx 데이터 Read/Write 처리 블록 //////
always @(posedge clk or posedge rst) begin
	if (rst || state == IDLE)
		new_data <= 0; // 새로 읽은 데이터 초기화
	else begin
		if (state == DEBUG && rw_bit == 1) begin
            new_data <= mem[addr_buffer]; // 메모리에서 4비트 데이터 통째로 읽어옴
        end
		if (state == DEBUG && rw_bit == 0) begin
            mem[addr_buffer] <= data_buffer; // 메모리에 4비트 데이터 통째로 씀
        end
	end
end

////// tx 데이터 처리 블록 (state = REPLY): tx로 보낼 주소와 데이터 설정 
always @(posedge clk or posedge rst) begin
	if (rst || state == IDLE) begin
		addr_tx <= 0;
		data_tx <= 0;
		tx_start <= 0;
	end else begin
		if (state == REPLY && bit_index == 11) begin
			addr_tx <= addr_buffer; // 주소 전송 준비
			data_tx <= (rw_bit == 1)? new_data : 4'b0000; // 데이터 입력
			tx_start <= 1; // REPLY 상태에서 tx_start 신호 활성화
		end
	end
end

////// parity 오류 검출 함수/////
function parity_even;
	input [7:0] data;
	integer i;
	reg result;
	begin
		result = 0;
		for (i = 0; i < 8; i = i + 1) begin
			result = result ^ data[i];
		end
		parity_even = result;
	end
endfunction

//////// FSM 로직 블록 ////////
// 1. state-register logic (sequential logic, D FF)
always @(posedge clk or posedge rst) begin
	if (rst) begin
		state <= IDLE;
	end else begin
		state <= next_state;
	end
end

// 2. next state logic (combinational logic)
always @(*) begin
	case(state)
		IDLE:begin
			if (rx_start) begin
				next_state = START; // start bit 감지
			end else begin
				next_state = IDLE; // 유지	
			end
		end
		START:begin
			if (bit_index == 2 && s_done == 1) begin
				if (rw_bit == 1) next_state = READ; // R/W 비트에 따라 READ 또는 WRITE 상태로 전환
				else next_state = WRITE;
			end
		end
		READ: begin
			if (bit_index == 9 && s_done == 1) begin
				next_state = DEBUG;
			end
		end
		WRITE:begin
			if (bit_index == 9 && s_done == 1) begin
				next_state = DEBUG;
			end
		end
		DEBUG:begin
			if (bit_index == 10 && s_done == 1) begin
				if (parity_error) next_state = IDLE; // 패리티 오류가 있으면 IDLE로 전환
				else next_state = REPLY;
			end
		end
		REPLY: begin
			if (bit_index == 11 && s_done == 1) begin
				next_state = IDLE; // DONE 상태 없앰
			end
		end
		default: begin
			next_state = state;
		end	
	endcase
end

// 3. output logic (combinational logic)
always @(*) begin
	if (tx_start == 1) begin
		to_tx = {rw_bit, addr_tx, data_tx}; // Tx로 보낼 주소와 데이터 조합
	end
end
endmodule