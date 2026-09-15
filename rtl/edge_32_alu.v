`ifndef EDGE_32_ALU_V
`define EDGE_32_ALU_V
`timescale 1ns/1ps

// Combinational RV32I/Zba fast integer datapath. Legality is owned by decode.
(* keep_hierarchy = "yes" *)
module edge_32_alu #(
  parameter PC_WIDTH = 32,
  parameter OP_WIDTH = 4
) (
  input  wire [OP_WIDTH-1:0] fast_issue_op,
  input  wire [PC_WIDTH-1:0] fast_issue_pc,
  input  wire [31:0] fast_issue_src0_value,
  input  wire [31:0] fast_issue_src1_value,
  input  wire [31:0] fast_issue_imm,
  input  wire [2:0] fast_issue_funct3,
  input  wire fast_issue_funct7_bit5,
  input  wire fast_issue_funct7_is_m,
  input  wire [4:0] fast_issue_shamt,
  output wire [31:0] fast_result,
  output reg [31:0] simple_result, complex_result,
  output wire simple_select
);
  localparam [OP_WIDTH-1:0] ALU_OP_OP_IMM = 4'd0;
  localparam [OP_WIDTH-1:0] ALU_OP_OP      = 4'd1;
  localparam [OP_WIDTH-1:0] ALU_OP_LUI     = 4'd4;
  localparam [OP_WIDTH-1:0] ALU_OP_AUIPC   = 4'd5;
  localparam [OP_WIDTH-1:0] ALU_OP_JAL     = 4'd6;
  localparam [OP_WIDTH-1:0] ALU_OP_JALR    = 4'd7;
  localparam [OP_WIDTH-1:0] ALU_OP_ZBA     = 4'd9;

  wire op_imm = fast_issue_op == ALU_OP_OP_IMM;
  wire op_reg = fast_issue_op == ALU_OP_OP;
  wire op_zba = fast_issue_op == ALU_OP_ZBA;
  wire op_pc = fast_issue_op == ALU_OP_AUIPC ||
               fast_issue_op == ALU_OP_JAL || fast_issue_op == ALU_OP_JALR;
  wire op_link = fast_issue_op == ALU_OP_JAL || fast_issue_op == ALU_OP_JALR;
  wire [31:0] rhs = op_imm ? fast_issue_imm : fast_issue_src1_value;
  wire [4:0] shift_amount = op_imm ? fast_issue_shamt : fast_issue_src1_value[4:0];

  // Fast add has no Zba shift or subtraction control in its operand cone.
  wire [31:0] simple_lhs = op_pc ? fast_issue_pc[31:0] : fast_issue_src0_value;
  wire [31:0] simple_rhs = op_link ? 32'd4 : op_pc ? fast_issue_imm : rhs;
  wire [31:0] simple_add, complex_add;
  wire [31:0] zba_lhs = fast_issue_funct3 == 3'b010 ? fast_issue_src0_value << 1 :
                        fast_issue_funct3 == 3'b100 ? fast_issue_src0_value << 2 :
                                                    fast_issue_src0_value << 3;
  wire subtract = op_reg && fast_issue_funct7_bit5;
  edge32_alu_add32 fast_adder(.a(simple_lhs),.b(simple_rhs),.cin(1'b0),.sum(simple_add));
  edge32_alu_add32 complex_adder(
    .a(op_zba ? zba_lhs : fast_issue_src0_value),
    .b(rhs ^ {32{subtract}}),.cin(subtract),.sum(complex_add));
  wire integer_op = op_imm || (op_reg && !fast_issue_funct7_is_m);
  assign simple_select = (fast_issue_op == ALU_OP_LUI) || op_pc ||
    (integer_op && ((fast_issue_funct3 == 3'b000 && !subtract) ||
                    fast_issue_funct3 == 3'b100 || fast_issue_funct3 == 3'b110 ||
                    fast_issue_funct3 == 3'b111));
  // Compatibility output for local combinational clients. The core captures
  // the separate outputs, and performs this selection after the WB registers.
  assign fast_result = simple_select ? simple_result : complex_result;

  // Signed and unsigned comparisons share the magnitude comparison.
  wire less_unsigned = fast_issue_src0_value < rhs;
  wire less_signed = (fast_issue_src0_value[31] ^ rhs[31]) ?
                      fast_issue_src0_value[31] : less_unsigned;

  // Reverse bits for left shifts so all shifts use one right barrel shifter.
  wire shift_left = fast_issue_funct3 == 3'b001;
  wire [31:0] shift_input, shifted, shift_result;
  wire shift_sign = !shift_left && fast_issue_funct7_bit5 && fast_issue_src0_value[31];
  wire signed [32:0] shift_extended = {shift_sign, shift_input};
  wire signed [32:0] shifted_extended = shift_extended >>> shift_amount;
  assign shifted = shifted_extended[31:0];
  genvar bit_index;
  generate for (bit_index=0; bit_index<32; bit_index=bit_index+1) begin: g_shift
    assign shift_input[bit_index] = shift_left ? fast_issue_src0_value[31-bit_index] :
                                               fast_issue_src0_value[bit_index];
    assign shift_result[bit_index] = shift_left ? shifted[31-bit_index] : shifted[bit_index];
  end endgenerate

  always @* begin
    simple_result = 32'd0;
    complex_result = 32'd0;
    case (fast_issue_op)
      ALU_OP_LUI: simple_result = fast_issue_imm;
      ALU_OP_AUIPC, ALU_OP_JAL, ALU_OP_JALR: simple_result = simple_add;
      ALU_OP_OP_IMM, ALU_OP_OP: begin
        if (integer_op) begin
          case (fast_issue_funct3)
            3'b000: begin
              simple_result = simple_add;
              complex_result = complex_add;
            end
            3'b001, 3'b101: complex_result = shift_result;
            3'b010: complex_result = {31'd0, less_signed};
            3'b011: complex_result = {31'd0, less_unsigned};
            3'b100: simple_result = fast_issue_src0_value ^ rhs;
            3'b110: simple_result = fast_issue_src0_value | rhs;
            3'b111: simple_result = fast_issue_src0_value & rhs;
            default: begin end
          endcase
        end
      end
      ALU_OP_ZBA: begin
        case (fast_issue_funct3)
          3'b010, 3'b100, 3'b110: complex_result = complex_add;
          default: begin end
        endcase
      end
      default: begin end
    endcase
  end
endmodule

// Four local 8-bit candidate additions and a parallel group carry network.
// Bound carry propagation instead of relying on a mapped 32-bit ripple chain.
module edge32_alu_add32 (
  input wire [31:0] a,b, input wire cin, output wire [31:0] sum
);
  wire [3:0] g,p;
  wire [3:0] carry;
  assign carry[0] = cin;
  assign carry[1] = g[0] | (p[0]&cin);
  assign carry[2] = g[1] | (p[1]&g[0]) | (p[1]&p[0]&cin);
  assign carry[3] = g[2] | (p[2]&g[1]) | (p[2]&p[1]&g[0]) | (p[2]&p[1]&p[0]&cin);
  genvar i;
  generate for (i=0;i<4;i=i+1) begin: chunk
    wire [8:0] zero_sum = {1'b0,a[8*i+:8]} + {1'b0,b[8*i+:8]};
    wire [7:0] one_sum = a[8*i+:8] + b[8*i+:8] + 8'd1;
    assign g[i] = zero_sum[8];
    assign p[i] = &(a[8*i+:8] ^ b[8*i+:8]);
    assign sum[8*i+:8] = carry[i] ? one_sum : zero_sum[7:0];
  end endgenerate
endmodule
`endif
