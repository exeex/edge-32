// Implementation owned by this stage module.
  // IF captures candidate indices without source-use decoding. ID decides
  // whether operands participate in hazards and the EX issue packet.
  edge_32_register_decode #(.ENABLE_FPU(ENABLE_FPU)) id_gpr_use_decode(
    .inst(id_inst),.uses_gpr(id_uses_gpr),
    .read_gpr0(),.read_gpr1(),.read_fpr0(),.read_fpr1(),.read_fpr2(),
    .uses_fpr(),.write_rd(),.rd_gpr(),.rd_fpr(),.csr_write());
  edge_32_issue_decode #(.ENABLE_FPU(ENABLE_FPU)) id_issue_decode(
    .inst(id_inst),.op_class(id_decoded_class),.decoded_legal(id_decoded_legal),
    .register_rd(id_write_rd),.rd_gpr(id_rd_gpr),.rd_fpr(id_rd_fpr),
    .fpu_control(id_fpu_control),
    .control(id_issue_control),.terminal_break(id_terminal_break),.imm(id_imm),
    .writes_gpr(),.writes_fpr(),
    .issue_legal(id_issue_legal));
