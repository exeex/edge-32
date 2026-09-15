`timescale 1ns/1ps

// Six parallel 10/11/11 by 16/16 products. The top chunks carry the selected
// signedness directly; no input magnitude or output negate is needed.
(* keep_hierarchy = "yes" *)
module edge_32_mul_asap7 (
  input wire clk, input wire reset_n,
  input wire op_valid, output wire op_ready,
  input wire [31:0] src0, input wire [31:0] src1,
  input wire [2:0] funct3,
  output wire result_valid, output wire [31:0] result_value,
  output wire busy
);
  wire accept = op_valid && op_ready;
  wire lhs_signed = (funct3 == 3'b001) || (funct3 == 3'b010);
  wire rhs_signed = funct3 == 3'b001;
  wire lane_valid;
  wire [63:0] product;
  reg [5:0] valid_pipe_q;
  reg [5:0] high_pipe_q;

  edge32_mul3x2_tree tree_lane (
    .clk(clk), .reset_n(reset_n), .in_valid(accept),
    .src0(src0), .src1(src1),
    .lhs_signed(lhs_signed), .rhs_signed(rhs_signed),
    .out_valid(lane_valid), .product(product)
  );
  assign op_ready = !busy;
  assign busy = |valid_pipe_q;
  assign result_valid = valid_pipe_q[5];
  assign result_value = high_pipe_q[5] ? product[63:32] : product[31:0];
  always @(posedge clk or negedge reset_n) begin
    if (!reset_n) valid_pipe_q <= 6'd0;
    else valid_pipe_q <= {valid_pipe_q[4:0],accept};
  end
  always @(posedge clk)
    high_pipe_q <= {high_pipe_q[4:0],funct3 != 3'b000};
endmodule

// X={A,B,C} (10/11/11), Y={H,L} (16/16).
// Only A and H carry the instruction-selected sign; all lower chunks are
// nonnegative. Two three-product rows are summed in parallel, then combined.
// Six edges: inputs, products, BC rows, ABC rows, full sum, output.
(* keep_hierarchy = "yes" *)
module edge32_mul3x2_tree (
  input wire clk, input wire reset_n, input wire in_valid,
  input wire [31:0] src0, input wire [31:0] src1,
  input wire lhs_signed, input wire rhs_signed,
  output wire out_valid, output reg [63:0] product
);
  reg signed [10:0] a_q;
  reg signed [11:0] b_q, c_q;
  reg signed [16:0] h_q, l_q;
  reg signed [28:0] al_q, bl_q, cl_q, ah_q, bh_q, ch_q;
  reg signed [28:0] al_delay_q, ah_delay_q;
  reg signed [38:0] bc_l_q, bc_h_q;
  reg signed [48:0] row_l_q, row_h_q;
  reg [63:0] sum_q;
  reg [5:0] valid_q;
  assign out_valid = valid_q[5];
  always @(posedge clk or negedge reset_n) begin
    if (!reset_n) valid_q <= 6'd0;
    else valid_q <= {valid_q[4:0],in_valid};
  end
  always @(posedge clk) begin
    a_q <= {lhs_signed & src0[31],src0[31:22]};
    b_q <= {1'b0,src0[21:11]};
    c_q <= {1'b0,src0[10:0]};
    h_q <= {rhs_signed & src1[31],src1[31:16]};
    l_q <= {1'b0,src1[15:0]};
    al_q <= a_q * l_q;
    bl_q <= b_q * l_q;
    cl_q <= c_q * l_q;
    ah_q <= a_q * h_q;
    bh_q <= b_q * h_q;
    ch_q <= c_q * h_q;
    bc_l_q <= {{10{cl_q[28]}},cl_q} + ({{10{bl_q[28]}},bl_q} << 11);
    bc_h_q <= {{10{ch_q[28]}},ch_q} + ({{10{bh_q[28]}},bh_q} << 11);
    al_delay_q <= al_q;
    ah_delay_q <= ah_q;
    row_l_q <= {{10{bc_l_q[38]}},bc_l_q} + ({{20{al_delay_q[28]}},al_delay_q} << 22);
    row_h_q <= {{10{bc_h_q[38]}},bc_h_q} + ({{20{ah_delay_q[28]}},ah_delay_q} << 22);
    sum_q <= {{15{row_l_q[48]}},row_l_q} + ({{15{row_h_q[48]}},row_h_q} << 16);
    product <= sum_q;
  end
endmodule

// Native RV32 radix-4 nonnegative divider wrapper.
(* keep_hierarchy = "yes" *)
module edge_32_div_asap7 (
  input wire clk, input wire reset_n,
  input wire op_valid, output wire op_ready,
  input wire [31:0] src0, input wire [31:0] src1,
  input wire [2:0] funct3,
  output wire result_valid, output wire [31:0] result_value,
  output wire busy
);
  edge32_div_nonnegative radix4 (
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
