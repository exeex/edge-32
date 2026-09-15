`timescale 1ns/1ps

// Combinational RV32 branch comparison and control-target calculation.
(* keep_hierarchy = "yes" *)
module edge_32_branch #(
  parameter PC_WIDTH = 32,
  parameter OP_WIDTH = 4
) (
  input  wire [OP_WIDTH-1:0] branch_issue_op,
  input  wire [PC_WIDTH-1:0] branch_issue_pc,
  input  wire [31:0]         branch_issue_src0_value,
  input  wire [31:0]         branch_issue_src1_value,
  input  wire [31:0]         branch_issue_imm,
  input  wire [2:0]          branch_issue_funct3,

  output reg                 branch_taken,
  output wire [PC_WIDTH-1:0] branch_target
);

  localparam [OP_WIDTH-1:0] ALU_OP_JAL  = 4'd6;
  localparam [OP_WIDTH-1:0] ALU_OP_JALR = 4'd7;

  wire signed [31:0] src0_signed = branch_issue_src0_value;
  wire signed [31:0] src1_signed = branch_issue_src1_value;
  reg [31:0] control_target;

  always @* begin
    case (branch_issue_funct3)
      3'b000: branch_taken = branch_issue_src0_value ==
                              branch_issue_src1_value;
      3'b001: branch_taken = branch_issue_src0_value !=
                              branch_issue_src1_value;
      3'b100: branch_taken = src0_signed < src1_signed;
      3'b101: branch_taken = src0_signed >= src1_signed;
      3'b110: branch_taken = branch_issue_src0_value <
                              branch_issue_src1_value;
      3'b111: branch_taken = branch_issue_src0_value >=
                              branch_issue_src1_value;
      default: branch_taken = 1'b0;
    endcase

    if (branch_issue_op == ALU_OP_JAL) begin
      control_target = branch_issue_pc[31:0] + branch_issue_imm;
      branch_taken = 1'b1;
    end else if (branch_issue_op == ALU_OP_JALR) begin
      control_target = (branch_issue_src0_value + branch_issue_imm) &
                       32'hffff_fffe;
      branch_taken = 1'b1;
    end else begin
      control_target = branch_issue_pc[31:0] + branch_issue_imm;
    end
  end

  assign branch_target = {{(PC_WIDTH-32){1'b0}}, control_target};

endmodule
