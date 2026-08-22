// SPDX-License-Identifier: Apache-2.0
// Throughput-one 32x32 unsigned radix-4 Booth multiplier lane.
(* keep_hierarchy = "yes" *)
module edge_mul32_booth_lane (
  input  wire        clk,
  input  wire        reset_n,
  input  wire        in_valid,
  input  wire [31:0] multiplicand,
  input  wire [31:0] multiplier,
  output wire        out_valid,
  output wire [63:0] product
);
  wire        carry_save_valid;
  wire [68:0] carry_save_sum;
  wire [68:0] carry_save_carry;
  wire [63:0] final_sum;
  reg         input_valid_q;
  reg  [31:0] multiplicand_q;
  reg  [31:0] multiplier_q;

  always @(posedge clk or negedge reset_n) begin
    if (!reset_n)
      input_valid_q <= 1'b0;
    else
      input_valid_q <= in_valid;
  end

  always @(posedge clk) begin
    multiplicand_q <= multiplicand;
    multiplier_q <= multiplier;
  end

  edge_mul32_booth_compressor #(
    .MULT_SUB_FIXED_ZERO(1'b1)
  ) u_compressor (
    .clk          (clk),
    .reset_n      (reset_n),
    .in_valid     (input_valid_q),
    .mult_round   (32'b0),
    .mult_sub     (1'b0),
    .multiplicand ({1'b0, multiplicand_q}),
    .multiplier   ({1'b0, multiplier_q}),
    .result_0     (carry_save_sum),
    .result_1     (carry_save_carry),
    .out_valid    (carry_save_valid)
  );

  edge_add64_carry_select16 u_final_cpa (
    .clk       (clk),
    .reset_n   (reset_n),
    .in_valid  (carry_save_valid),
    .lhs       (carry_save_sum[63:0]),
    .rhs       (carry_save_carry[63:0]),
    .out_valid (out_valid),
    .sum       (final_sum)
  );
  assign product = final_sum;
endmodule
