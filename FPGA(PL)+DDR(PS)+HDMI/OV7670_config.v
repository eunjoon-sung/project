`timescale 1ns / 1ps

// OV7670 CMOS Image Sensor control module
// 목표: ROM에서 설정값을 하나씩 읽어와, SCCB_interface 모듈에게 전송을 지시하고, 
// 모든 설정이 끝날 때까지 이 과정을 반복하는 시퀀서를 만든다.

module OV7670_config
#(
    parameter CLK_FREQ = 25_000_000
)
(
    input wire clk,
    input wire rst,
    input wire SCCB_interface_ready, // ready = 0 : busy, ready = 1 : ok
    input wire [15:0] rom_data, // from OV7670_config_rom
    input wire start, // initiate configuration process
    output reg [7:0] rom_addr, // to OV7670_config_rom
    output reg done, // completed configuration process
    output reg [7:0] SCCB_interface_addr, // to SCCB_interface
    output reg [7:0] SCCB_interface_data,
    output reg SCCB_interface_start
    );

    reg [2:0] state, next_state = 0;
    reg [7:0] addr_buf; // 현재 어드레스 버퍼
    reg [15:0] data_buf; // 받은 데이터 버퍼
    reg [23:0] timer = 0;
    
    localparam DELAY_1MS = CLK_FREQ / 50;
        
    initial begin
        rom_addr = 0;
        done = 0;
        SCCB_interface_addr = 0;
        SCCB_interface_data = 0;
        SCCB_interface_start = 0;
    end

    // state definitions
    localparam IDLE = 0; // start 신호가 들어오기 전 작동 안하는 상태
    localparam READ_ROM = 1; // rom_addr = addr_buf; 적재되는 동시에 rom 모듈 input에 들어감.
    localparam CHECK_DATA = 2; // dout 출력후 클럭 마지막에 캡쳐
    localparam DATA_SEND = 3; // ready 상태 체크 후, SCCB_interface에 데이터 전송을 지시
    localparam WAIT_RES= 4; // 전송할동안 대기. ready 신호가 다시 1되길 기다림
    localparam DONE = 5;
    localparam DELAY = 6; // 하드웨어를 고려한 설정추가: 물리적인 대기시간
    localparam WAIT_BUSY = 7;

    // FSM
    // 1. state register : 값을 저장하는 역할만 함.
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            addr_buf <= 0;
            data_buf <= 0;
            state <= 0;
            timer <= 0;
        end
        else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    addr_buf <= 0;
                    data_buf <= 0;
                end
    
                CHECK_DATA: begin
                    data_buf <= rom_data;
                    timer <= DELAY_1MS;
                    if (rom_data != 16'hFF_FF) begin 
                        addr_buf <= addr_buf + 1; // 다음 주소 준비
                    end
                end
                
                DELAY: begin
                    if (timer > 0) begin
                        timer <=  timer - 1;
                    end
                    else
                        timer <= 0;
                    end
            endcase
        end
    end
    
    // 2. next-state logic + output logic : 실제 회로 구성
    // '현재 상태'와 '입력'을 보고 '다음에 저장할 값'과 '지금 당장 내보낼 출력'을 계산하는 모든 로직이 이 안에 들어감.
    always @(*) begin
    // latch 생성 방지 : 모든 출력/변수의 '기본값'을 'case' 문 전에 할당.
        next_state = state;
        rom_addr = addr_buf; // wire 로 항상 연결시킴
        done = 0;
        SCCB_interface_start = 0;
        SCCB_interface_addr = data_buf[15:8]; // address
        SCCB_interface_data = data_buf[7:0]; // data

        case (state)
            IDLE: begin
				done = 0;
                SCCB_interface_start = 0;
                if (start) begin
                    next_state = READ_ROM;
                end else begin
                    next_state = IDLE;
                end
            end
            
            READ_ROM: begin
                next_state = CHECK_DATA;
            end
            
            CHECK_DATA: begin
                if (rom_data == 16'hFF_FF) begin // end of rom
                    next_state = DONE;
                end
                else if (rom_data == 16'hFF_F0) begin
                    next_state = DELAY;
                end
                else begin
                    next_state = DATA_SEND;
                end
            end
            
            DATA_SEND: begin 
                if (SCCB_interface_ready) begin
					SCCB_interface_start = 1;
					SCCB_interface_addr = data_buf[15:8];
					SCCB_interface_data = data_buf[7:0];
                    next_state = WAIT_BUSY;
                end
                else begin
                    next_state = DATA_SEND;
                end
            end
            
            // [추가된 상태] I2C 모듈이 Start를 인식하고 Busy(Ready=0)가 될 때까지 기다림
            WAIT_BUSY: begin
                SCCB_interface_start = 1; // 확실하게 Start 유지 (모듈에 따라 필요할 수 있음)
                SCCB_interface_addr = data_buf[15:8]; // 주소/데이터 유지
                SCCB_interface_data = data_buf[7:0];
                
                if (!SCCB_interface_ready) begin // Ready가 0이 되면(바빠지면) 성공!
                    SCCB_interface_start = 0; // 이제 Start 내림
                    next_state = WAIT_RES;    // 완료 대기 상태로 이동
                end else begin
                    next_state = WAIT_BUSY;   // 아직 안 바빠졌으면 계속 대기
                end
            end
            
            WAIT_RES: begin   // sccb interface의 전송이 끝나길 기다림. 
                if (SCCB_interface_ready) begin
                    SCCB_interface_start = 0;
                    next_state = DELAY;
                end else begin
                    next_state = WAIT_RES;
                end
            end
            
            DONE: begin
                done = 1;   
                next_state = DONE;
            end
            
            DELAY: begin
                if (timer == 0) begin
                    next_state = READ_ROM;
                end
            end
            
            default: begin // 비정상 상태 대비
                next_state = IDLE;
                // next_state = 'x; 는 systemverilog 에서 유효
                
            end
        endcase
    end
    
endmodule
