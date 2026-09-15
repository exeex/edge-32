// Implementation owned by this stage module.
  edge_32_register_decode #(.ENABLE_FPU(ENABLE_FPU),
    .UNMASKED_GPR_READ(1)) if_register_decode(
    .inst(if_inst),
    .read_gpr0(if_rs1),.read_gpr1(if_rs2),
    .read_fpr0(if_frs0),.read_fpr1(if_frs1),.read_fpr2(if_frs2),
    .uses_gpr(),.uses_fpr(if_uses_fpr),
    .write_rd(if_write_rd),.rd_gpr(if_rd_gpr),.rd_fpr(if_rd_fpr),
    .csr_write(if_csr_write));
