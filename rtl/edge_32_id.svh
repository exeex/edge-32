// ID stage source entry. Included once by edge_32_core.
// Stage-owned signals and boundary payload.
  wire id_error;
  wire [31:0] id_inst;
  wire id_capture_enable;
  wire [31:0] id_fpu_control;
  wire [31:0] id_rs1_value, id_rs2_value, gpr_debug_x31;
  wire rv32::issue_control_t id_issue_control;
  wire [31:0] id_alu_imm, id_mem_imm, id_branch_imm, id_jump_imm;
  wire id_issue_legal;
  wire [1:0] id_uses_gpr;

`include "id/decode.svh"
`include "id/dependencies.svh"
`include "id/register_file.svh"
`include "id/pipeline_boundary.svh"
