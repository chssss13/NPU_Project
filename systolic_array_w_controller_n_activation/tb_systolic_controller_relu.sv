//[5] systolic_array_2d + controller + Activation(ReLu)

`timescale 1ns/1ps

module tb_systolic_controller_relu;

  parameter int DATA_W = 4;
  parameter int K_DIM  = 4;
  parameter int ROWS   = 1;
  parameter int COLS   = 4;

  // [설정] Bias를 50으로 설정 (행렬 곱 결과가 50보다 작으면 0이 됨)
  // 랜덤 입력이 보통 15*15=225 근처이므로, 일부 값은 0이 될 수 있음
  parameter int BIAS   = 50; 

  parameter int ACC_W  = 2*DATA_W + $clog2(K_DIM);

  logic clk, rst_n;

  logic start, done, busy;
  logic [DATA_W-1:0] tb_mat_a [0:ROWS-1][0:K_DIM-1];
  logic [DATA_W-1:0] tb_mat_b [0:K_DIM-1][0:COLS-1];
  logic [ACC_W-1:0]  tb_mat_c [0:ROWS-1][0:COLS-1];

  // Reference Model
  int C_ref [0:ROWS-1][0:COLS-1];
  int err_cnt;

  // DUT Instantiation
  systolic_controller_relu #(
    .DATA_W(DATA_W), 
    .K_DIM(K_DIM), 
    .ROWS(ROWS), 
    .COLS(COLS),
    .BIAS(BIAS) // Bias 파라미터 전달
  ) dut (
    .clk        (clk),
    .rst_n      (rst_n),

    // Control Interface
    .i_start    (start),
    .o_done     (done),
    .o_busy     (busy),

    // Data Interface
    .i_mat_a    (tb_mat_a),
    .i_mat_b    (tb_mat_b),
    .o_mat_c    (tb_mat_c)
  );

  // Clock Gen
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
    rst_n = 0;
    start = 0;
    tb_mat_a  = '{default:0};
    tb_mat_b  = '{default:0};

    #20 rst_n = 1;

    $display("=== Controller Verification with ReLU (Bias=%0d) ===", BIAS);

    for (int iter = 0; iter < 5; iter++) begin

      // 1. Data Setup (Random)
      //    TB에서는 그냥 평범한 행렬 모양으로 넣으면 됨 (Skew 불필요)
      for(int r=0; r<ROWS; r++)
        for(int k=0; k<K_DIM; k++) 
          tb_mat_a[r][k] = $urandom_range(0, (1<<DATA_W)-1);

      for(int k=0; k<K_DIM; k++)
        for(int c=0; c<COLS; c++) 
          tb_mat_b[k][c] = $urandom_range(0, (1<<DATA_W)-1);

      // 2. Calculate Reference (ReLU Logic 적용)
      for(int r=0; r<ROWS; r++) begin
        for(int c=0; c<COLS; c++) begin
          int temp_sum;
          temp_sum = 0;

          // (1) MAC Calculation
          for(int k=0; k<K_DIM; k++) 
            temp_sum += tb_mat_a[r][k] * tb_mat_b[k][c];

          // (2) Bias Subtraction
          temp_sum = temp_sum - BIAS;

          // (3) ReLU (Activation)
          if (temp_sum < 0) C_ref[r][c] = 0;
          else              C_ref[r][c] = temp_sum;
        end
      end

      // 3. Start Operation
      @(posedge clk);
      start = 1;
      @(posedge clk);
      start = 0;

      // 4. Wait for Done
      wait(done == 1);

      // 5. Check Result
      err_cnt = 0;
      $display("--------------------------------------------------");
      $display("[Iter %0d] Checking Result...", iter);
      for(int r=0; r<ROWS; r++) begin
        for(int c=0; c<COLS; c++) begin
          if (tb_mat_c[r][c] !== C_ref[r][c]) begin
             $display("ERROR! [%0d][%0d]: DUT=%0d, REF=%0d", r, c, tb_mat_c[r][c], C_ref[r][c]);
             err_cnt++;
          end else begin
             // 0이 나오면 ReLU가 동작하여 값을 죽인 것
             if (tb_mat_c[r][c] == 0)
               $display("PASS!  [%0d][%0d]: DUT=%0d (ReLU Activated)", r, c, tb_mat_c[r][c]);
             else
               $display("PASS!  [%0d][%0d]: DUT=%0d", r, c, tb_mat_c[r][c]);
          end
        end
      end

      if (err_cnt == 0) $display("[Iter %0d] FINAL RESULT: PASS!", iter);
      else              $display("[Iter %0d] FINAL RESULT: FAIL! (%0d errors)", iter, err_cnt);
      $display("--------------------------------------------------");

      // 6. Wait a bit before next run
      @(posedge clk);
    end

    $display("=== All Tests Finished ===");
    $finish;
  end

endmodule