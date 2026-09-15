`timescale 1ns/1ps

// ASAP7-oriented RV32M multiplier.  The unsigned Booth lane is shared with
// edge-rv-lite; signed high-half operations are reduced to magnitude multiply
// followed by an RV32 high-half two's-complement correction.
(* keep_hierarchy = "yes" *)
module edge_32_mul_asap7 (
  input wire clk, input wire reset_n,
  input wire op_valid, output wire op_ready,
  input wire [31:0] src0, input wire [31:0] src1,
  input wire [2:0] funct3,
  output wire result_valid, output wire [31:0] result_value,
  output wire busy
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
  // For -P, the upper half is ~P[63:32] plus the carry generated when
  // ~P[31:0] is incremented.  That carry is one exactly when P[31:0] is zero.
  // Computing only the architecturally visible half avoids a 64-bit negate.
  wire [31:0] negative_high = ~magnitude_product[63:32] +
                              (magnitude_product[31:0] == 32'd0);
  wire [31:0] multiply_high = negative_pipe_q[5] ? negative_high :
                                                       magnitude_product[63:32];

  edge_mul32_booth_lane booth_lane (
    .clk(clk), .reset_n(reset_n), .in_valid(accept),
    .multiplicand(lhs_mag), .multiplier(rhs_mag),
    .out_valid(lane_valid), .product(magnitude_product)
  );

  assign op_ready = !busy;
  assign busy = |valid_pipe_q;
  // The lane valid is the same six-edge accept shift as valid_pipe_q.
  // Export the local owner directly: completion must not detour through the
  // remote CPA valid/reset cone before returning to pipeline/frontend control.
  assign result_valid = valid_pipe_q[5];
  assign result_value = high_pipe_q[5] ? multiply_high :
                                              magnitude_product[31:0];

  always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      valid_pipe_q <= 6'd0;
    end else begin
      valid_pipe_q <= {valid_pipe_q[4:0], accept};
    end
  end
  // Mode/sign travel beside valid; bubbles and reset invalidate them without
  // resetting or qualifying the numerical result selection pipeline.
  always @(posedge clk) begin
    high_pipe_q <= {high_pipe_q[4:0], high_result};
    negative_pipe_q <= {negative_pipe_q[4:0], lhs_negative ^ rhs_negative};
  end
endmodule

// Native RV32 radix-4 SRT wrapper.  The iterative datapath is 35 bits wide,
// uses two registered ring slices, seven high bits for quotient-digit
// selection, and carry-save partial-remainder feedback.
(* keep_hierarchy = "yes" *)
module edge_32_div_asap7 (
  input wire clk, input wire reset_n,
  input wire op_valid, output wire op_ready,
  input wire [31:0] src0, input wire [31:0] src1,
  input wire [2:0] funct3,
  output wire result_valid, output wire [31:0] result_value,
  output wire busy
);
  edge_32_div_srt4_native srt4 (
    .clk(clk), .reset_n(reset_n), .op_valid(op_valid), .op_ready(op_ready),
    .src0(src0), .src1(src1), .funct3(funct3),
    .result_valid(result_valid), .result_value(result_value),
    .busy(busy)
  );
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
  output wire busy
);
  wire select_div = funct3[2];
  wire mul_ready, mul_valid, mul_busy;
  wire [31:0] mul_value;
  wire div_ready, div_valid, div_busy;
  wire [31:0] div_value;

  edge_32_mul_asap7 multiply (
    .clk(clk), .reset_n(reset_n),
    .op_valid(op_valid && !select_div && !div_busy), .op_ready(mul_ready),
    .src0(src0), .src1(src1), .funct3(funct3),
    .result_valid(mul_valid), .result_value(mul_value), .busy(mul_busy)
  );
  edge_32_div_asap7 divide (
    .clk(clk), .reset_n(reset_n),
    .op_valid(op_valid && select_div && !mul_busy), .op_ready(div_ready),
    .src0(src0), .src1(src1), .funct3(funct3),
    .result_valid(div_valid), .result_value(div_value), .busy(div_busy)
  );

  assign op_ready = select_div ? (!mul_busy && div_ready) :
                                 (!div_busy && mul_ready);
  assign result_valid = mul_valid || div_valid;
  assign result_value = mul_valid ? mul_value : div_value;
  assign busy = mul_busy || div_busy;
endmodule
