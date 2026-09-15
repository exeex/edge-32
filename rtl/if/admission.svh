// Included in edge_32_core; preserves the existing hardware hierarchy.
  edge_32_register_decode #(.ENABLE_FPU(ENABLE_FPU),
    .UNMASKED_GPR_READ(1)) if_register_decode(
    .inst(if_inst),
    .read_gpr0(if_rs1),.read_gpr1(if_rs2),
    .read_fpr0(if_frs0),.read_fpr1(if_frs1),.read_fpr2(if_frs2),
    .uses_gpr(),.uses_fpr(if_uses_fpr),
    .write_rd(if_write_rd),.rd_gpr(if_rd_gpr),.rd_fpr(if_rd_fpr),
    .csr_write(if_csr_write));
  always @(posedge clk) begin
    if(if_valid && if_ready) begin
      {id_rs1,id_rs2,id_frs0,id_frs1,id_frs2,id_write_rd} <=
        {if_rs1,if_rs2,if_frs0,if_frs1,if_frs2,if_write_rd};
      {id_uses_fpr,id_rd_gpr,id_rd_fpr,id_csr_write} <=
        {if_uses_fpr,if_rd_gpr,if_rd_fpr,if_csr_write};
      id_decoded_class<=if_decoded_class; id_decoded_legal<=if_decoded_legal;
    end
  end
