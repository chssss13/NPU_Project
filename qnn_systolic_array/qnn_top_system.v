// qnn_top_system.v
module qnn_top_system (
    input wire clk,
    input wire rst_n,
    input wire start,           // 1일 때 연산 FSM 가동 (원본 i_start 매핑)
    input wire relu_en,          // ReLU 활성화 제어
    input wire [1:0] pe_select,  // 관찰할 PE 선택 (00:PE00, 01:PE01, 10:PE10, 11:PE11)
    
    // 25핀 스펙 달성을 위한 시퀀셜 입력 채널
    input wire [7:0] seq_data_in, // T=0: 행0 데이터, T=1: 행1 데이터
    input wire [2:0] seq_wgt_in,  // T=0: 열0 가중치, T=1: 열1 가중치
    
    output wire [7:0] system_out, // 최종 8비트 복원 출력 (원본 o_mat_c 매핑)
    output reg o_done             // 연산 완료 신호 (원본 o_done 매핑)
);

    reg [7:0] raw_a0, raw_a1;
    reg [2:0] raw_b0, raw_b1;
    reg [1:0] step_cnt;

    // OS systolic 입력 valid: A/B가 실제로 유효한 cycle에만 각 PE가 MAC 수행
    wire in_a0_valid = start & (step_cnt == 2'd0);
    wire in_b0_valid = start & (step_cnt == 2'd0);
    wire in_a1_valid = start & (step_cnt == 2'd1);
    wire in_b1_valid = start & (step_cnt == 2'd1);

    // 현재 25핀 순차 입력 인터페이스 기준: T0는 row0/col0, T1은 row1/col1로 투입
    wire [7:0] core_a0 = in_a0_valid ? seq_data_in : 8'd0;
    wire [2:0] core_b0 = in_b0_valid ? seq_wgt_in  : 3'd0;
    wire [7:0] core_a1 = in_a1_valid ? seq_data_in : 8'd0;
    wire [2:0] core_b1 = in_b1_valid ? seq_wgt_in  : 3'd0;

    // 첫 유효 입력 cycle에서 모든 PE accumulator 초기화. qnn_mac_pe는 이 cycle의 MAC도 함께 반영한다.
    wire clr_accum = in_a0_valid & in_b0_valid;

    // 1. 외부 시퀀셜 입력의 valid 타이밍을 만드는 FSM (Controller 로직)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            step_cnt  <= 2'd0;
            o_done    <= 1'b0;
            raw_a0 <= 8'd0; raw_a1 <= 8'd0;
            raw_b0 <= 3'd0; raw_b1 <= 3'd0;
        end else begin
            if (start) begin
                case (step_cnt)
                    2'b00: begin
                        o_done    <= 1'b0;
                        raw_a0    <= seq_data_in; // 행0 데이터 확보
                        raw_b0    <= seq_wgt_in;  // 열0 가중치 확보
                        step_cnt  <= step_cnt + 2'd1;
                    end
                    2'b01: begin
                        raw_a1    <= seq_data_in; // 행1 데이터 확보
                        raw_b1    <= seq_wgt_in;  // 열1 가중치 확보
                        step_cnt  <= step_cnt + 2'd1;
                    end
                    2'b10: begin
                        o_done    <= 1'b1;      // 파이프라인 연산 완료 플래그 업
                        step_cnt  <= 2'b00;     // 루프 대기 혹은 리셋
                    end
                    default: step_cnt <= 2'b00;
                endcase
            end else begin
                step_cnt  <= 2'b00;
                o_done    <= 1'b0;
            end
        end
    end

    // 3. 내부 2x2 시스톨릭 코어 어레이 연결
    qnn_systolic_array_2d u_qnn_core (
        .clk(clk),
        .rst_n(rst_n),
        .clr_accum(clr_accum),
        .relu_en(relu_en),
        .in_a0(core_a0),
        .in_a1(core_a1),
        .in_b0(core_b0),
        .in_b1(core_b1),
        .in_a0_valid(in_a0_valid),
        .in_a1_valid(in_a1_valid),
        .in_b0_valid(in_b0_valid),
        .in_b1_valid(in_b1_valid),
        .out_sel(pe_select),
        .final_out(system_out)
    );

endmodule