// qnn_mac_pe.v
module qnn_mac_pe (
    input wire clk,
    input wire rst_n,
    input wire clr_accum,     // 새로운 행렬 계산을 시작할 때 누산기 초기화 신호
    input wire mac_en,        // 유효한 A/B가 만났을 때만 MAC 수행
    input wire [7:0] in_a,    // 8비트 입력 데이터
    input wire [2:0] in_b,    // 3비트 가중치 (0~7 시프트 크기)
    input wire in_a_valid,    // A 데이터 valid
    input wire in_b_valid,    // B 데이터 valid
    output reg [7:0] out_a,   // 오른쪽 PE로 데이터 패싱
    output reg [2:0] out_b,   // 아래쪽 PE로 가중치 패싱
    output reg out_a_valid,   // 오른쪽 PE로 A valid 패싱
    output reg out_b_valid,   // 아래쪽 PE로 B valid 패싱
    output reg [15:0] accum   // 내부 16비트 누산기 결과
);

    // Guard bit 검토:
    // - 단일 MAC 최대값: 8'hFF << 3'd7 = 32640 (15bit 필요)
    // - 2x2 행렬곱의 K=2 누산 최대값: 32640 * 2 = 65280 (16bit에 수용)
    // - K가 4 이상으로 확장되면 17bit 이상 accumulator가 필요하다.
    reg [15:0] shift_res;

    // 조합회로: 곱셈기 대신 8비트 배럴 시프터 구현 (Weight의 거듭제곱배 효과)
    always @(*) begin
        shift_res = {8'b0, in_a} << in_b;
    end

    // 순차회로: 클락 동기화 데이터 전달 및 가산 연산
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_a <= 8'd0;
            out_b <= 3'd0;
            out_a_valid <= 1'b0;
            out_b_valid <= 1'b0;
            accum <= 16'd0;
        end else begin
            out_a <= in_a;
            out_b <= in_b;
            out_a_valid <= in_a_valid;
            out_b_valid <= in_b_valid;
            if (clr_accum) begin
                accum <= mac_en ? shift_res : 16'd0; // 새 연산 시작 시 초기화, 유효하면 첫 MAC 포함
            end else if (mac_en) begin
                accum <= accum + shift_res; // 기존 누산값에 누적
            end
        end
    end

endmodule