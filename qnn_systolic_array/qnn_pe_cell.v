// qnn_pe_cell.v
module qnn_pe_cell (
    input wire clk,
    input wire rst_n,
    input wire clr_accum,
    input wire [3:0] in_a,
    input wire [1:0] in_b,
    input wire in_a_valid,
    input wire in_b_valid,
    output wire [3:0] out_a,
    output wire [1:0] out_b,
    output wire out_a_valid,
    output wire out_b_valid,
    output wire [7:0] out_data
);

    wire [7:0] accum_raw;
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

    // weight shift를 0~3으로 제한했기 때문에 K=2 최대 누산값은 240이다.
    // 따라서 8비트 출력 범위 내에 항상 들어오므로 saturation logic 없이 직접 연결한다.
    assign out_data = accum_raw;

endmodule