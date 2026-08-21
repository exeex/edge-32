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

// Nine-bit carry-select boundary for the 500 ps post-iteration stages.  The
// upper half is speculated in parallel with the lower carry chain.
(* keep_hierarchy = "yes" *)
module edge_32_add18_csel9 (
  input  wire [17:0] lhs,
  input  wire [17:0] rhs,
  input  wire        carry_in,
  output wire [18:0] sum
);
  wire [9:0] low = {1'b0, lhs[8:0]} +
                   {1'b0, rhs[8:0]} + carry_in;
  wire [9:0] high_c0 = {1'b0, lhs[17:9]} +
                       {1'b0, rhs[17:9]};
  wire [9:0] high_c1 = {1'b0, lhs[17:9]} +
                       {1'b0, rhs[17:9]} + 10'd1;
  wire [9:0] high = low[9] ? high_c1 : high_c0;
  assign sum = {high, low[8:0]};
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
  localparam [3:0] STATE_COMBINE_LOW = 4'd3;
  localparam [3:0] STATE_SCALE_LOW = 4'd4;
  localparam [3:0] STATE_SCALE_MID = 4'd5;
  localparam [3:0] STATE_SCALE_HIGH = 4'd6;
  localparam [3:0] STATE_CORRECT_LOW = 4'd7;
  localparam [3:0] STATE_SIGN = 4'd8;
  localparam [3:0] STATE_DECIDE = 4'd9;
  localparam [3:0] STATE_CORRECT_HIGH = 4'd10;
  localparam [3:0] STATE_COMBINE_HIGH = 4'd11;
  localparam integer RING_STAGES = 2;

  function [4:0] msb_index32;
    input [31:0] value;
    reg [1:0] byte_index;
    reg [7:0] selected_byte;
    reg [2:0] bit_index;
    begin
      if (|value[31:24]) begin
        byte_index = 2'd3;
        selected_byte = value[31:24];
      end else if (|value[23:16]) begin
        byte_index = 2'd2;
        selected_byte = value[23:16];
      end else if (|value[15:8]) begin
        byte_index = 2'd1;
        selected_byte = value[15:8];
      end else begin
        byte_index = 2'd0;
        selected_byte = value[7:0];
      end

      if (|selected_byte[7:4]) begin
        if (|selected_byte[7:6])
          bit_index = selected_byte[7] ? 3'd7 : 3'd6;
        else
          bit_index = selected_byte[5] ? 3'd5 : 3'd4;
      end else begin
        if (|selected_byte[3:2])
          bit_index = selected_byte[3] ? 3'd3 : 3'd2;
        else
          bit_index = selected_byte[1] ? 3'd1 : 3'd0;
      end
      msb_index32 = {byte_index, bit_index};
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
  reg [17:0] quotient_combine_low_r;
  reg [17:0] remainder_combine_low_r;
  reg quotient_combine_carry_r;
  reg remainder_combine_carry_r;
  reg signed [34:0] partial_scale_r;
  reg signed [34:0] remainder_scaled_r;
  reg correction_negative_r;
  reg correction_positive_r;
  reg [17:0] quotient_correction_low_r;
  reg [17:0] remainder_correction_low_r;
  reg quotient_correction_carry_r;
  reg remainder_correction_carry_r;
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
  // The divisor's two shifts collapse algebraically:
  //   scale_even + (32 - (divisor_msb + scale_even)) = 32 - divisor_msb.
  // Keep normalize_shift for the dividend, but remove scale_even from the
  // normalized-divisor and final-remainder shift cones.
  wire [5:0] divisor_normalize_shift = 6'd32 -
                                         {1'b0, divisor_msb};
  wire [5:0] remainder_scale = divisor_normalize_shift;
  wire [34:0] normalized_divisor =
    {3'b000, divisor_mag} << divisor_normalize_shift;
  wire [34:0] dividend_extended = {3'b000, dividend_mag};
  wire choose_initial_zero = (dividend_extended << 1) < aligned_divisor;
  wire choose_initial_two = (dividend_extended << 1) >=
                            (aligned_divisor + (aligned_divisor << 1));
  wire signed [34:0] normalized_dividend =
    $signed(dividend_extended << normalize_shift);
  wire signed [34:0] normalized_initial_partial =
    choose_initial_zero ? normalized_dividend : choose_initial_two ?
    normalized_dividend - $signed(normalized_divisor << 1) :
    normalized_dividend - $signed(normalized_divisor);

  // Slot zero owns the final carry-save remainder and signed-digit quotient.
  // COMBINE_LOW and COMBINE_HIGH form a true 18/17-bit pipeline, avoiding a
  // complete 35-bit carry path at the 500 ps target.
  wire [34:0] quotient_neg_inverted = ~ring_qneg_r[0];
  wire [18:0] quotient_combine_low;
  wire [18:0] remainder_combine_low;
  wire [18:0] quotient_combine_high;
  wire [18:0] remainder_combine_high;
  edge_32_add18_csel9 quotient_combine_low_add (
    .lhs(ring_qpos_r[0][17:0]),
    .rhs(quotient_neg_inverted[17:0]), .carry_in(1'b1),
    .sum(quotient_combine_low)
  );
  edge_32_add18_csel9 remainder_combine_low_add (
    .lhs(ring_sum_r[0][17:0]), .rhs(ring_carry_r[0][17:0]),
    .carry_in(1'b0), .sum(remainder_combine_low)
  );
  edge_32_add18_csel9 quotient_combine_high_add (
    .lhs({1'b0, ring_qpos_r[0][34:18]}),
    .rhs({1'b0, quotient_neg_inverted[34:18]}),
    .carry_in(quotient_combine_carry_r), .sum(quotient_combine_high)
  );
  edge_32_add18_csel9 remainder_combine_high_add (
    .lhs({1'b0, ring_sum_r[0][34:18]}),
    .rhs({1'b0, ring_carry_r[0][34:18]}),
    .carry_in(remainder_combine_carry_r), .sum(remainder_combine_high)
  );

  // DECIDE registers one-hot correction controls.  CORRECT_LOW and
  // CORRECT_HIGH then form a true 18/14-bit pipeline instead of asking one
  // carry-select adder and its control fanout to close in a single cycle.
  wire [31:0] quotient_correction_operand = correction_negative_r ?
                                                32'hffff_ffff : 32'd0;
  wire [31:0] remainder_correction_operand = correction_negative_r ?
    divisor_mag_r : correction_positive_r ? ~divisor_mag_r : 32'd0;
  wire [18:0] quotient_correction_low;
  wire [18:0] remainder_correction_low;
  wire [18:0] quotient_correction_high;
  wire [18:0] remainder_correction_high;
  edge_32_add18_csel9 quotient_correction_low_add (
    .lhs(quotient_binary_r[17:0]),
    .rhs(quotient_correction_operand[17:0]),
    .carry_in(correction_positive_r), .sum(quotient_correction_low)
  );
  edge_32_add18_csel9 remainder_correction_low_add (
    .lhs(remainder_scaled_r[17:0]),
    .rhs(remainder_correction_operand[17:0]),
    .carry_in(correction_positive_r), .sum(remainder_correction_low)
  );
  edge_32_add18_csel9 quotient_correction_high_add (
    .lhs({4'b0000, quotient_binary_r[31:18]}),
    .rhs({4'b0000, quotient_correction_operand[31:18]}),
    .carry_in(quotient_correction_carry_r), .sum(quotient_correction_high)
  );
  edge_32_add18_csel9 remainder_correction_high_add (
    .lhs({4'b0000, remainder_scaled_r[31:18]}),
    .rhs({4'b0000, remainder_correction_operand[31:18]}),
    .carry_in(remainder_correction_carry_r), .sum(remainder_correction_high)
  );
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
  wire [6:0] ring_latency = {ring_passes, 2'b00} + 7'd9;
  assign op_latency = fast_case ? 7'd1 :
                      srt_rounds == 5'd0 ? 7'd9 : ring_latency;

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
          state_next = STATE_COMBINE_LOW;
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
          state_next = STATE_COMBINE_LOW;
      end
      STATE_COMBINE_LOW: state_next = STATE_COMBINE_HIGH;
      STATE_COMBINE_HIGH: state_next = STATE_SCALE_LOW;
      STATE_SCALE_LOW: state_next = STATE_SCALE_MID;
      STATE_SCALE_MID: state_next = STATE_SCALE_HIGH;
      STATE_SCALE_HIGH: state_next = STATE_DECIDE;
      STATE_DECIDE: state_next = STATE_CORRECT_LOW;
      STATE_CORRECT_LOW: state_next = STATE_CORRECT_HIGH;
      STATE_CORRECT_HIGH: state_next = STATE_SIGN;
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
`ifdef EDGE32_QDS_LATCH
  // QDS is evaluated during the high half-cycle.  The latch closes before
  // the carry-save update edge, so the update stage sees a stable digit while
  // borrowing the otherwise unused high phase.  Keep CLK ungated so CTS and
  // latch timing analysis see the primary clock, not a derived enable.
  always_latch begin
    if (clk) begin
      for (ring_i = 0; ring_i < RING_STAGES; ring_i = ring_i + 1) begin
        ring_q_pos2_r[ring_i] <= ring_q_pos2_next[ring_i];
        ring_q_pos1_r[ring_i] <= ring_q_pos1_next[ring_i];
        ring_q_neg1_r[ring_i] <= ring_q_neg1_next[ring_i];
        ring_q_neg2_r[ring_i] <= ring_q_neg2_next[ring_i];
      end
    end
  end
`endif

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
`ifndef EDGE32_QDS_LATCH
            if (srt_rounds != 0) begin
              ring_q_pos2_r[0] <= 1'b0;
              ring_q_pos1_r[0] <= 1'b0;
              ring_q_neg1_r[0] <= 1'b0;
              ring_q_neg2_r[0] <= 1'b0;
            end
`endif
          end
        end
        STATE_FAST: begin
          result_value <= fast_value_r;
        end
        STATE_ITER: begin
          if (ring_qds_phase_r) begin
`ifndef EDGE32_QDS_LATCH
            for (ring_i = 0; ring_i < RING_STAGES; ring_i = ring_i + 1) begin
              ring_q_pos2_r[ring_i] <= ring_q_pos2_next[ring_i];
              ring_q_pos1_r[ring_i] <= ring_q_pos1_next[ring_i];
              ring_q_neg1_r[ring_i] <= ring_q_neg1_next[ring_i];
              ring_q_neg2_r[ring_i] <= ring_q_neg2_next[ring_i];
            end
`endif
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
        STATE_COMBINE_LOW: begin
          quotient_combine_low_r <= quotient_combine_low[17:0];
          remainder_combine_low_r <= remainder_combine_low[17:0];
          quotient_combine_carry_r <= quotient_combine_low[18];
          remainder_combine_carry_r <= remainder_combine_low[18];
        end
        STATE_COMBINE_HIGH: begin
          quotient_binary_r <= $signed({quotient_combine_high[16:0],
                                        quotient_combine_low_r});
          partial_binary_r <= $signed({remainder_combine_high[16:0],
                                       remainder_combine_low_r});
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
          correction_negative_r <= remainder_scaled_r < 0;
          correction_positive_r <= remainder_scaled_r >= 0 &&
                                   remainder_ge_divisor;
        end
        STATE_CORRECT_LOW: begin
          quotient_correction_low_r <= quotient_correction_low[17:0];
          remainder_correction_low_r <= remainder_correction_low[17:0];
          quotient_correction_carry_r <= quotient_correction_low[18];
          remainder_correction_carry_r <= remainder_correction_low[18];
        end
        STATE_CORRECT_HIGH: begin
          quotient_mag_r <= {quotient_correction_high[13:0],
                             quotient_correction_low_r};
          remainder_mag_r <= {remainder_correction_high[13:0],
                              remainder_correction_low_r};
        end
        STATE_SIGN: begin
          result_value <= selected_result;
        end
        default: ;
      endcase
  end
endmodule

`endif
