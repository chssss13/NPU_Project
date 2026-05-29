module pe_systolic_cell #(
  parameter int DATA_W = 8,
  parameter int ACC_W  = 2*DATA_W
)(
  input  logic                 clk,
  input  logic                 rst_n,
  input  logic                 clr,
  input  logic                 en,

  input  logic [DATA_W-1:0]    a_in,
  input  logic [DATA_W-1:0]    b_in,
  output logic [DATA_W-1:0]    a_out,
  output logic [DATA_W-1:0]    b_out,

  output logic [ACC_W-1:0]     mul,
  output logic [ACC_W-1:0]     acc_sum
);

  // a, b를 한 번 레지스터에 잡고 옆/아래로 전달
  logic [DATA_W-1:0] a_reg, b_reg;

  assign a_out = a_reg;
  assign b_out = b_reg;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      a_reg <= '0;
      b_reg <= '0;
    //end else if (clr) begin
    //clr은 연산기(mac_pe)의 누적값 초기화에만 관여하고, 데이터 전달(a_reg, b_reg)은 건드리지 않는 것이 일반적인 설계
    end else if (en) begin //debugging point
      a_reg <= a_in;
      b_reg <= b_in;
    end
    // en=0 이면 값 유지 (Stall)
  end

  // 내부 MAC 동작: a_reg * b_reg 누산
  mac_pe #(
    .DATA_W (DATA_W),
    .ACC_W  (ACC_W)
  ) u_mac_pe (
    .clk     (clk),
    .rst_n   (rst_n),
    .clr     (clr),
    .en      (en),
    .a       (a_reg),
    .b       (b_reg),
    .mul     (mul),
    .acc_sum (acc_sum)
  );

endmodule
