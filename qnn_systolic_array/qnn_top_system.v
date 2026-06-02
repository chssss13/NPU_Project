// qnn_top_system.v
module qnn_top_system (
    input wire clk,
    input wire rst_n,
    input wire start,              

    input wire [3:0] data_a0,      // row0 activation
    input wire [3:0] data_a1,      // row1 activation
    input wire [1:0] wgt_b0,       // col0 weight shift
    input wire [1:0] wgt_b1,       // col1 weight shift


    output wire [7:0] system_out,
    output wire o_done             
);

    reg [2:0] phase_cnt;

    wire in_a0_valid = (phase_cnt == 3'd1);
    wire in_b0_valid = (phase_cnt == 3'd1);
    wire in_a1_valid = (phase_cnt == 3'd2);
    wire in_b1_valid = (phase_cnt == 3'd2);

    wire [3:0] core_a0 = in_a0_valid ? data_a0 : 4'd0;
    wire [1:0] core_b0 = in_b0_valid ? wgt_b0  : 2'd0;
    wire [3:0] core_a1 = in_a1_valid ? data_a1 : 4'd0;
    wire [1:0] core_b1 = in_b1_valid ? wgt_b1  : 2'd0;


    wire clr_accum = in_a0_valid & in_b0_valid;


    wire [1:0] out_sel = phase_cnt[1:0];
    assign o_done = (phase_cnt >= 3'd4);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase_cnt <= 3'd0;
        end else begin
            if (phase_cnt == 3'd0) begin
                phase_cnt <= start ? 3'd1 : 3'd0;
            end else if (phase_cnt == 3'd7) begin
                phase_cnt <= 3'd0;
            end else begin
                phase_cnt <= phase_cnt + 3'd1;
            end
        end
    end

    qnn_systolic_array_2d u_qnn_core (
        .clk(clk),
        .rst_n(rst_n),
        .clr_accum(clr_accum),
        .in_a0(core_a0),
        .in_a1(core_a1),
        .in_b0(core_b0),
        .in_b1(core_b1),
        .in_a0_valid(in_a0_valid),
        .in_a1_valid(in_a1_valid),
        .in_b0_valid(in_b0_valid),
        .in_b1_valid(in_b1_valid),
        .out_sel(out_sel),
        .final_out(system_out)
    );

endmodule
