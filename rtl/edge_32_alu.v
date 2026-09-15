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
  output reg [31:0] fast_result
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

  // Select operands before arithmetic: OP/OP-IMM, PC-relative and Zba share
  // one add/subtract datapath. Zba's shifts are fixed wiring plus selection.
  wire [31:0] zba_lhs = fast_issue_funct3 == 3'b010 ? fast_issue_src0_value << 1 :
                        fast_issue_funct3 == 3'b100 ? fast_issue_src0_value << 2 :
                                                    fast_issue_src0_value << 3;
  wire [31:0] add_lhs = op_pc ? fast_issue_pc[31:0] :
                       op_zba ? zba_lhs : fast_issue_src0_value;
  wire [31:0] add_rhs = op_link ? 32'd4 :
                       op_pc ? fast_issue_imm : rhs;
  wire subtract = op_reg && fast_issue_funct7_bit5;
  wire [31:0] add_result = add_lhs + (add_rhs ^ {32{subtract}}) + {31'd0, subtract};

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
    fast_result = 32'd0;
    case (fast_issue_op)
      ALU_OP_LUI: fast_result = fast_issue_imm;
      ALU_OP_AUIPC, ALU_OP_JAL, ALU_OP_JALR: fast_result = add_result;
      ALU_OP_OP_IMM, ALU_OP_OP: begin
        if (op_imm || !fast_issue_funct7_is_m) begin
          case (fast_issue_funct3)
            3'b000: fast_result = add_result;
            3'b001, 3'b101: fast_result = shift_result;
            3'b010: fast_result = {31'd0, less_signed};
            3'b011: fast_result = {31'd0, less_unsigned};
            3'b100: fast_result = fast_issue_src0_value ^ rhs;
            3'b110: fast_result = fast_issue_src0_value | rhs;
            3'b111: fast_result = fast_issue_src0_value & rhs;
            default: fast_result = 32'd0;
          endcase
        end
      end
      ALU_OP_ZBA: begin
        case (fast_issue_funct3)
          3'b010, 3'b100, 3'b110: fast_result = add_result;
          default: fast_result = 32'd0;
        endcase
      end
      default: fast_result = 32'd0;
    endcase
  end

endmodule

`endif
