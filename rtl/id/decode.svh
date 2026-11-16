// IF owns the candidate read addresses. ID selects the EX payload once;
// the exact same mux controls qualify GPR hazards and EX operand capture.
  wire rv32::operand_select_t id_operand_select;
  assign id_uses_gpr = id_operand_select; // existing two-bit boundary ABI
  edge_32_issue_decode #(.ENABLE_FPU(ENABLE_FPU)) id_issue_decode(
    .inst(id_inst),.op_class(id_decoded_class),.decoded_legal(id_decoded_legal),
    .register_rd(id_write_rd),.rd_gpr(id_rd_gpr),.rd_fpr(id_rd_fpr),
    .fpu_control(id_fpu_control),
    .control(id_issue_control),.operand_select(id_operand_select),.terminal_break(id_terminal_break),.imm(id_imm),
    .writes_gpr(),.writes_fpr(),
    .issue_legal(id_issue_legal));
