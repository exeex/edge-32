`ifndef EDGE32_EXTERNAL_FPU_SVH
`define EDGE32_EXTERNAL_FPU_SVH
// Cycle-level edge_32_fpu owner interface. The owner shares core clock/reset.
`ifdef EDGE32_LOCAL_FP_WB
`define EDGE32_FPU_WB_PORTS \
  output wire fpu_is_fp_load, \
  output wire [4:0] fpu_ex_fpr_rd,
`define EDGE32_FPU_WB_CONNECT \
  .fpu_is_fp_load(fpu_is_fp_load), \
  .fpu_ex_fpr_rd(fpu_ex_fpr_rd),
`else
`define EDGE32_FPU_WB_PORTS \
  output wire [4:0] fpu_wb_rd_q, \
  output wire [31:0] fpu_wb_value_q,
`define EDGE32_FPU_WB_CONNECT \
  .fpu_wb_rd_q(fpu_wb_rd_q), \
  .fpu_wb_value_q(fpu_wb_value_q),
`endif
`define EDGE32_FPU_PORTS \
  output wire fpu_cancel, \
  output wire fpu_id_capture_enable, \
  output wire [31:0] fpu_id_inst, \
  output wire [4:0] fpu_id_frs0, \
  output wire [4:0] fpu_id_frs1, \
  output wire [4:0] fpu_id_frs2, \
  output wire fpu_ex_issue_ok, \
  output wire fpu_ex_done, \
  output wire fpu_is_fp_compute, \
  output wire fpu_ex_writes_fpr, \
  output wire fpu_is_fp_csr, \
  output wire fpu_csr_fflags, \
  output wire fpu_csr_frm, \
  output wire fpu_csr_write, \
  output wire [2:0] fpu_f3, \
  output wire [4:0] fpu_csr_uimm, \
  output wire [31:0] fpu_ex_rs1_value, \
  output wire [31:0] fpu_lsu_value, \
  output wire fpu_wb_commit, \
  output wire fpu_wb_fault_q, \
  `EDGE32_FPU_WB_PORTS \
  input wire [2:0] fpu_frm, \
  input wire fpu_fp_compute_complete, \
  input wire [31:0] fpu_fpu_value, \
  input wire [31:0] fpu_fp_load_value, \
  input wire [63:0] fpu_fp_store_value, \
  input wire [31:0] fpu_fp_csr_value, \
  input wire fpu_wb_fp_csr_q,
`define EDGE32_FPU_CONNECT \
  .fpu_cancel(fpu_cancel), \
  .fpu_id_capture_enable(fpu_id_capture_enable), \
  .fpu_id_inst(fpu_id_inst), \
  .fpu_id_frs0(fpu_id_frs0), \
  .fpu_id_frs1(fpu_id_frs1), \
  .fpu_id_frs2(fpu_id_frs2), \
  .fpu_ex_issue_ok(fpu_ex_issue_ok), \
  .fpu_ex_done(fpu_ex_done), \
  .fpu_is_fp_compute(fpu_is_fp_compute), \
  .fpu_ex_writes_fpr(fpu_ex_writes_fpr), \
  .fpu_is_fp_csr(fpu_is_fp_csr), \
  .fpu_csr_fflags(fpu_csr_fflags), \
  .fpu_csr_frm(fpu_csr_frm), \
  .fpu_csr_write(fpu_csr_write), \
  .fpu_f3(fpu_f3), \
  .fpu_csr_uimm(fpu_csr_uimm), \
  .fpu_ex_rs1_value(fpu_ex_rs1_value), \
  .fpu_lsu_value(fpu_lsu_value), \
  .fpu_wb_commit(fpu_wb_commit), \
  .fpu_wb_fault_q(fpu_wb_fault_q), \
  `EDGE32_FPU_WB_CONNECT \
  .fpu_frm(fpu_frm), \
  .fpu_fp_compute_complete(fpu_fp_compute_complete), \
  .fpu_fpu_value(fpu_fpu_value), \
  .fpu_fp_load_value(fpu_fp_load_value), \
  .fpu_fp_store_value(fpu_fp_store_value), \
  .fpu_fp_csr_value(fpu_fp_csr_value), \
  .fpu_wb_fp_csr_q(fpu_wb_fp_csr_q),
`endif
