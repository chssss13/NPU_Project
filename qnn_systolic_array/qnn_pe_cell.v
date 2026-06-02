// qnn_pe_cell.v
module qnn_pe_cell (
    input wire clk,
    input wire rst_n,
    input wire clr_accum,
    input wire relu_en,
    input wire [7:0] in_a,
    input wire [2:0] in_b,
    input wire in_a_valid,
    input wire in_b_valid,
    output wire [7:0] out_a,
    output wire [2:0] out_b,
    output wire out_a_valid,
    output wire out_b_valid,
    output reg [7:0] out_data
);

    wire [15:0] accum_raw;
    wire mac_en;

    assign mac_en = in_a_valid & in_b_valid;

    // 경량 PE 인스턴스화
    qnn_mac_pe u_qnn_mac_pe (
        .clk(clk),
        .rst_n(rst_n),
        .clr_accum(clr_accum),
        .mac_en(mac_en),
        .in_a(in_a),
        .in_b(in_b),
        .in_a_valid(in_a_valid),
        .in_b_valid(in_b_valid),
        .out_a(out_a),
        .out_b(out_b),
        .out_a_valid(out_a_valid),
        .out_b_valid(out_b_valid),
        .accum(accum_raw)
    );

    // 조합회로: 현재 MAC은 unsigned 2^n shift 누산 구조이므로
    // accum_raw[15]를 음수 sign bit로 보지 않고, 8비트 출력 범위 초과 여부만 확인해 포화 처리한다.
    // relu_en 포트는 상위 인터페이스 호환을 위해 유지하지만, unsigned 구조에서는 별도 음수 클램프가 없다.
    always @(*) begin
        if (accum_raw[15:8] != 8'b0) begin
            out_data = 8'hFF;
        end else begin
            out_data = accum_raw[7:0];
        end
    end

endmodule