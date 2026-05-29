module systolic_controller_relu #(
  parameter int DATA_W = 4,
  parameter int K_DIM  = 2, //Common dimension
  parameter int ROWS   = 2,
  parameter int COLS   = 2,

  // [추가] 활성화 함수용 파라미터 (Threshold/Bias)
  // 이 값보다 작은 연산 결과는 노이즈로 간주하고 0으로 만듭니다.
  parameter int BIAS   = 30, 

  // 내부 파라미터
  parameter int ACC_W  = 2*DATA_W + $clog2(K_DIM)
)(
  input  logic                      clk,
  input  logic                      rst_n,

  // --- Control Interface ---
  input  logic                      i_start,
  output logic                      o_done,
  output logic                      o_busy,

  // --- Data Interface ---
  input  logic [DATA_W-1:0]         i_mat_a [0:ROWS-1][0:K_DIM-1],
  input  logic [DATA_W-1:0]         i_mat_b [0:K_DIM-1][0:COLS-1],
  output logic [ACC_W-1:0]          o_mat_c [0:ROWS-1][0:COLS-1]
);

  //==========================================================
  // 1. 내부 상태 및 버퍼 정의
  //==========================================================
  typedef enum logic [1:0] {
    IDLE,
    RUN,
    DONE_STATE
  } state_t;

  state_t state, next_state;
  logic [7:0] cnt; 

  // Input Buffer: 입력 데이터를 저장(Latch)해두는 공간
  logic [DATA_W-1:0] latched_mat_a [0:ROWS-1][0:K_DIM-1];
  logic [DATA_W-1:0] latched_mat_b [0:K_DIM-1][0:COLS-1];

  // Array Interface: 실제 Systolic Array로 들어가는 신호
  logic [DATA_W-1:0] array_a_in [0:ROWS-1];
  logic [DATA_W-1:0] array_b_in [0:COLS-1];
  logic              array_en;
  logic              array_clr; 

  // [핵심] Array의 순수 결과값 (PPU 입력용 내부 와이어)
  logic [ACC_W-1:0]  raw_acc_sum [0:ROWS-1][0:COLS-1];

  // 연산 완료까지 걸리는 시간 계산
  // 데이터 주입 완료(ROWS + K_DIM) + 파이프라인 통과(COLS) + 여유
  localparam int CALC_CYCLES = ROWS + COLS + K_DIM + 2;

  //==========================================================
  // 2. FSM & Counter
  //==========================================================
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      cnt   <= 0;
    end else begin
      state <= next_state;
      if (state == RUN) cnt <= cnt + 1;
      else              cnt <= 0;
    end
  end

  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (i_start) next_state = RUN;
      end
      RUN: begin
        if (cnt >= CALC_CYCLES) next_state = DONE_STATE;
      end
      DONE_STATE: begin
        if (!i_start) next_state = IDLE;
      end
    endcase
  end

  // Output Assignments
  assign o_busy   = (state == RUN);
  assign o_done   = (state == DONE_STATE);

  // Array Control Signals
  assign array_en = (state == RUN);

  // IDLE 상태에서 start가 들어오는 순간 Clear 수행 (Accumulator 초기화)
  // 이렇게 하면 PE 내부의 acc_sum이 0으로 리셋되고 새 연산을 시작합니다.
  assign array_clr = (state == IDLE) && i_start;

  //==========================================================
  // 3. Input Buffer Latching
  //==========================================================
  // 연산 도중 입력값이 바뀌어도 내부 연산이 꼬이지 않도록 캡처
  always_ff @(posedge clk) begin
    if (state == IDLE && i_start) begin
      latched_mat_a <= i_mat_a;
      latched_mat_b <= i_mat_b;
    end
  end

  //==========================================================
  // 4. Data Skewing Logic
  //==========================================================
  genvar r, c;
  generate
    // Row Input Control (Matrix A -> Row Input)
    for (r = 0; r < ROWS; r++) begin : GEN_SKEW_A
      always_comb begin
        array_a_in[r] = '0; // Default 0 padding
        if (state == RUN) begin
          // Timing Logic: time(cnt) - row_index(r) = col_index(k)
          int k;
          k = cnt - r;
          if (k >= 0 && k < K_DIM) begin
            array_a_in[r] = latched_mat_a[r][k];
          end
        end
      end
    end

    // Column Input Control (Matrix B -> Col Input)
    for (c = 0; c < COLS; c++) begin : GEN_SKEW_B
      always_comb begin
        array_b_in[c] = '0; // Default 0 padding
        if (state == RUN) begin
          // Timing Logic: time(cnt) - col_index(c) = row_index(k)
          int k;
          k = cnt - c;
          if (k >= 0 && k < K_DIM) begin
            array_b_in[c] = latched_mat_b[k][c];
          end
        end
      end
    end
  endgenerate

  //==========================================================
  // 5. Systolic Array Instantiation
  //==========================================================
  systolic_array_2d #(
    .DATA_W (DATA_W),
    .ACC_W  (ACC_W),
    .ROWS   (ROWS),
    .COLS   (COLS)
  ) u_core_array (
    .clk        (clk),
    .rst_n      (rst_n),
    .clr        (array_clr),
    .en         (array_en),
    .a_in_row   (array_a_in),
    .b_in_col   (array_b_in),
    .pe_mul     (),
    .pe_acc_sum (raw_acc_sum) // [주의] 최종 출력이 아니라 내부 와이어로 연결
  );

  //==========================================================
  // [NEW] 6. Post-Processing Unit (ReLU + Bias)
  //==========================================================
  generate
    for (r = 0; r < ROWS; r++) begin : GEN_PPU_ROW
      for (c = 0; c < COLS; c++) begin : GEN_PPU_COL

        always_comb begin
          // 1. Bias Subtraction (Signed 연산)
          //    값이 작으면 음수가 될 수 있으므로 int(32bit)로 변환하여 계산
          int temp_val;

          temp_val = int'(raw_acc_sum[r][c]) - BIAS;

          // 2. ReLU (Rectified Linear Unit)
          //    0보다 작으면 0(Dead), 아니면 그대로 통과
          if (temp_val < 0) begin
            o_mat_c[r][c] = '0; // Deactivate (Output 0)
          end else begin
            o_mat_c[r][c] = temp_val[ACC_W-1:0]; // Activate (Pass)
          end
        end

      end
    end
  endgenerate

endmodule