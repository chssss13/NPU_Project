// qnn_systolic_array_2d.v
module qnn_systolic_array_2d (
    input wire clk,
    input wire rst_n,
    input wire clr_accum,
    
    // 컨트롤러로부터 인가받는 스큐된 입력 와이어
    input wire [3:0] in_a0, input wire [3:0] in_a1,
    input wire [1:0] in_b0, input wire [1:0] in_b1,
    input wire in_a0_valid, input wire in_a1_valid,
    input wire in_b0_valid, input wire in_b1_valid,
    
    input wire [1:0] out_sel,
    output reg [7:0] final_out
);

    // PE 상호간의 전송 연결을 위한 와이어망
    wire [3:0] a00_to_a01, a10_to_a11;
    wire [1:0] b00_to_b10, b01_to_b11;
    wire a00_to_a01_valid, a10_to_a11_valid;
    wire b00_to_b10_valid, b01_to_b11_valid;
    
    wire [7:0] pe00_out, pe01_out, pe10_out, pe11_out;

    // PE (0,0) - 무지연 다이렉트 셀
    qnn_pe_cell pe00 (
        .clk(clk), .rst_n(rst_n), .clr_accum(clr_accum),
        .in_a(in_a0), .in_b(in_b0), .in_a_valid(in_a0_valid), .in_b_valid(in_b0_valid),
        .out_a(a00_to_a01), .out_b(b00_to_b10), .out_a_valid(a00_to_a01_valid), .out_b_valid(b00_to_b10_valid), .out_data(pe00_out)
    );

    // PE (0,1) - ★ 포트 오타 수정 (in_a0 대신 좌측 PE00의 출력물인 a00_to_a01 수령)
    qnn_pe_cell pe01 (
        .clk(clk), .rst_n(rst_n), .clr_accum(clr_accum),
        .in_a(a00_to_a01), .in_b(in_b1), .in_a_valid(a00_to_a01_valid), .in_b_valid(in_b1_valid),
        .out_a(), .out_b(b01_to_b11), .out_a_valid(), .out_b_valid(b01_to_b11_valid), .out_data(pe01_out)
    );

    // PE (1,0) - ★ 포트 오타 수정 (in_b0 대신 상단 PE00의 가중치 출력물인 b00_to_b10 수령)
    qnn_pe_cell pe10 (
        .clk(clk), .rst_n(rst_n), .clr_accum(clr_accum),
        .in_a(in_a1), .in_b(b00_to_b10), .in_a_valid(in_a1_valid), .in_b_valid(b00_to_b10_valid),
        .out_a(a10_to_a11), .out_b(), .out_a_valid(a10_to_a11_valid), .out_b_valid(), .out_data(pe10_out)
    );

    // PE (1,1) - ★ 포트 오타 수정 (좌측의 a10_to_a11과 상단의 b01_to_b11을 교차 수령)
    qnn_pe_cell pe11 (
        .clk(clk), .rst_n(rst_n), .clr_accum(clr_accum),
        .in_a(a10_to_a11), .in_b(b01_to_b11), .in_a_valid(a10_to_a11_valid), .in_b_valid(b01_to_b11_valid),
        .out_a(), .out_b(), .out_a_valid(), .out_b_valid(), .out_data(pe11_out)
    );

    // Restoring을 위한 출력 멀티플렉서
    always @(*) begin
        case (out_sel)
            2'b00: final_out = pe00_out;
            2'b01: final_out = pe01_out;
            2'b10: final_out = pe10_out;
            2'b11: final_out = pe11_out;
            default: final_out = 8'd0;
        endcase
    end

endmodule