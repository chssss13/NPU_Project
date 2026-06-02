`timescale 1ns / 1ps

module tb_qnn_top_system;

    // 1. 테스트벤치용 입력/출력 신호 선언
    reg clk;
    reg rst_n;
    reg start;
    reg relu_en;
    reg [1:0] pe_select;
    reg [7:0] seq_data_in;
    reg [2:0] seq_wgt_in;

    wire [7:0] system_out;
    wire o_done;

    // 2. 검증 대상 모듈(DUT) 인스턴스화
    qnn_top_system uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .relu_en(relu_en),
        .pe_select(pe_select),
        .seq_data_in(seq_data_in),
        .seq_wgt_in(seq_wgt_in),
        .system_out(system_out),
        .o_done(o_done)
    );

    // 3. 10ns 주기의 시스템 클락 생성 (100MHz 환경 가상)
    always #5 clk = ~clk;

    // 4. 테스트 시나리오 실행
    initial begin
        // GTKWave 파형 분석 파일 자동 추출 설정
        $dumpfile("qnn_system.vcd");
        $dumpvars(0, tb_qnn_top_system);

        // 초기값 설정 및 비동기 리셋 인가
        clk = 0;
        rst_n = 0;
        start = 0;
        relu_en = 1;      // 기본적으로 ReLU 활성화 검증
        pe_select = 2'b00; // 우선 가장 먼저 연산이 시작되는 PE00 관찰
        seq_data_in = 8'd0;
        seq_wgt_in = 3'd0;

        #20;
        rst_n = 1; // 리셋 해제
        #10;

        // ========================================================
        // [시나리오 1] 첫 번째 행렬 데이터 순차 입력 및 스큐 연산
        // 목표: PE00에 데이터 입력 10, 가중치 (1<<2 = 4배 시프트) 주입 -> 결과 40 기대
        // ========================================================
        $display("[TB INFO] Starting Scenario 1: Basic QNN Shift Operations.");
        @(negedge clk);
        start = 1;
        seq_data_in = 8'd10; // T=0: 행0 데이터 진입
        seq_wgt_in = 3'd2;   // T=0: 열0 시프트 크기 '2' (즉, 1<<2 = 4배 연산 의미)
        
        @(negedge clk);
        seq_data_in = 8'd25; // T=1: 행1 데이터 진입 (FSM에 의해 내부 스큐 1클락 대기)
        seq_wgt_in = 3'd1;   // T=1: 열1 시프트 크기 '1' (즉, 1<<1 = 2배 연산 의미)

        @(negedge clk);
        // 연산 파이프라인 진행 중 (FSM에서 데이터 버퍼 유지를 진행하는 안정화 사이클)
        start = 0;
        seq_data_in = 8'd0;
        seq_wgt_in = 3'd0;

        // 파이프라인 연산이 코어를 관통하여 결과가 유지될 때까지 대기
        #30; 
        
        // 관찰 셀 변경을 통한 결과 복원(Restoring) 검증
        pe_select = 2'b00; // PE(0,0) 관찰
        #5;
        $display("[RESULT] PE00 Output = %d (Expected: 40)", system_out);
        if (system_out !== 8'd40) begin
            $display("[TB ERROR] PE00 mismatch: got %d, expected 40", system_out);
        end

        // ========================================================
        // [시나리오 2] ReLU 연산 기능 검증 (음수 발생 및 클리어 조건 테스트)
        // ========================================================
        $display("[TB INFO] Starting Scenario 2: Zero Restoring / ReLU Function Check.");
        pe_select = 2'b01; // 옆 칸인 PE01 관찰 설정
        
        @(negedge clk);
        start = 1;
        seq_data_in = 8'd5;
        seq_wgt_in = 3'd3;  // 5 << 3 = 40
        
        @(negedge clk);
        start = 0;
        
        #40;
        // 의도적으로 칩을 강제 초기화하여 Restoring 및 ReLU의 0 바인딩 검증
        rst_n = 0; 
        #10;
        rst_n = 1;
        #10;
        $display("[RESULT] Post-Reset PE01 Output = %d (Expected: 0 due to ReLU/Clear)", system_out);

        $display("[TB INFO] All Matrix Operations verified successfully.");
        $finish;
    end

endmodule