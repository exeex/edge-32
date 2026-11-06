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

  // Flip the sign bit before comparing for BLT/BGE. This shares one
  // unsigned tree without a late signed-result mux on the IF feedback path.
  wire signed_compare = !branch_issue_funct3[1];
  wire [31:0] compare_a = {branch_issue_src0_value[31] ^ signed_compare,
                          branch_issue_src0_value[30:0]};
  wire [31:0] compare_b = {branch_issue_src1_value[31] ^ signed_compare,
                          branch_issue_src1_value[30:0]};
  wire [7:0] group_equal, group_less;
  genvar group_index;
  generate for (group_index=0; group_index<8; group_index=group_index+1) begin: compare_group
    assign group_equal[group_index] =
      compare_a[4*group_index+:4] == compare_b[4*group_index+:4];
    assign group_less[group_index] =
      compare_a[4*group_index+:4] < compare_b[4*group_index+:4];
  end endgenerate
  wire operands_equal = &group_equal;
  wire lower_less = group_less[3] |
    (group_equal[3] & group_less[2]) |
    (group_equal[3] & group_equal[2] & group_less[1]) |
    (group_equal[3] & group_equal[2] & group_equal[1] & group_less[0]);
  wire upper_less = group_less[7] |
    (group_equal[7] & group_less[6]) |
    (group_equal[7] & group_equal[6] & group_less[5]) |
    (group_equal[7] & group_equal[6] & group_equal[5] & group_less[4]);
  wire operands_less = upper_less | ((&group_equal[7:4]) & lower_less);
  reg [31:0] control_target;

  // Same four-byte carry-select structure as edge32_alu_add32, kept local
  // so the branch leaf remains independently compilable. No added cycle.
  function [31:0] target_add32;
    input [31:0] a, b;
    reg [3:0] g, p, carry;
    reg [31:0] zero_sum, one_sum;
    reg [8:0] chunk_sum;
    integer i;
    begin
      for (i=0; i<4; i=i+1) begin
        chunk_sum = {1'b0,a[8*i+:8]} + {1'b0,b[8*i+:8]};
        zero_sum[8*i+:8] = chunk_sum[7:0];
        one_sum[8*i+:8] = a[8*i+:8] + b[8*i+:8] + 8'd1;
        g[i] = chunk_sum[8];
        p[i] = &(a[8*i+:8] ^ b[8*i+:8]);
      end
      carry[0] = 1'b0;
      carry[1] = g[0];
      carry[2] = g[1] | (p[1]&g[0]);
      carry[3] = g[2] | (p[2]&g[1]) | (p[2]&p[1]&g[0]);
      for (i=0; i<4; i=i+1)
        target_add32[8*i+:8] = carry[i] ? one_sum[8*i+:8] : zero_sum[8*i+:8];
    end
  endfunction

  always @* begin
    branch_taken = branch_issue_funct3[2] ?
      (operands_less ^ branch_issue_funct3[0]) :
      (!branch_issue_funct3[1] && (operands_equal ^ branch_issue_funct3[0]));

    if (branch_issue_op == ALU_OP_JAL) begin
      control_target = target_add32(branch_issue_pc[31:0], branch_issue_imm);
      branch_taken = 1'b1;
    end else if (branch_issue_op == ALU_OP_JALR) begin
      control_target = target_add32(branch_issue_src0_value, branch_issue_imm) &
                       32'hffff_fffe;
      branch_taken = 1'b1;
    end else begin
      control_target = target_add32(branch_issue_pc[31:0], branch_issue_imm);
    end
  end

  assign branch_target = {{(PC_WIDTH-32){1'b0}}, control_target};

endmodule
