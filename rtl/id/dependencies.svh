// Included in edge_32_core; preserves the existing hardware hierarchy.
  // A result still in EX cannot bypass the new WB register boundary.
  wire id_gpr_hazard=ex_valid&&ex_writes_gpr&&(rd!=0)&&
    ((id_uses_gpr[0]&&id_rs1==rd)||(id_uses_gpr[1]&&id_rs2==rd));
  wire id_fpr_hazard=ex_valid&&ex_writes_fpr&&
    ((id_uses_fpr[0]&&id_frs0==rd)||(id_uses_fpr[1]&&id_frs1==rd)||
     (id_uses_fpr[2]&&id_frs2==rd));
  // Dynamic FRM and header state are read only after the older CSR commits.
  wire id_reads_fp_csr=ENABLE_FPU&&(id_inst[6:0]==7'h73)&&
    (id_inst[14:12]!=0)&&((id_inst[31:20]==12'h001)||
    (id_inst[31:20]==12'h002)||(id_inst[31:20]==12'h003));
  wire id_csr_hazard=(id_reads_fp_csr&&ex_valid&&is_fp_compute)||
    (ex_valid&&csr_write&&
    (is_fp_csr||is_icache_header_csr||is_dcache_header_csr)) ||
    (wb_pending_q&&(wb_fp_csr_q||wb_icache_header_q||wb_dcache_header_q));
  wire id_stall=id_gpr_hazard||id_fpr_hazard||id_csr_hazard;
