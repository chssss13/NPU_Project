module mac_pe #(
  parameter int DATA_W = 8,               // 입력 데이터 폭
  parameter int ACC_W  = 2*DATA_W         // 누산기 폭 (곱셈 결과를 안전하게 담을 수 있도록) 
// 두 개의 n-bit 수를 곱하면 결과값은 최대 2n-bit 
// 그런데 accumulation 하면 더 커지기 때문에  guard bit가 필요하다. 2^16-1 < (2^8-1) * (2^8-1) * K_DIM
)(
  input  logic                  clk,      // Clock
  input  logic                  rst_n,    // Active-low reset

  input  logic                  clr,      // 누산 초기화
  input  logic                  en,       // 연산 enable

  input  logic [DATA_W-1:0]     a,        // operand 1
  input  logic [DATA_W-1:0]     b,        // operand 2

  output logic [ACC_W-1:0]      mul,      // a*b 결과
  output logic [ACC_W-1:0]      acc_sum   // 누산 결과
);
)(
  input  logic                  clk,      // Clock
  input  logic                  rst_n,    // Active-low reset

  input  logic                  clr,      // 누산 초기화
  input  logic                  en,       // 연산 enable

  input  logic [DATA_W-1:0]     a,        // operand 1
  input  logic [DATA_W-1:0]     b,        // operand 2

  output logic [ACC_W-1:0]      mul,      // a*b 결과
  output logic [ACC_W-1:0]      acc_sum   // 누산 결과
);

  // 곱셈기: 조합 논리
  always_comb begin
    mul = a * b;  
  end

  // 누산기: acc_sum <= acc_sum + mul
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      acc_sum <= '0;
    end
    else begin
      if (clr) begin
        acc_sum <= '0;
      end
      else if (en) begin
        acc_sum <= acc_sum + mul;
      end
      // en=0이면 acc_sum 유지
    end
  end

endmodule
