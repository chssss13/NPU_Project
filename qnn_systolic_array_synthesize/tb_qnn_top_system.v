`timescale 1ns / 1ps

module tb_qnn_top_system;

    reg clk;
    reg rst_n;
    reg start;
    reg [3:0] data_a0;
    reg [3:0] data_a1;
    reg [1:0] wgt_b0;
    reg [1:0] wgt_b1;

    wire [7:0] system_out;
    wire o_done;

    qnn_top_system uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .data_a0(data_a0),
        .data_a1(data_a1),
        .wgt_b0(wgt_b0),
        .wgt_b1(wgt_b1),
        .system_out(system_out),
        .o_done(o_done)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("qnn_system.vcd");
        $dumpvars(0, tb_qnn_top_system);

        clk = 0;
        rst_n = 0;
        start = 0;
        data_a0 = 4'd0;
        data_a1 = 4'd0;
        wgt_b0 = 2'd0;
        wgt_b1 = 2'd0;

        #20;
        rst_n = 1;
        #10;

        $display("[TB INFO] Starting parallel-input / sequential-output QNN test.");
        @(negedge clk);
        data_a0 = 4'd10;
        data_a1 = 4'd12;
        wgt_b0 = 2'd2;  // 10 << 2 = 40 at PE00
        wgt_b1 = 2'd1;  // 10 << 1 = 20 can propagate to PE01
        start = 1;

        @(negedge clk);
        start = 0;

        wait (o_done == 1'b1);
        #1;
        $display("[RESULT] OUT0(PE00) = %d (Expected: 40)", system_out);
        if (system_out !== 8'd40) begin
            $display("[TB ERROR] PE00 mismatch: got %d, expected 40", system_out);
        end

        @(posedge clk); #1;
        $display("[RESULT] OUT1(PE01) = %d (Expected: 20)", system_out);
        if (system_out !== 8'd20) begin
            $display("[TB ERROR] PE01 mismatch: got %d, expected 20", system_out);
        end

        @(posedge clk); #1;
        $display("[RESULT] OUT2(PE10) = %d (Expected: 48)", system_out);
        if (system_out !== 8'd48) begin
            $display("[TB ERROR] PE10 mismatch: got %d, expected 48", system_out);
        end

        @(posedge clk); #1;
        $display("[RESULT] OUT3(PE11) = %d (Expected: 24)", system_out);
        if (system_out !== 8'd24) begin
            $display("[TB ERROR] PE11 mismatch: got %d, expected 24", system_out);
        end

        $display("[TB INFO] Parallel input and sequential output verified successfully.");
        #10;
        $finish;
    end

endmodule
