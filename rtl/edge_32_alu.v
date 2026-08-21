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

  wire signed [31:0] src0_signed = fast_issue_src0_value;
  wire signed [31:0] src1_signed = fast_issue_src1_value;
  wire signed [31:0] imm_signed = fast_issue_imm;

  always @* begin
    fast_result = 32'd0;
    case (fast_issue_op)
      ALU_OP_LUI: fast_result = fast_issue_imm;
      ALU_OP_AUIPC: fast_result = fast_issue_pc[31:0] + fast_issue_imm;
      ALU_OP_JAL,
      ALU_OP_JALR: fast_result = fast_issue_pc[31:0] + 32'd4;
      ALU_OP_OP_IMM: begin
        case (fast_issue_funct3)
          3'b000: fast_result = fast_issue_src0_value + fast_issue_imm;
          3'b001: fast_result = fast_issue_src0_value << fast_issue_shamt;
          3'b010: fast_result = src0_signed < imm_signed ? 32'd1 : 32'd0;
          3'b011: fast_result = fast_issue_src0_value < fast_issue_imm ?
                               32'd1 : 32'd0;
          3'b100: fast_result = fast_issue_src0_value ^ fast_issue_imm;
          3'b101: fast_result = fast_issue_funct7_bit5 ?
                               $unsigned(src0_signed >>> fast_issue_shamt) :
                               fast_issue_src0_value >> fast_issue_shamt;
          3'b110: fast_result = fast_issue_src0_value | fast_issue_imm;
          3'b111: fast_result = fast_issue_src0_value & fast_issue_imm;
          default: fast_result = 32'd0;
        endcase
      end
      ALU_OP_OP: begin
        if (!fast_issue_funct7_is_m) begin
          case (fast_issue_funct3)
            3'b000: fast_result = fast_issue_funct7_bit5 ?
                                 fast_issue_src0_value-fast_issue_src1_value :
                                 fast_issue_src0_value+fast_issue_src1_value;
            3'b001: fast_result = fast_issue_src0_value <<
                                 fast_issue_src1_value[4:0];
            3'b010: fast_result = src0_signed < src1_signed ? 32'd1 : 32'd0;
            3'b011: fast_result = fast_issue_src0_value < fast_issue_src1_value ?
                                 32'd1 : 32'd0;
            3'b100: fast_result = fast_issue_src0_value ^ fast_issue_src1_value;
            3'b101: fast_result = fast_issue_funct7_bit5 ?
                                 $unsigned(src0_signed >>> fast_issue_src1_value[4:0]) :
                                 fast_issue_src0_value >> fast_issue_src1_value[4:0];
            3'b110: fast_result = fast_issue_src0_value | fast_issue_src1_value;
            3'b111: fast_result = fast_issue_src0_value & fast_issue_src1_value;
            default: fast_result = 32'd0;
          endcase
        end
      end
      ALU_OP_ZBA: begin
        case (fast_issue_funct3)
          3'b010: fast_result = fast_issue_src1_value+
                               (fast_issue_src0_value << 1);
          3'b100: fast_result = fast_issue_src1_value+
                               (fast_issue_src0_value << 2);
          3'b110: fast_result = fast_issue_src1_value+
                               (fast_issue_src0_value << 3);
          default: fast_result = 32'd0;
        endcase
      end
      default: fast_result = 32'd0;
    endcase
  end
endmodule

`endif
