`timescale 1ns / 1ps

module UART_Tx(
    input tx_start,
    input [7:0]to_tx,
    input clk,
    input rst,
    output wire tx_out,
    output reg busy    // 송신 flag
    );
    reg [10:0] shift_reg;
    reg [3:0] state;
    reg [3:0] next_state;
    reg [12:0] clk_cnt = 0; // 시스템 클럭 16Mhz과 전송 속도 맞추기 위함
    reg sampling_on = 0;
    reg [3:0]sampling_cnt = 0;
    reg bit_cnt = 0;
    reg tx_buffer = 0;
    parameter IDLE = 3'b000, // 아무것도 수신 x, rst 누른 후 상태
              READ = 3'b001, // rx단에서 보낸 addr, data 가져오기
              SEND = 3'b010, // 송신 파트 준비
              DONE = 3'b100; // 송신완료 (0에서 다시 1)

    parameter BAUD_DIV = 104; // (16MHz / 9600) / 16 : 16배 오버샘플링. 1bit (1667번 진동하는 동안) 16번 체크한다는 뜻
    // clk 카운트 해서 sampling cnt 계산
    always @(posedge clk) begin
        if (clk_cnt == BAUD_DIV - 1) begin // 이렇게 하면 1비트에 16번 정도 sampling on이 됨
            sampling_on <= 1;
            clk_cnt <=0;
        end
        else begin
            clk_cnt <= clk_cnt + 1;
            sampling_on <= 0;
        end
    end
    always @(posedge clk) begin
        if (sampling_on) sampling_cnt <= sampling_cnt + 1; 
        else if ((state == IDLE) || (state == READ) || (state == DONE) ||rst ) sampling_cnt <=0;
    end
    // parity 오류 검출
    function parity_even;
        input [6:0] data;  // addr + data
        integer i;
        reg result;
        begin
            result = 0;
            for (i = 0; i < 7; i = i + 1)
                result = result ^ data[i];  // XOR로 1의 개수 판단
                parity_even = result;  // 1이면 홀수, 0이면 짝수
            end
    endfunction
    // bit reverse
    function [6:0] reverse_bits;
        input [6:0] in;
        integer i;
        begin
            for (i = 0; i < 7; i = i + 1)
                reverse_bits[i] = in[6 - i];
        end
    endfunction

    always @(posedge clk) begin
        if (busy) begin
            if(sampling_cnt % 16 == 0 && bit_cnt < 11) begin
                tx_buffer <= shift_reg[bit_cnt];
                bit_cnt <= bit_cnt + 1;
            end
        end
    end
    
    
    // state-register logic          
    always @(posedge clk or posedge rst) begin
        if (rst) state <= IDLE;
        else state <= next_state;
    end
    // next-state logic          
    always @(*) begin
        case (state)
        IDLE: begin next_state = (tx_start == 1)? READ : IDLE; end
        READ: begin
            if (to_tx == 7'b1000101) begin
                shift_reg = 
                {
                1'b1,
                parity_even(to_tx),
                reverse_bits(to_tx),
                1'b0
                };
                next_state = SEND;
            end
            else begin
                shift_reg = { // 거꾸로 배치해야 수신시 제대로 된 순서로 받음
                    1'b1, // STOP bit
                    parity_even(to_tx),  // parity bit 계산
                    reverse_bits(to_tx),
                    1'b0 // start bit             
                };
                next_state = SEND;
            end
        end
        SEND: begin
            busy = 1;
            if (bit_cnt == 11) begin busy = 0; next_state = DONE; end
        end
        DONE: begin
            bit_cnt = 0;
            sampling_on = 0;
            sampling_cnt = 0;
            tx_buffer = 0;
            shift_reg = 0;
            next_state = IDLE;
        end
        endcase
    end
    
    // output logic
    assign tx_out = tx_buffer;
endmodule
