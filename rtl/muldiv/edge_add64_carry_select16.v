// SPDX-License-Identifier: Apache-2.0
// Four 16-bit adders with precomputed carries.  This bounds the CPA path to
// one 16-bit carry chain plus three 2:1 selections instead of a 64-bit chain.
(* keep_hierarchy = "yes" *)
module edge_add64_carry_select16 (
  input  wire        clk,
  input  wire        reset_n,
  input  wire        in_valid,
  input  wire [63:0] lhs,
  input  wire [63:0] rhs,
  output reg         out_valid,
  output reg  [63:0] sum
);
  wire [16:0] chunk0;
  wire [16:0] chunk1_c0;
  wire [16:0] chunk1_c1;
  wire [16:0] chunk2_c0;
  wire [16:0] chunk2_c1;
  wire [16:0] chunk3_c0;
  wire [16:0] chunk3_c1;
  reg  [16:0] chunk0_q;
  reg  [16:0] chunk1_c0_q;
  reg  [16:0] chunk1_c1_q;
  reg  [16:0] chunk2_c0_q;
  reg  [16:0] chunk2_c1_q;
  reg  [16:0] chunk3_c0_q;
  reg  [16:0] chunk3_c1_q;
  reg         candidates_valid_q;
  wire [16:0] chunk1_selected;
  wire [16:0] chunk2_selected;
  wire [16:0] chunk3_selected;

  edge_add16_carry_select8 u_chunk0 (
    .lhs(lhs[15:0]), .rhs(rhs[15:0]), .carry_in(1'b0), .sum(chunk0));
  edge_add16_carry_select8 u_chunk1_c0 (
    .lhs(lhs[31:16]), .rhs(rhs[31:16]), .carry_in(1'b0), .sum(chunk1_c0));
  edge_add16_carry_select8 u_chunk1_c1 (
    .lhs(lhs[31:16]), .rhs(rhs[31:16]), .carry_in(1'b1), .sum(chunk1_c1));
  edge_add16_carry_select8 u_chunk2_c0 (
    .lhs(lhs[47:32]), .rhs(rhs[47:32]), .carry_in(1'b0), .sum(chunk2_c0));
  edge_add16_carry_select8 u_chunk2_c1 (
    .lhs(lhs[47:32]), .rhs(rhs[47:32]), .carry_in(1'b1), .sum(chunk2_c1));
  edge_add16_carry_select8 u_chunk3_c0 (
    .lhs(lhs[63:48]), .rhs(rhs[63:48]), .carry_in(1'b0), .sum(chunk3_c0));
  edge_add16_carry_select8 u_chunk3_c1 (
    .lhs(lhs[63:48]), .rhs(rhs[63:48]), .carry_in(1'b1), .sum(chunk3_c1));

  assign chunk1_selected = chunk0_q[16] ? chunk1_c1_q : chunk1_c0_q;
  assign chunk2_selected = chunk1_selected[16] ? chunk2_c1_q : chunk2_c0_q;
  assign chunk3_selected = chunk2_selected[16] ? chunk3_c1_q : chunk3_c0_q;

  // Stage 1: seven independent 16-bit candidate additions.
  always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      candidates_valid_q <= 1'b0;
    end else begin
      candidates_valid_q <= in_valid;
    end
  end

  always @(posedge clk) begin
    chunk0_q <= chunk0;
    chunk1_c0_q <= chunk1_c0;
    chunk1_c1_q <= chunk1_c1;
    chunk2_c0_q <= chunk2_c0;
    chunk2_c1_q <= chunk2_c1;
    chunk3_c0_q <= chunk3_c0;
    chunk3_c1_q <= chunk3_c1;
  end

  // Stage 2: only the carry-selection mux chain reaches the result register.
  always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      out_valid <= 1'b0;
    end else begin
      out_valid <= candidates_valid_q;
    end
  end


  always @(posedge clk) begin
    sum <= {chunk3_selected[15:0], chunk2_selected[15:0],
            chunk1_selected[15:0], chunk0_q[15:0]};
  end
endmodule
