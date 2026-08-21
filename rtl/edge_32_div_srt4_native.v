`ifndef EDGE_32_DIV_SRT4_NATIVE_V
`define EDGE_32_DIV_SRT4_NATIVE_V

// One registered-hop combinational slice for the folded radix-4 ring.  The
// parent places a register boundary between every pair of slice instances.
(* keep_hierarchy = "yes" *)
module edge_32_div_srt4_ring_slice (
  input  wire [4:0]  rounds_in,
  input  wire [34:0] partial_sum_in,
  input  wire [34:0] partial_carry_in,
  input  wire [34:0] divisor_in,
  input  wire signed [10:0] divisor_select_in,
  input  wire signed [10:0] divisor_x3_select_in,
  input  wire [34:0] quotient_pos_in,
  input  wire [34:0] quotient_neg_in,
  input  wire        q_pos2_in,
  input  wire        q_pos1_in,
  input  wire        q_neg1_in,
  input  wire        q_neg2_in,
  output wire        q_pos2_out,
  output wire        q_pos1_out,
  output wire        q_neg1_out,
  output wire        q_neg2_out,
  output wire [4:0]  rounds_out,
  output wire [34:0] partial_sum_out,
  output wire [34:0] partial_carry_out,
  output wire [34:0] quotient_pos_out,
  output wire [34:0] quotient_neg_out
);
  wire [6:0] partial_select_bits = partial_sum_in[34:28] +
                                   partial_carry_in[34:28];
  wire signed [7:0] partial_select =
    $signed({partial_select_bits[6], partial_select_bits});
  wire signed [10:0] partial_select_x8 = partial_select <<< 3;
  wire q_pos2 = partial_select_x8 >= divisor_x3_select_in;
  wire q_pos1 = !q_pos2 && partial_select_x8 >= divisor_select_in;
  wire q_neg1 = !q_pos2 && !q_pos1 &&
                !(partial_select_x8 > -divisor_select_in) &&
                (partial_select_x8 > -divisor_x3_select_in);
  wire q_neg2 = !q_pos2 && !q_pos1 &&
                !(partial_select_x8 > -divisor_select_in) && !q_neg1;

  wire [34:0] sum_shift = partial_sum_in << 2;
  wire [34:0] carry_shift = partial_carry_in << 2;
  wire [34:0] digit_operand = q_pos2_in ? ~(divisor_in << 1) :
                              q_pos1_in ? ~divisor_in :
                              q_neg1_in ? divisor_in :
                              q_neg2_in ? (divisor_in << 1) : 35'd0;
  wire subtract_carry_in = q_pos1_in || q_pos2_in;
  wire [34:0] csa_sum0 = sum_shift ^ carry_shift ^ digit_operand;
  wire [34:0] csa_carry0 = ((sum_shift & carry_shift) |
                            (sum_shift & digit_operand) |
                            (carry_shift & digit_operand)) << 1;
  wire [34:0] carry_in_vector = {{34{1'b0}}, subtract_carry_in};
  wire [34:0] iter_sum = csa_sum0 ^ csa_carry0 ^ carry_in_vector;
  wire [34:0] iter_carry = ((csa_sum0 & csa_carry0) |
                            (csa_sum0 & carry_in_vector) |
                            (csa_carry0 & carry_in_vector)) << 1;
  wire [34:0] iter_qpos = (quotient_pos_in << 2) |
                          (q_pos1_in ? 35'd1 : q_pos2_in ? 35'd2 : 35'd0);
  wire [34:0] iter_qneg = (quotient_neg_in << 2) |
                          (q_neg1_in ? 35'd1 : q_neg2_in ? 35'd2 : 35'd0);
  wire iterate = rounds_in != 5'd0;

  assign q_pos2_out = q_pos2;
  assign q_pos1_out = q_pos1;
  assign q_neg1_out = q_neg1;
  assign q_neg2_out = q_neg2;
  assign rounds_out = iterate ? rounds_in - 5'd1 : 5'd0;
  assign partial_sum_out = iterate ? iter_sum : partial_sum_in;
  assign partial_carry_out = iterate ? iter_carry : partial_carry_in;
  assign quotient_pos_out = iterate ? iter_qpos : quotient_pos_in;
  assign quotient_neg_out = iterate ? iter_qneg : quotient_neg_in;
endmodule

// A shallow 35-bit carry-select adder for the non-iterative COMBINE stage.
// The upper 17 bits are speculated in parallel; the lower 18-bit carry drives
// one final mux instead of rippling through the complete word.
(* keep_hierarchy = "yes" *)
module edge_32_add35_csel18 (
  input wire [34:0] lhs,
  input wire [34:0] rhs,
  input wire carry_in,
  output wire [34:0] sum
);
  wire [18:0] low = {1'b0, lhs[17:0]} +
                    {1'b0, rhs[17:0]} + carry_in;
  wire [17:0] high_c0 = {1'b0, lhs[34:18]} +
                        {1'b0, rhs[34:18]};
  wire [17:0] high_c1 = {1'b0, lhs[34:18]} +
                        {1'b0, rhs[34:18]} + 18'd1;
  wire [16:0] high = low[18] ? high_c1[16:0] : high_c0[16:0];
  assign sum = {high, low[17:0]};
endmodule

// ASAP7-oriented radix-4 SRT integer divider.  The partial remainder may be
// negative and quotient digits are selected from {-2,-1,0,+1,+2}.  Positive
// and negative digits accumulate separately so the iterative feedback path
// does not contain a wide quotient add/subtract.
(* keep_hierarchy = "yes" *)
module edge_32_div_srt4_native (
  input  wire                   clk,
  input  wire                   reset_n,
  input  wire                   op_valid,
  output wire                   op_ready,
  input  wire [31:0]            src0,
  input  wire [31:0]            src1,
  input  wire [2:0]             funct3,
  output reg                    result_valid,
  output reg  [31:0]            result_value,
  output wire                   busy,
  output wire [6:0]             op_latency
);
  localparam [3:0] STATE_IDLE = 4'd0;
  localparam [3:0] STATE_FAST = 4'd1;
  localparam [3:0] STATE_ITER = 4'd2;
  localparam [3:0] STATE_COMBINE = 4'd3;
  localparam [3:0] STATE_SCALE_LOW = 4'd4;
  localparam [3:0] STATE_SCALE_MID = 4'd5;
  localparam [3:0] STATE_SCALE_HIGH = 4'd6;
  localparam [3:0] STATE_CORRECT = 4'd7;
  localparam [3:0] STATE_SIGN = 4'd8;
  localparam [3:0] STATE_DECIDE = 4'd9;
  localparam integer RING_STAGES = 2;

  function [4:0] msb_index32;
    input [31:0] value;
    integer i;
    begin
      msb_index32 = 5'd0;
      for (i = 0; i < 32; i = i + 1)
        if (value[i]) msb_index32 = i[4:0];
    end
  endfunction

  reg [3:0] state_r;
  reg [5:0] scale_r;
  reg [34:0] aligned_divisor_r;
  reg signed [10:0] divisor_select_r;
  reg signed [10:0] divisor_x3_select_r;
  reg [31:0] divisor_mag_r;
  reg signed [34:0] quotient_binary_r;
  reg signed [34:0] partial_binary_r;
  reg signed [34:0] partial_scale_r;
  reg signed [34:0] remainder_scaled_r;
  reg signed [1:0] correction_r;
  reg [31:0] quotient_mag_r;
  reg [31:0] remainder_mag_r;
  reg rem_r;
  reg quotient_negative_r;
  reg remainder_negative_r;
  reg [31:0] fast_value_r;
  reg [RING_STAGES-1:0] ring_valid_r;
  reg ring_qds_phase_r;
  reg [4:0] ring_rounds_r [0:RING_STAGES-1];
  reg [34:0] ring_sum_r [0:RING_STAGES-1];
  reg [34:0] ring_carry_r [0:RING_STAGES-1];
  reg [34:0] ring_qpos_r [0:RING_STAGES-1];
  reg [34:0] ring_qneg_r [0:RING_STAGES-1];
  reg ring_q_pos2_r [0:RING_STAGES-1];
  reg ring_q_pos1_r [0:RING_STAGES-1];
  reg ring_q_neg1_r [0:RING_STAGES-1];
  reg ring_q_neg2_r [0:RING_STAGES-1];
  wire [4:0] ring_rounds_next [0:RING_STAGES-1];
  wire [34:0] ring_sum_next [0:RING_STAGES-1];
  wire [34:0] ring_carry_next [0:RING_STAGES-1];
  wire [34:0] ring_qpos_next [0:RING_STAGES-1];
  wire [34:0] ring_qneg_next [0:RING_STAGES-1];
  wire ring_q_pos2_next [0:RING_STAGES-1];
  wire ring_q_pos1_next [0:RING_STAGES-1];
  wire ring_q_neg1_next [0:RING_STAGES-1];
  wire ring_q_neg2_next [0:RING_STAGES-1];
  genvar ring_gen;
  generate
    for (ring_gen = 0; ring_gen < RING_STAGES; ring_gen = ring_gen + 1) begin : ring
      edge_32_div_srt4_ring_slice iteration (
        .rounds_in(ring_rounds_r[ring_gen]),
        .partial_sum_in(ring_sum_r[ring_gen]),
        .partial_carry_in(ring_carry_r[ring_gen]),
        .divisor_in(aligned_divisor_r),
        .divisor_select_in(divisor_select_r),
        .divisor_x3_select_in(divisor_x3_select_r),
        .quotient_pos_in(ring_qpos_r[ring_gen]),
        .quotient_neg_in(ring_qneg_r[ring_gen]),
        .q_pos2_in(ring_q_pos2_r[ring_gen]),
        .q_pos1_in(ring_q_pos1_r[ring_gen]),
        .q_neg1_in(ring_q_neg1_r[ring_gen]),
        .q_neg2_in(ring_q_neg2_r[ring_gen]),
        .q_pos2_out(ring_q_pos2_next[ring_gen]),
        .q_pos1_out(ring_q_pos1_next[ring_gen]),
        .q_neg1_out(ring_q_neg1_next[ring_gen]),
        .q_neg2_out(ring_q_neg2_next[ring_gen]),
        .rounds_out(ring_rounds_next[ring_gen]),
        .partial_sum_out(ring_sum_next[ring_gen]),
        .partial_carry_out(ring_carry_next[ring_gen]),
        .quotient_pos_out(ring_qpos_next[ring_gen]),
        .quotient_neg_out(ring_qneg_next[ring_gen])
      );
    end
  endgenerate

  wire signed_op = !funct3[0];
  wire is_remainder = funct3[1];
  wire src0_sign = src0[31];
  wire src1_sign = src1[31];
  wire [31:0] src0_full_abs = signed_op && src0_sign ?
                               (~src0 + 32'd1) : src0;
  wire [31:0] src1_full_abs = signed_op && src1_sign ?
                               (~src1 + 32'd1) : src1;
  wire [31:0] dividend_mag = src0_full_abs;
  wire [31:0] divisor_mag = src1_full_abs;
  wire divide_by_zero = divisor_mag == 32'd0;
  wire signed_overflow = signed_op &&
    (src0 == 32'h8000_0000) && (src1 == 32'hffff_ffff);
  wire magnitude_lt = dividend_mag < divisor_mag;
  wire magnitude_zero = dividend_mag == 32'd0;
  wire fast_case = divide_by_zero || signed_overflow || magnitude_lt ||
                   magnitude_zero;

  wire [4:0] dividend_msb = msb_index32(dividend_mag);
  wire [4:0] divisor_msb = msb_index32(divisor_mag);
  wire [5:0] exponent_difference = {1'b0, dividend_msb} -
                                   {1'b0, divisor_msb};
  wire [5:0] scale_even = exponent_difference + exponent_difference[0];
  wire [4:0] srt_rounds = scale_even[5:1];
  wire [34:0] aligned_divisor =
    {3'b000, divisor_mag} << scale_even;
  wire [5:0] aligned_msb = {1'b0, divisor_msb} + scale_even;
  wire [5:0] normalize_shift = 6'd32 - aligned_msb;
  wire [5:0] remainder_scale = scale_even + normalize_shift;
  wire [34:0] normalized_divisor = aligned_divisor << normalize_shift;
  wire [34:0] dividend_extended = {3'b000, dividend_mag};
  wire choose_initial_zero = (dividend_extended << 1) < aligned_divisor;
  wire choose_initial_two = (dividend_extended << 1) >=
                            (aligned_divisor + (aligned_divisor << 1));
  wire signed [34:0] initial_partial = choose_initial_zero ?
    $signed(dividend_extended) : choose_initial_two ?
    $signed(dividend_extended) - $signed(aligned_divisor << 1) :
    $signed(dividend_extended) - $signed(aligned_divisor);
  wire signed [34:0] normalized_initial_partial =
    initial_partial <<< normalize_shift;

  // Slot zero owns the final carry-save remainder and signed-digit quotient.
  // Reusing it for COMBINE avoids a second 140-bit register bank.
  wire [34:0] quotient_binary_next;
  wire [34:0] partial_binary_next;
  edge_32_add35_csel18 quotient_combine (
    .lhs(ring_qpos_r[0]), .rhs(~ring_qneg_r[0]), .carry_in(1'b1),
    .sum(quotient_binary_next)
  );
  edge_32_add35_csel18 remainder_combine (
    .lhs(ring_sum_r[0]), .rhs(ring_carry_r[0]), .carry_in(1'b0),
    .sum(partial_binary_next)
  );

  // Truncated digit selection can leave one signed correction in either
  // direction. DECIDE isolates the comparison from these carry-select adders.
  wire [34:0] quotient_minus_one;
  wire [34:0] quotient_plus_one;
  wire [34:0] remainder_plus_divisor;
  wire [34:0] remainder_minus_divisor;
  edge_32_add35_csel18 quotient_decrement (
    .lhs(quotient_binary_r), .rhs({35{1'b1}}), .carry_in(1'b0),
    .sum(quotient_minus_one)
  );
  edge_32_add35_csel18 remainder_add_divisor (
    .lhs(remainder_scaled_r), .rhs({3'b000, divisor_mag_r}),
    .carry_in(1'b0), .sum(remainder_plus_divisor)
  );
  edge_32_add35_csel18 quotient_increment (
    .lhs(quotient_binary_r), .rhs(35'd0), .carry_in(1'b1),
    .sum(quotient_plus_one)
  );
  edge_32_add35_csel18 remainder_sub_divisor (
    .lhs(remainder_scaled_r), .rhs(~{3'b000, divisor_mag_r}),
    .carry_in(1'b1), .sum(remainder_minus_divisor)
  );
  wire [34:0] corrected_quotient = correction_r < 0 ? quotient_minus_one :
                                   correction_r > 0 ? quotient_plus_one :
                                                      quotient_binary_r;
  wire [34:0] corrected_remainder = correction_r < 0 ?
                                     remainder_plus_divisor :
                                     correction_r > 0 ?
                                     remainder_minus_divisor :
                                     remainder_scaled_r;
  wire remainder_ge_divisor = remainder_scaled_r >=
                              $signed({3'b000, divisor_mag_r});
  wire [34:0] negative_quotient_wide;
  wire [34:0] negative_remainder_wide;
  assign negative_quotient_wide = {3'b000, ~quotient_mag_r} + 35'd1;
  assign negative_remainder_wide = {3'b000, ~remainder_mag_r} + 35'd1;
  wire [31:0] signed_quotient = quotient_negative_r ?
                                negative_quotient_wide[31:0] : quotient_mag_r;
  wire [31:0] signed_remainder = remainder_negative_r ?
                                 negative_remainder_wide[31:0] : remainder_mag_r;
  wire [31:0] selected_result = rem_r ? signed_remainder : signed_quotient;

  reg [31:0] fast_value;
  always @* begin
    if (divide_by_zero)
      fast_value = is_remainder ? src0 : 32'hffff_ffff;
    else if (signed_overflow)
      fast_value = is_remainder ? 32'd0 : 32'h8000_0000;
    else if (is_remainder)
      fast_value = src0;
    else
      fast_value = 32'd0;
  end

  assign op_ready = (state_r == STATE_IDLE) && !result_valid;
  assign busy = (state_r != STATE_IDLE) || result_valid;
  // Each pass through the two-slice ring consumes two radix-4 digits.  Exit
  // at the first pass boundary after all requested digits have completed.
  wire [3:0] ring_passes = srt_rounds[4:1] + srt_rounds[0];
  wire [6:0] ring_latency = {ring_passes, 2'b00} + 7'd7;
  assign op_latency = fast_case ? 7'd1 :
                      srt_rounds == 5'd0 ? 7'd7 : ring_latency;

  reg [3:0] state_next;
  reg [RING_STAGES-1:0] ring_valid_next;
  reg ring_qds_phase_next;
  reg result_valid_next;

  always @* begin
    state_next = state_r;
    ring_valid_next = ring_valid_r;
    ring_qds_phase_next = ring_qds_phase_r;
    result_valid_next = 1'b0;
    case (state_r)
      STATE_IDLE: if (op_valid) begin
        if (fast_case)
          state_next = STATE_FAST;
        else if (srt_rounds == 0)
          state_next = STATE_COMBINE;
        else begin
          state_next = STATE_ITER;
          ring_valid_next = {{(RING_STAGES-1){1'b0}}, 1'b1};
          ring_qds_phase_next = 1'b1;
        end
      end
      STATE_FAST: begin
        state_next = STATE_IDLE;
        result_valid_next = 1'b1;
      end
      STATE_ITER: if (ring_qds_phase_r) begin
        ring_qds_phase_next = 1'b0;
      end else begin
        ring_qds_phase_next = 1'b1;
        ring_valid_next[1] = ring_valid_r[0];
        ring_valid_next[0] = ring_valid_r[1] &&
                             (ring_rounds_next[1] != 5'd0);
        if (ring_valid_r[1] && (ring_rounds_next[1] == 5'd0))
          state_next = STATE_COMBINE;
      end
      STATE_COMBINE: state_next = STATE_SCALE_LOW;
      STATE_SCALE_LOW: state_next = STATE_SCALE_MID;
      STATE_SCALE_MID: state_next = STATE_SCALE_HIGH;
      STATE_SCALE_HIGH: state_next = STATE_DECIDE;
      STATE_DECIDE: state_next = STATE_CORRECT;
      STATE_CORRECT: state_next = STATE_SIGN;
      STATE_SIGN: begin
        state_next = STATE_IDLE;
        result_valid_next = 1'b1;
      end
      default: state_next = STATE_IDLE;
    endcase
  end

  always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      state_r <= STATE_IDLE;
      ring_valid_r <= {RING_STAGES{1'b0}};
      ring_qds_phase_r <= 1'b1;
      result_valid <= 1'b0;
    end else begin
      state_r <= state_next;
      ring_valid_r <= ring_valid_next;
      ring_qds_phase_r <= ring_qds_phase_next;
      result_valid <= result_valid_next;
    end
  end

  integer ring_i;
  always @(posedge clk) begin
      case (state_r)
        STATE_IDLE: if (op_valid) begin
          rem_r <= is_remainder;
          quotient_negative_r <= signed_op && (src0_sign ^ src1_sign);
          remainder_negative_r <= signed_op && src0_sign;
          if (fast_case) begin
            fast_value_r <= fast_value;
          end else begin
            scale_r <= remainder_scale;
            aligned_divisor_r <= normalized_divisor;
            divisor_select_r <=
              $signed({4'b0000, normalized_divisor[34:28]});
            divisor_x3_select_r <=
              $signed({4'b0000, normalized_divisor[34:28]}) +
              ($signed({4'b0000, normalized_divisor[34:28]}) <<< 1);
            divisor_mag_r <= divisor_mag;
            ring_rounds_r[0] <= srt_rounds;
            ring_sum_r[0] <= normalized_initial_partial;
            ring_carry_r[0] <= 35'd0;
            ring_qpos_r[0] <= choose_initial_zero ? 35'd0 :
                              choose_initial_two ? 35'd2 : 35'd1;
            ring_qneg_r[0] <= 35'd0;
            if (srt_rounds != 0) begin
              ring_q_pos2_r[0] <= 1'b0;
              ring_q_pos1_r[0] <= 1'b0;
              ring_q_neg1_r[0] <= 1'b0;
              ring_q_neg2_r[0] <= 1'b0;
            end
          end
        end
        STATE_FAST: begin
          result_value <= fast_value_r;
        end
        STATE_ITER: begin
          if (ring_qds_phase_r) begin
            for (ring_i = 0; ring_i < RING_STAGES; ring_i = ring_i + 1) begin
              ring_q_pos2_r[ring_i] <= ring_q_pos2_next[ring_i];
              ring_q_pos1_r[ring_i] <= ring_q_pos1_next[ring_i];
              ring_q_neg1_r[ring_i] <= ring_q_neg1_next[ring_i];
              ring_q_neg2_r[ring_i] <= ring_q_neg2_next[ring_i];
            end
          end else begin
            for (ring_i = 1; ring_i < RING_STAGES; ring_i = ring_i + 1) begin
            ring_rounds_r[ring_i] <= ring_rounds_next[ring_i-1];
            ring_sum_r[ring_i] <= ring_sum_next[ring_i-1];
            ring_carry_r[ring_i] <= ring_carry_next[ring_i-1];
            ring_qpos_r[ring_i] <= ring_qpos_next[ring_i-1];
            ring_qneg_r[ring_i] <= ring_qneg_next[ring_i-1];
            end
            if (ring_valid_r[RING_STAGES-1] &&
                (ring_rounds_next[RING_STAGES-1] != 5'd0)) begin
              ring_rounds_r[0] <= ring_rounds_next[RING_STAGES-1];
              ring_sum_r[0] <= ring_sum_next[RING_STAGES-1];
              ring_carry_r[0] <= ring_carry_next[RING_STAGES-1];
              ring_qpos_r[0] <= ring_qpos_next[RING_STAGES-1];
              ring_qneg_r[0] <= ring_qneg_next[RING_STAGES-1];
            end
            if (ring_valid_r[RING_STAGES-1] &&
                (ring_rounds_next[RING_STAGES-1] == 5'd0)) begin
              ring_rounds_r[0] <= ring_rounds_next[RING_STAGES-1];
              ring_sum_r[0] <= ring_sum_next[RING_STAGES-1];
              ring_carry_r[0] <= ring_carry_next[RING_STAGES-1];
              ring_qpos_r[0] <= ring_qpos_next[RING_STAGES-1];
              ring_qneg_r[0] <= ring_qneg_next[RING_STAGES-1];
            end
          end
        end
        STATE_COMBINE: begin
          quotient_binary_r <= $signed(quotient_binary_next);
          partial_binary_r <= $signed(partial_binary_next);
        end
        STATE_SCALE_LOW: begin
          case (scale_r[1:0])
            2'd1: partial_scale_r <= partial_binary_r >>> 1;
            2'd2: partial_scale_r <= partial_binary_r >>> 2;
            2'd3: partial_scale_r <= partial_binary_r >>> 3;
            default: partial_scale_r <= partial_binary_r;
          endcase
        end
        STATE_SCALE_MID: begin
          case (scale_r[3:2])
            2'd1: partial_scale_r <= partial_scale_r >>> 4;
            2'd2: partial_scale_r <= partial_scale_r >>> 8;
            2'd3: partial_scale_r <= partial_scale_r >>> 12;
            default: partial_scale_r <= partial_scale_r;
          endcase
        end
        STATE_SCALE_HIGH: begin
          case (scale_r[5:4])
            2'd1: remainder_scaled_r <= partial_scale_r >>> 16;
            2'd2: remainder_scaled_r <= partial_scale_r >>> 32;
            default: remainder_scaled_r <= partial_scale_r;
          endcase
        end
        STATE_DECIDE: begin
          if (remainder_scaled_r < 0)
            correction_r <= -2'sd1;
          else if (remainder_ge_divisor)
            correction_r <= 2'sd1;
          else
            correction_r <= 2'sd0;
        end
        STATE_CORRECT: begin
          quotient_mag_r <= corrected_quotient[31:0];
          remainder_mag_r <= corrected_remainder[31:0];
        end
        STATE_SIGN: begin
          result_value <= selected_result;
        end
        default: ;
      endcase
  end
endmodule

`endif
