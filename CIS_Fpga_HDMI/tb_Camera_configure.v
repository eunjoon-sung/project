`timescale 1ns / 1ps

module tb_Camera_configure;

    // 1. 파라미터 및 클럭 생성
    parameter CLK_FREQ = 25_000_000;
    // 25MHz -> 40ns 주기
    parameter CLK_PERIOD = 40; 

    // 2. 최상위 모듈 입출력 신호 선언
    reg  clk;
    reg  rst;
    reg  start; // DUT 입력
    wire sioc;  // DUT 출력
    wire siod;  // DUT 출력
    wire done;  // DUT 출력

	initial begin
			$dumpfile("test_out.vcd");                // VCD 파일 생성
			$dumpvars(0, tb_Camera_configure);       // testbench 내부의 모든 신호를 덤프
		end

    // 클럭 생성기
    always #(CLK_PERIOD / 2) clk = ~clk;

    // 3. DUT (Device Under Test) 인스턴스화
    // 님이 짠 3개의 모듈(FSM, ROM, SCCB)을 '통합'한
    // '최상위' 모듈 하나만 불러옵니다.
    Camera_configure #(
        .CLK_FREQ(CLK_FREQ)
    ) uut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .sioc(sioc),
        .siod(siod),
        .done(done)
    );

    // 4. 모니터링 (필수)
    // FSM 내부 상태는 볼 수 없지만, 최상위 신호를 관찰합니다.
    initial begin
        $monitor("Time: %0t | rst: %b | start: %b | SCCB_ready: %b | done: %b",
                 $time, rst, start, uut.SCCB_ready, done);
        // 참고: uut.SCCB_ready 처럼 하위 모듈의 신호를 보려면
        // Vivado에서 'uut'를 펼쳐서 봐야 합니다.
    end

    // 5. 메인 테스트 시퀀스 (Stimulus)
    initial begin
        // 1. 초기화 및 비동기 리셋 (필수!)
        $display("TB: 시뮬레이션 시작... 리셋 활성화.");
        clk = 0;
        rst = 1; // 'X' 상태를 잡기 위해 1로 시작
        start = 0;
        
        #(CLK_PERIOD * 10); // 10 사이클 동안 리셋 유지

        $display("TB: 리셋 비활성화. FSM 동작 시작.");
        rst = 0; // 'posedge rst'가 아닌 'negedge' 발생
        
        #(CLK_PERIOD * 10); // 리셋 해제 후 안정화 대기

        // 2. FSM 시작
        $display("TB: FSM 'start' 펄스 전송.");
        start = 1; // 'start' 신호 1 사이클 인가
        #(CLK_PERIOD);
        start = 0;

        // 3. FSM이 'done' 신호를 보낼 때까지 대기
        // (이 과정은 SCCB_FREQ 때문에 매우 오래 걸릴 수 있음)
        wait (done == 1'b1);
        
        $display("TB: 'done' 신호 감지!");
        #(CLK_PERIOD * 10);

        // 4. 시뮬레이션 종료
        $display("TB: 시뮬레이션 종료.");
        $finish;
    end

endmodule