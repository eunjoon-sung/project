`timescale 1ns / 1ps
/*
start 1 bit
R/W 1 bit
address 3 bit
data 4 bit
parity 1 bit
end 1 bit 
*/
module UART_Rx(
    input wire clk,
    input wire rst,
    input wire rx,             // UART Rx 선
    output reg [7:0] rx_data,  // 수신된 데이터
    output reg tx_start, // REPLY flag
    output reg rw_bit, // 1이면 R 0이면 W
    output reg [6:0] to_tx
    );
    reg [3:0] mem [0:7]; // 메모리 4bit 8개. 주소가 3bit로 들어오기 때문
    reg [12:0] clk_cnt = 0; // 시스템 클럭 16Mhz과 전송 속도 맞추기 위함
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] sampling_cnt;
    reg [3:0] bit_index = 0; // total 11bit
    reg [2:0] addr_buffer = 0; // 읽은 주소 저장하는 버퍼
    reg [3:0] data_buffer = 0; // 읽은 주소에 저장된 data를 저장하는 버퍼
    reg [2:0] new_addr= 0;
    reg [3:0] new_data= 0;
    reg rx_0, rx_1; // start, end 구분 용도
    reg sampling_on = 0;
    reg rx_start, rx_end; // start, end flag    
    reg parity_bit;          // 수신된 패리티 비트 저장
    reg parity_calc_result;  // 계산된 패리티 결과 저장
    reg parity_error;        // 오류 플래그
    reg [2:0] addr_tx; // tx단에 보낼 addr
    reg [3:0] data_tx; // tx단에 보낼 data
    
    // 시뮬레이션 초기화 블록
    initial begin
        mem[2] = 4'b0101; // 주소 2번에 0101 저장
        // 필요하면 더 추가
        // mem[0] = 4'b0001;
        mem[1] = 4'b0010;
    end
    
	// FSM을 짤 때는 일단 상태를 잘 나눠서 정의해놓는게 가장 중요!
    parameter IDLE = 3'b000, // 아무것도 수신 x, rst 누른 후 상태, rx가 high 상태인지 감시
              START = 3'b001, // start bit 감지(계속 1이다가 0으로 바뀌는 순간), R/W 신호 감지 (0으로 바뀐 다음 비트)
              READ = 3'b010, // 주소에 해당하는 3bit 읽어서 data 가져오기, 가져온 data Tx로 보내기 -> REPLY
              WRITE = 3'b011, // 3bit 주소에서 읽어온 data를 register에 쓰기. Tx단으로 보내기 
              REPLY = 3'b100, // 송신 파트 준비
              DEBUG = 3'b101, // 패리티 비트 체크 (오류 검출)
              DONE = 3'b110; // 수신완료 (0에서 다시 1)

    parameter BAUD_DIV = 104; // (16MHz / 9600) / 16 : 16배 오버샘플링. 1bit (1667번 진동하는 동안) 16번 체크한다는 뜻
    
    always @(posedge clk) begin // rx 신호 변화 감지
        rx_0 <= rx;
        rx_1 <= rx_0;
        
        rx_start <= ((state == IDLE) && ((rx_1 == 1)&&(rx_0 == 0)))? 1:0; // start flag
        rx_end <= ((state == DONE) && ((rx_1 == 0)&&(rx_0 == 1))); // end flag
        if (rx_start == 1) bit_index <= 1;
    end

    // clk 카운트 해서 sampling cnt 계산
    // 클럭 카운터, 샘플링 온 카운터
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            clk_cnt <= 0;
            sampling_on <= 0;
            sampling_cnt <= 0;
            state <= IDLE;
            tx_start <= 0;
            rx_data <= 0;
            to_tx <= 0;
            bit_index <= 0;
            addr_buffer <= 0;
            data_buffer <= 0;
            rw_bit <= 0;
            parity_bit <= 0;
            parity_calc_result <= 0;
            parity_error <= 0;

        end else begin
            if (clk_cnt == BAUD_DIV - 1) begin
                sampling_on <= 1;
                clk_cnt <= 0;
            end else begin
                clk_cnt <= clk_cnt + 1;
                sampling_on <= 0;
            end

            if (sampling_on) begin         
                if (sampling_cnt == 15) begin
                    if (state == READ || state == WRITE || state == START || state == DEBUG || state == DONE) begin
                        if (bit_index < 11) bit_index <= bit_index + 1;
                    end
                    sampling_cnt <= 0;
                end
                else begin
                    sampling_cnt <= sampling_cnt + 1;
                end              
            end
        end
     end

     // 함수로 sampling_addr, sampling_data 구현
    function [2:0] sampling_addr_func;
        input [3:0] sampling_cnt_in;
        input [3:0] bit_index;
        input [2:0] addr_in;
        input rx_bit;
        begin
            sampling_addr_func = addr_in;
    
            if (sampling_cnt_in == 8) begin
                case(bit_index)
                    3: sampling_addr_func[2] = rx_bit;
                    4: sampling_addr_func[1] = rx_bit;
                    5: sampling_addr_func[0] = rx_bit;
                endcase
            end
        end
    endfunction

    function [3:0] sampling_data_func;
        input [3:0] sampling_cnt_in;
        input [3:0] bit_index;
        input [3:0] data_in;
        input rx_bit;
         begin
           sampling_data_func = data_in;

            if (sampling_cnt_in == 8) begin
                case(bit_index)
                6: begin sampling_data_func[3] = rx_bit; end
                7: begin sampling_data_func[2] = rx_bit; end
                8: begin sampling_data_func[1] = rx_bit; end
                9: begin sampling_data_func[0] = rx_bit; end

                endcase
            end

        end 
    endfunction

    // parity 오류 검출
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

     // next-state logic
    always @(*) begin
        next_state = state; // 기본 유지
        case(state)
            IDLE: begin
                if (rx_start)
                    next_state = START;
            end
            START: begin
                if (sampling_cnt == 15 && bit_index == 2) begin
                    if (rw_bit == 1)
                        next_state = READ;
                    else
                        next_state = WRITE;
                end
            end
            READ: begin
                if (bit_index == 10)
                    next_state = DEBUG;
            end
            WRITE: begin
                if (bit_index == 10)
                    next_state = DEBUG;
            end
            DEBUG: begin
                if (parity_error)
                    next_state = DONE;
                else
                    next_state = REPLY;
            end
            REPLY: begin
                next_state = DONE;
            end
            DONE: begin
                if (bit_index == 11)
                    next_state = IDLE;
            end
        endcase
    end

    // state - register + output logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            tx_start <= 0;
            rx_data <= 0;
            to_tx <= 0;
            bit_index <= 0;
            addr_buffer <= 0;
            data_buffer <= 0;
            rw_bit <= 0;
            parity_bit <= 0;
            parity_calc_result <= 0;
            parity_error <= 0;

        end else begin
            state <= next_state;

            case(state)
                IDLE: begin

                end
                START: begin
                    case (bit_index)
                    1: begin end
                    2: begin 
                    if (sampling_cnt == 8) rw_bit <= rx;
                    end
                    endcase
                end
                READ: begin
                    if (bit_index >= 3 && bit_index <= 5) begin
                        addr_buffer <= sampling_addr_func(sampling_cnt, bit_index, addr_buffer, rx);
                       
                    end
                    if (bit_index >= 6 && bit_index <= 9) begin
                        data_buffer <= sampling_data_func(sampling_cnt, bit_index, data_buffer, rx);     
                    end
                end 
                WRITE: begin
                    if (bit_index >= 3 && bit_index <= 5) begin
                        addr_buffer <= sampling_addr_func(sampling_cnt, bit_index, addr_buffer, rx);
                    end
                    if (bit_index >= 6 && bit_index <=9) begin
                        data_buffer <= sampling_data_func(sampling_cnt, bit_index, data_buffer, rx);
                        mem[addr_buffer] <= data_buffer;
                    end
                end
                DEBUG: begin
                    // RW + addr + data 묶음
                    rx_data <= {rw_bit, addr_buffer, data_buffer};
                    parity_calc_result <= parity_even({rw_bit, addr_buffer, data_buffer});
                    parity_error <= (parity_calc_result != parity_bit);
                end
                REPLY: begin
                    addr_tx <= addr_buffer;
                    data_tx <= (rw_bit) ? data_buffer : 4'b0000;
                    to_tx <= {addr_tx, data_tx};
                    tx_start <= 1;
                end
                DONE: begin
                    tx_start <= 0;
                    if (bit_index >= 11) begin
                        bit_index <= 0;
                        rw_bit <= 0;
                        addr_buffer <= 0;
                        data_buffer <= 0;
                        addr_tx <= 0;
                        data_tx <= 0;
                        clk_cnt <= 0;
                        sampling_on <= 0;
                        sampling_cnt <= 0;
                        tx_start <= 0;
                        rx_data <= 0;
                        to_tx <= 0;
    
                        parity_bit <= 0;
                        parity_calc_result <= 0;
                        parity_error <= 0;
                        
                    end
                end
            endcase

            if (sampling_on && bit_index == 10) begin
                parity_bit <= rx;
            end
        end
    end
    
endmodule