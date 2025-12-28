module SRAM_writer(
    input wire clk, // 25MHz
    input wire rst,
    input wire scaled_valid,
    input wire [11:0] scaled_data,
    input wire frame_done, // 비동기 신호 (PCLK 도메인)
    
    output reg [16:0] bram_addr,
    output reg [11:0] bram_data,
    output reg bram_we
    );
    
    localparam MAX_ADDR = 76800 - 1; 

    // [1] CDC 동기화를 위한 레지스터 (2-stage synchronizer)
    reg frame_done_d1;
    reg frame_done_d2;
    reg frame_done_d3; // 엣지 검출용

    always @(posedge clk) begin
        if (rst) begin
            frame_done_d1 <= 0;
            frame_done_d2 <= 0;
            frame_done_d3 <= 0;
        end else begin
            // 신호를 25MHz 클럭으로 가져옴 (안전장치)
            frame_done_d1 <= frame_done; 
            frame_done_d2 <= frame_done_d1; 
            frame_done_d3 <= frame_done_d2; // 이전 클럭 값 저장
        end
    end

    // [2] 상승 엣지 검출 (0에서 1로 변하는 순간 포착)
    // VSYNC가 시작되는 순간 딱 한 번만 1이 됨
    wire frame_start_pulse = (frame_done_d2 == 1'b1) && (frame_done_d3 == 1'b0);


    // 메인 로직
    always @(posedge clk) begin
        if (rst) begin
            bram_addr <= 0;
            bram_data <= 0;
            bram_we <= 0;
        end 
        else begin
            // ★ 수정됨: 신호가 유지되는 동안이 아니라, "시작되는 순간" 딱 한 번만 리셋
            if (frame_start_pulse) begin
                bram_addr <= 0;
                bram_we <= 0;
            end
            else begin
                if (scaled_valid) begin
                    bram_we <= 1;
                    bram_data <= scaled_data;
                end 
                else begin
                    bram_we <= 0;  // 데이터가 없을 땐 주소 유지
                end
                
                // bram_we 신호가 1이 되고부터 sram 쓰기
                if (bram_we) begin
                    if (bram_addr == MAX_ADDR) 
                        bram_addr <= 0;
                    else 
                        bram_addr <= bram_addr + 1;
                end
            end
        end
    end

endmodule