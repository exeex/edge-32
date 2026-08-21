`timescale 1ns/1ps

// Simple RV32M unit: inferred-DSP multiply and iterative radix-2 divide.
(* keep_hierarchy = "yes" *)
module edge_32_muldiv (
  input wire clk,
  input wire reset_n,
  input wire op_valid,
  output wire op_ready,
  input wire [31:0] src0,
  input wire [31:0] src1,
  input wire [2:0] funct3,
  output reg result_valid,
  output reg [31:0] result_value,
  output wire busy,
  output wire [6:0] op_latency
);
  wire accept = op_valid && op_ready;
  wire is_divrem = funct3[2];
  wire is_signed_divrem = (funct3 == 3'b100) || (funct3 == 3'b110);
  wire is_remainder = funct3[1];

  // The direct multiply operators are intentional: Yosys may infer target DSPs.
  wire mul_lhs_signed = (funct3 == 3'b001) || (funct3 == 3'b010);
  wire mul_rhs_signed = funct3 == 3'b001;
  wire signed [32:0] multiply_lhs = {mul_lhs_signed && src0[31], src0};
  wire signed [32:0] multiply_rhs = {mul_rhs_signed && src1[31], src1};
  wire signed [65:0] product = multiply_lhs * multiply_rhs;
  reg [31:0] multiply_result;
  always @* begin
    case (funct3)
      3'b000: multiply_result = product[31:0];
      3'b001,
      3'b010,
      3'b011: multiply_result = product[63:32];
      default: multiply_result = 32'd0;
    endcase
  end

  wire src0_negative = is_signed_divrem && src0[31];
  wire src1_negative = is_signed_divrem && src1[31];
  wire [31:0] src0_abs = src0_negative ? (~src0 + 32'd1) : src0;
  wire [31:0] src1_abs = src1_negative ? (~src1 + 32'd1) : src1;
  wire divide_by_zero = src1 == 32'd0;
  wire signed_overflow = is_signed_divrem &&
                         (src0 == 32'h8000_0000) &&
                         (src1 == 32'hffff_ffff);

  reg div_busy_q;
  reg [5:0] count_q;
  reg [31:0] dividend_q;
  reg [31:0] divisor_q;
  reg [31:0] quotient_q;
  reg [32:0] remainder_q;
  reg quotient_negative_q;
  reg remainder_negative_q;
  reg remainder_result_q;

  wire [32:0] shifted_remainder = {remainder_q[31:0], dividend_q[31]};
  wire subtract_valid = shifted_remainder >= {1'b0, divisor_q};
  wire [32:0] next_remainder = subtract_valid ?
    shifted_remainder - {1'b0, divisor_q} : shifted_remainder;
  wire [31:0] next_quotient = {quotient_q[30:0], subtract_valid};
  wire [31:0] next_dividend = {dividend_q[30:0], 1'b0};
  wire [31:0] signed_quotient = quotient_negative_q ?
    (~next_quotient + 32'd1) : next_quotient;
  wire [31:0] unsigned_remainder = next_remainder[31:0];
  wire [31:0] signed_remainder = remainder_negative_q ?
    (~unsigned_remainder + 32'd1) : unsigned_remainder;

  assign op_ready = !div_busy_q;
  assign busy = div_busy_q;
  assign op_latency = is_divrem ?
    ((divide_by_zero || signed_overflow) ? 7'd1 : 7'd32) : 7'd1;

  always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      result_valid <= 1'b0;
      result_value <= 32'd0;
      div_busy_q <= 1'b0;
      count_q <= 6'd0;
      dividend_q <= 32'd0;
      divisor_q <= 32'd0;
      quotient_q <= 32'd0;
      remainder_q <= 33'd0;
      quotient_negative_q <= 1'b0;
      remainder_negative_q <= 1'b0;
      remainder_result_q <= 1'b0;
    end else begin
      result_valid <= 1'b0;

      if (div_busy_q) begin
        dividend_q <= next_dividend;
        quotient_q <= next_quotient;
        remainder_q <= next_remainder;
        if (count_q == 6'd1) begin
          div_busy_q <= 1'b0;
          count_q <= 6'd0;
          result_valid <= 1'b1;
          result_value <= remainder_result_q ?
                          signed_remainder : signed_quotient;
        end else begin
          count_q <= count_q - 6'd1;
        end
      end

      if (accept) begin
        if (!is_divrem) begin
          result_valid <= 1'b1;
          result_value <= multiply_result;
        end else if (divide_by_zero) begin
          result_valid <= 1'b1;
          result_value <= is_remainder ? src0 : 32'hffff_ffff;
        end else if (signed_overflow) begin
          result_valid <= 1'b1;
          result_value <= is_remainder ? 32'd0 : 32'h8000_0000;
        end else begin
          div_busy_q <= 1'b1;
          count_q <= 6'd32;
          dividend_q <= src0_abs;
          divisor_q <= src1_abs;
          quotient_q <= 32'd0;
          remainder_q <= 33'd0;
          quotient_negative_q <= src0_negative ^ src1_negative;
          remainder_negative_q <= src0_negative;
          remainder_result_q <= is_remainder;
        end
      end
    end
  end
endmodule
