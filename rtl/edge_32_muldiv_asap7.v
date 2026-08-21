`timescale 1ns/1ps

// ASAP7-oriented RV32M multiplier.  The unsigned Booth lane is shared with
// edge-rv-lite; signed high-half operations are reduced to magnitude multiply
// followed by a 64-bit two's-complement correction.
(* keep_hierarchy = "yes" *)
module edge_32_mul_asap7 (
  input wire clk, input wire reset_n,
  input wire op_valid, output wire op_ready,
  input wire [31:0] src0, input wire [31:0] src1,
  input wire [2:0] funct3,
  output wire result_valid, output wire [31:0] result_value,
  output wire busy, output wire [6:0] op_latency
);
  wire high_result = funct3 != 3'b000;
  wire lhs_signed = (funct3 == 3'b001) || (funct3 == 3'b010);
  wire rhs_signed = funct3 == 3'b001;
  wire lhs_negative = lhs_signed && src0[31];
  wire rhs_negative = rhs_signed && src1[31];
  wire [31:0] lhs_mag = lhs_negative ? (~src0 + 32'd1) : src0;
  wire [31:0] rhs_mag = rhs_negative ? (~src1 + 32'd1) : src1;
  wire accept = op_valid && op_ready;

  wire lane_valid;
  wire [63:0] magnitude_product;
  reg [5:0] valid_pipe_q;
  reg [5:0] high_pipe_q;
  reg [5:0] negative_pipe_q;
  wire [63:0] signed_product = negative_pipe_q[5] ?
    (~magnitude_product + 64'd1) : magnitude_product;

  edge_mul32_booth_lane booth_lane (
    .clk(clk), .reset_n(reset_n), .in_valid(accept),
    .multiplicand(lhs_mag), .multiplier(rhs_mag),
    .out_valid(lane_valid), .product(magnitude_product)
  );

  assign op_ready = !busy;
  assign busy = |valid_pipe_q;
  assign result_valid = lane_valid && valid_pipe_q[5];
  assign result_value = high_pipe_q[5] ? signed_product[63:32] :
                                              signed_product[31:0];
  assign op_latency = 7'd6;

  always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      valid_pipe_q <= 6'd0;
      high_pipe_q <= 6'd0;
      negative_pipe_q <= 6'd0;
    end else begin
      valid_pipe_q <= {valid_pipe_q[4:0], accept};
      high_pipe_q <= {high_pipe_q[4:0], accept && high_result};
      negative_pipe_q <= {negative_pipe_q[4:0],
                          accept && (lhs_negative ^ rhs_negative)};
    end
  end
endmodule

// One native RV32 radix-4 restoring slice.  The 35-bit remainder includes
// three guard bits; no RV64-width arithmetic exists in this datapath.
(* keep_hierarchy = "yes" *)
module edge_32_div_radix4_slice (
  input wire [34:0] remainder_in,
  input wire [31:0] dividend_in,
  input wire [31:0] divisor,
  input wire [31:0] quotient_in,
  output wire [34:0] remainder_out,
  output wire [31:0] dividend_out,
  output wire [31:0] quotient_out
);
  wire [34:0] trial = {remainder_in[32:0], dividend_in[31:30]};
  wire [34:0] divisor_x1 = {3'd0, divisor};
  wire [34:0] divisor_x2 = {2'd0, divisor, 1'b0};
  wire [34:0] divisor_x3 = divisor_x1 + divisor_x2;
  wire [1:0] digit = (trial >= divisor_x3) ? 2'd3 :
                     (trial >= divisor_x2) ? 2'd2 :
                     (trial >= divisor_x1) ? 2'd1 : 2'd0;
  wire [34:0] subtract_value = digit[1] ?
    (digit[0] ? divisor_x3 : divisor_x2) :
    (digit[0] ? divisor_x1 : 35'd0);

  assign remainder_out = trial - subtract_value;
  assign dividend_out = {dividend_in[29:0], 2'b00};
  assign quotient_out = {quotient_in[29:0], digit};
endmodule

// Native RV32 divider with a two-stage radix-4 ring.  A 35-bit register
// boundary separates the slices, so every timing path crosses only one digit
// selection/subtract stage.  A normal operation completes in sixteen cycles.
(* keep_hierarchy = "yes" *)
module edge_32_div_asap7 (
  input wire clk, input wire reset_n,
  input wire op_valid, output wire op_ready,
  input wire [31:0] src0, input wire [31:0] src1,
  input wire [2:0] funct3,
  output wire result_valid, output wire [31:0] result_value,
  output wire busy, output wire [6:0] op_latency
);
  wire signed_operation = !funct3[0];
  wire remainder_operation = funct3[1];
  wire lhs_negative = signed_operation && src0[31];
  wire rhs_negative = signed_operation && src1[31];
  wire [31:0] lhs_magnitude = lhs_negative ? (~src0 + 32'd1) : src0;
  wire [31:0] rhs_magnitude = rhs_negative ? (~src1 + 32'd1) : src1;
  wire divide_by_zero = src1 == 32'd0;
  wire signed_overflow = signed_operation &&
    (src0 == 32'h8000_0000) && (src1 == 32'hffff_ffff);
  wire fast_case = divide_by_zero || signed_overflow;
  wire accept = op_valid && op_ready;

  reg busy_q;
  reg [3:0] cycles_q;
  reg [34:0] remainder_q;
  reg [31:0] dividend_q;
  reg [31:0] divisor_q;
  reg [31:0] quotient_q;
  reg phase_q;
  reg [34:0] stage1_remainder_q;
  reg [31:0] stage1_dividend_q;
  reg [31:0] stage1_quotient_q;
  reg quotient_negative_q;
  reg remainder_negative_q;
  reg remainder_operation_q;
  reg result_valid_q;
  reg [31:0] result_value_q;

  wire [34:0] slice0_remainder;
  wire [31:0] slice0_dividend;
  wire [31:0] slice0_quotient;
  wire [34:0] slice1_remainder;
  wire [31:0] slice1_dividend;
  wire [31:0] slice1_quotient;
  edge_32_div_radix4_slice slice0 (
    .remainder_in(remainder_q), .dividend_in(dividend_q),
    .divisor(divisor_q), .quotient_in(quotient_q),
    .remainder_out(slice0_remainder), .dividend_out(slice0_dividend),
    .quotient_out(slice0_quotient)
  );
  edge_32_div_radix4_slice slice1 (
    .remainder_in(stage1_remainder_q),
    .dividend_in(stage1_dividend_q),
    .divisor(divisor_q), .quotient_in(stage1_quotient_q),
    .remainder_out(slice1_remainder), .dividend_out(slice1_dividend),
    .quotient_out(slice1_quotient)
  );

  wire [31:0] quotient_signed = quotient_negative_q ?
    (~slice1_quotient + 32'd1) : slice1_quotient;
  wire [31:0] remainder_unsigned = slice1_remainder[31:0];
  wire [31:0] remainder_signed = remainder_negative_q ?
    (~remainder_unsigned + 32'd1) : remainder_unsigned;

  assign op_ready = !busy_q && !result_valid_q;
  assign busy = busy_q || result_valid_q;
  assign result_valid = result_valid_q;
  assign result_value = result_value_q;
  assign op_latency = fast_case ? 7'd1 : 7'd16;

  always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      busy_q <= 1'b0;
      cycles_q <= 4'd0;
      remainder_q <= 35'd0;
      dividend_q <= 32'd0;
      divisor_q <= 32'd0;
      quotient_q <= 32'd0;
      phase_q <= 1'b0;
      stage1_remainder_q <= 35'd0;
      stage1_dividend_q <= 32'd0;
      stage1_quotient_q <= 32'd0;
      quotient_negative_q <= 1'b0;
      remainder_negative_q <= 1'b0;
      remainder_operation_q <= 1'b0;
      result_valid_q <= 1'b0;
      result_value_q <= 32'd0;
    end else begin
      result_valid_q <= 1'b0;
      if (busy_q) begin
        if (!phase_q) begin
          stage1_remainder_q <= slice0_remainder;
          stage1_dividend_q <= slice0_dividend;
          stage1_quotient_q <= slice0_quotient;
          phase_q <= 1'b1;
        end else begin
          phase_q <= 1'b0;
          remainder_q <= slice1_remainder;
          dividend_q <= slice1_dividend;
          quotient_q <= slice1_quotient;
          if (cycles_q == 4'd1) begin
            busy_q <= 1'b0;
            cycles_q <= 4'd0;
            result_valid_q <= 1'b1;
            result_value_q <= remainder_operation_q ?
              remainder_signed : quotient_signed;
          end else begin
            cycles_q <= cycles_q - 4'd1;
          end
        end
      end
      if (accept) begin
        if (divide_by_zero) begin
          result_valid_q <= 1'b1;
          result_value_q <= remainder_operation ? src0 : 32'hffff_ffff;
        end else if (signed_overflow) begin
          result_valid_q <= 1'b1;
          result_value_q <= remainder_operation ? 32'd0 : 32'h8000_0000;
        end else begin
          busy_q <= 1'b1;
          cycles_q <= 4'd8;
          remainder_q <= 35'd0;
          dividend_q <= lhs_magnitude;
          divisor_q <= rhs_magnitude;
          quotient_q <= 32'd0;
          phase_q <= 1'b0;
          quotient_negative_q <= lhs_negative ^ rhs_negative;
          remainder_negative_q <= lhs_negative;
          remainder_operation_q <= remainder_operation;
        end
      end
    end
  end
endmodule

// Drop-in RV32M owner for ASAP7 builds.  Only one operation may be in flight,
// matching the edge-32 scalar pipeline contract.
(* keep_hierarchy = "yes" *)
module edge_32_muldiv_asap7 (
  input wire clk, input wire reset_n,
  input wire op_valid, output wire op_ready,
  input wire [31:0] src0, input wire [31:0] src1,
  input wire [2:0] funct3,
  output wire result_valid, output wire [31:0] result_value,
  output wire busy, output wire [6:0] op_latency
);
  wire select_div = funct3[2];
  wire mul_ready, mul_valid, mul_busy;
  wire [31:0] mul_value;
  wire [6:0] mul_latency;
  wire div_ready, div_valid, div_busy;
  wire [31:0] div_value;
  wire [6:0] div_latency;

  edge_32_mul_asap7 multiply (
    .clk(clk), .reset_n(reset_n),
    .op_valid(op_valid && !select_div && !div_busy), .op_ready(mul_ready),
    .src0(src0), .src1(src1), .funct3(funct3),
    .result_valid(mul_valid), .result_value(mul_value), .busy(mul_busy),
    .op_latency(mul_latency)
  );
  edge_32_div_asap7 divide (
    .clk(clk), .reset_n(reset_n),
    .op_valid(op_valid && select_div && !mul_busy), .op_ready(div_ready),
    .src0(src0), .src1(src1), .funct3(funct3),
    .result_valid(div_valid), .result_value(div_value), .busy(div_busy),
    .op_latency(div_latency)
  );

  assign op_ready = select_div ? (!mul_busy && div_ready) :
                                 (!div_busy && mul_ready);
  assign result_valid = mul_valid || div_valid;
  assign result_value = mul_valid ? mul_value : div_value;
  assign busy = mul_busy || div_busy;
  assign op_latency = select_div ? div_latency : mul_latency;
endmodule
