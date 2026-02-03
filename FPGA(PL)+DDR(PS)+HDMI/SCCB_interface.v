`timescale 1ns / 1ps

module SCCB_interface
#(
    parameter CLK_FREQ = 25_000_000,
    parameter SCCB_FREQ = 100_000
)
(
    input wire clk,
    input wire rst,
    input wire start,
    input wire [7:0] address,
    input wire [7:0] data,
    output reg ready,
    output reg SIOC_oe,
    output reg SIOD_oe
    );
    
    reg [3:0] state = 0;
    reg [3:0] next_state = 0;
    reg [7:0] addr_buf;
    reg [7:0] data_buf;
    
    localparam IDLE = 0; // rst 신호 및 start 신호 아무것도 안들어왔을 때
    localparam START_D = 1; // siod_oe up
    localparam START_C = 2; // sioc_oe up
    localparam CLK_LOW = 3; // sioc_oe 신호 low ---> 이 때 data 를 보냄
    localparam CLK_HIGH = 4; // sioc_oe 신호 high  ---> data 준비
    localparam CHECKING = 5; // 8bit data 보낸 뒤 마지막 1bit X 및 다음 data 준비
    localparam DONE_READY = 6;
    localparam DONE_C = 7; 
    localparam DONE_D = 8;
    
    localparam CAMERA_ADDR = 8'h42;
    localparam PERIOD = CLK_FREQ / SCCB_FREQ;
    
    reg [8:0] count = 0; // 0 ~ 124 까지 셈
    reg [8:0] next_count = 0; // 2 block fsm에 따라 순차 / 조합 나누기 위한 레지스터
    reg [3:0] bit_index = 0; // 0 ~ 7 bit (+ 1 bit (X))
    reg [2:0] byte_index = 0; // 1 byte = 8 bit. 3 byte 보낼 예정 1. camera addr 2. address (data[15:8]) 3. data(data[7:0])

     // 2-block FSM
     // 1. sequential logic
     always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= 0;
            SIOC_oe <= 0;
            SIOD_oe <= 0;
            data_buf <= 0;
            addr_buf <= 0;
            count <= 0;
            bit_index <= 8;
            byte_index <= 2;
            ready <= 1;
        end
        else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    // state <= 0; 넣으면 안됨 ! 위의 state <= ...; 구문과 충돌 일으킴
                    SIOC_oe <= 0;
                    SIOD_oe <= 0;
                    data_buf <= 0;
                    addr_buf <= 0;
                    count <= 0;
                    bit_index <= 8;
                    byte_index <= 2;
                    ready <= 1;

                    if (start) begin
                        addr_buf <= address;
                        data_buf <= data;
                        ready <= 0;
                    end
                end
                
                START_D: begin
                    SIOC_oe <= 0;
                    SIOD_oe <= 1;
                    
                    if (count == (PERIOD / 2) - 1) begin
                        count <= 0;
                    end
                    else begin
                        count <= count + 1;
                    end
                end
                
                START_C: begin
                    SIOC_oe <= 1;
                    SIOD_oe <= 1;
                    
                    if (count == (PERIOD / 2) - 1) begin
                        count <= 0;
                    end
                    else begin
                        count <= count + 1;
                    end
                end
                
                CLK_LOW: begin
                    SIOC_oe <= 1;
                    if (bit_index == 0) begin
                        SIOD_oe <= 0; // 마지막 1 bit : X (Acknowledge bit)
                    end else begin
                        if (byte_index == 2) begin
                            SIOD_oe <= ~ CAMERA_ADDR[bit_index - 1]; // SIOD = ~ SIOD_oe
                        end
                        else if (byte_index == 1) begin
                            SIOD_oe <= ~ addr_buf[bit_index - 1];
                        end
                        else if (byte_index == 0) begin
                            SIOD_oe <= ~ data_buf[bit_index - 1];
                        end
                    end

                    if (count == (PERIOD / 2) - 1) begin
                        count <= 0;
                    end
                    else begin
                        count <= count + 1;
                    end
                end
                
                CLK_HIGH: begin // data capture
                    SIOC_oe <= 0;
                    if (count == (PERIOD / 2) - 1) begin
                        count <= 0;
                        bit_index <= bit_index - 1;
                    end
                    else begin
                        count <= count + 1;
                    end
                end
                
                CHECKING: begin
                    SIOC_oe <= 0; // 클럭 High (ACK 타임)
                    SIOD_oe <= 0; // 카메라 대답 듣기
                    if (count == (PERIOD / 2) - 1) begin
                        byte_index <= byte_index - 1;
                        if (byte_index == 0) begin
                            byte_index <= 2;
                            bit_index <= 8;
                            count <= 0;
                        end else begin
                            bit_index <= 8;
                            count <= 0;
                        end
                    end
                    else begin
                        count <= count + 1;
                    end
                end
                
                // [1단계] DONE_READY: SCL=0, SDA=0 (데이터 변경을 위해 SCL을 내림)
                DONE_READY: begin
                    SIOC_oe <= 1; // SCL Low (0) [수정됨: 0->1]
                    SIOD_oe <= 1; // SDA Low (0) [수정됨: 0->1]
                    
                    if (count == (PERIOD / 2) - 1) begin
                        count <= 0;
                    end else begin
                        count <= count + 1;
                    end
                end
            
                // [2단계] DONE_C: SCL=1, SDA=0 (STOP 조건 셋업 - 클럭만 올림)
                DONE_C: begin
                    SIOC_oe <= 0; // SCL High (1) [수정됨: 1->0]
                    SIOD_oe <= 1; // SDA Low  (0) [유지]
                    
                    if (count == (PERIOD / 2) - 1) begin
                        count <= 0;
                    end else begin
                        count <= count + 1;
                    end
                end
            
                // [3단계] DONE_D: SCL=1, SDA=1 (STOP 실행 - SDA를 올림)
                DONE_D: begin
                    ready <= 1;
                    SIOC_oe <= 0; // SCL High (1)
                    SIOD_oe <= 0; // SDA High (1) -> 여기서 0에서 1로 상승하며 STOP!
                    
                    if (count == (PERIOD / 2) - 1) begin
                        count <= 0;
                    end else begin
                        count <= count + 1;
                    end
                end 
                        
            endcase
        end
     end
     
     // 2. combinational logic
     always @(*) begin
        next_state = state; // 맨 처음에 선언해놓으면 else 구문 안써줘도 됨. 다만 default 블럭은 상태 '안'에서 발생하는 래치를 막아주지 못한다는 것을 명심!
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = START_D;
                end
                else begin
                    next_state = IDLE;
                end
            end
            
            START_D: begin
                if (count == (PERIOD / 2) - 1) begin
                    next_state = START_C;
                end
                else begin
                    next_state = START_D;
                end
            end
                        
            START_C: begin
                if (count == (PERIOD / 2) - 1) begin
                    next_state = CLK_LOW;
                end
                else begin
                    next_state = START_C;
                end
            end
            
            CLK_LOW: begin
                if (count == (PERIOD / 2) - 1) begin
                    if (bit_index == 0) begin
                        next_state = CHECKING;
                    end
                    else begin
                        next_state = CLK_HIGH;
                    end
                end
            end
            
            CLK_HIGH: begin
                if (count == (PERIOD / 2) - 1) begin
                    next_state = CLK_LOW;
                end
            end
            
            CHECKING: begin
                if (count == (PERIOD / 2) - 1) begin
                    if (byte_index == 0) begin
                        next_state = DONE_READY;
                    end
                    else begin
                        next_state = CLK_LOW;
                    end
                end           
            end
            
            DONE_READY: begin
                 if (count == (PERIOD / 2) - 1) begin
                    next_state = DONE_C;
                 end
                 else begin
                    next_state = DONE_READY;
                 end
            end

            DONE_C: begin
                if (count == (PERIOD / 2) - 1) begin
                    next_state = DONE_D;
                end
                else begin
                    next_state = DONE_C;
                end
            end
            
            DONE_D: begin
                if (count == (PERIOD / 2) - 1) begin
                    next_state = IDLE;
                end
                else begin
                    next_state = DONE_D;
                end
            end
                        
            default: begin
                next_state = state;
            end
        endcase
     end
 endmodule
