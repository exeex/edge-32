`timescale 1ns/1ps

// Three capture edges. Only validity owns reset; arithmetic is free to retime.
module edge_32_mul_asap7 (
 input wire clk,reset_n,op_valid, output wire op_ready,
 input wire [31:0] src0,src1, input wire [2:0] funct3,
 output wire result_valid, output wire [31:0] result_value, output wire busy
);
 reg [2:0] is_valid_q;
 reg [2:0] high_q;
 wire [63:0] product;
 wire accept=op_valid && op_ready;
 assign busy=|is_valid_q;
 assign op_ready=!busy;
 assign result_valid=is_valid_q[2];
 assign result_value=high_q[2] ? product[63:32] : product[31:0];
 edge32_mul_pipe3 datapath (
  .clk(clk),
  .a({src0[31] && ((funct3==3'b001)||(funct3==3'b010)),src0}),
  .b({src1[31] && (funct3==3'b001),src1}), .product(product)
 );
 always @(posedge clk or negedge reset_n)
  if(!reset_n) is_valid_q<=3'b0;
  else is_valid_q<={is_valid_q[1:0],accept};
 always @(posedge clk) high_q<={high_q[1:0],funct3!=3'b000};
endmodule

// One portable multiply. ASIC synthesis enables Booth and sequential retiming;
// FPGA tools can infer DSP pipelines. Without retiming the middle stage contains
// the full combinational multiply; the RTL alone does not promise a split tree.
(* keep_hierarchy = "yes" *)
module edge32_mul_pipe3 (
 input wire clk,input wire signed [32:0] a,b,output reg [63:0] product
);
 reg signed [32:0] a_q,b_q;
 reg [63:0] product_q;
 always @(posedge clk) begin
  a_q<=a; b_q<=b;
  product_q<=a_q*b_q;
  product<=product_q;
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
