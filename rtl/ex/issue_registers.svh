// Included in edge_32_core; preserves the existing hardware hierarchy.
  // Named access preserves the ID->EX packet bit layout and capture edge.
  assign is_lui = ex_issue_control_q.is_lui;
  assign is_auipc = ex_issue_control_q.is_auipc;
  assign is_jal = ex_issue_control_q.is_jal;
  assign is_jalr = ex_issue_control_q.is_jalr;
  assign is_branch = ex_issue_control_q.is_branch;
  assign is_load = ex_issue_control_q.is_load;
  assign is_store = ex_issue_control_q.is_store;
  assign is_fp_load = ex_issue_control_q.is_fp_load;
  assign is_fp_store = ex_issue_control_q.is_fp_store;
  assign is_fp_compute = ex_issue_control_q.is_fp_compute;
  assign is_muldiv = ex_issue_control_q.is_muldiv;
  assign is_cycle = ex_issue_control_q.is_cycle;
  assign is_instret = ex_issue_control_q.is_instret;
  assign is_hardware_id = ex_issue_control_q.is_hardware_id;
  assign is_icache_header_csr = ex_issue_control_q.is_icache_header_csr;
  assign is_dcache_header_csr = ex_issue_control_q.is_dcache_header_csr;
  assign is_fp_csr = ex_issue_control_q.is_fp_csr;
  assign is_edge_break = ex_issue_control_q.is_edge_break;
  assign is_edge_cache = ex_issue_control_q.is_edge_cache;
  assign is_fast_class = ex_issue_control_q.is_fast_class;
  assign is_int_mem = ex_issue_control_q.is_int_mem;
  assign is_fp_mem = ex_issue_control_q.is_fp_mem;
  assign is_fence_i = ex_issue_control_q.is_fence_i;
  assign is_supported_system = ex_issue_control_q.is_supported_system;
  assign is_accel = ex_issue_control_q.is_accel;
  assign csr_fflags = ex_issue_control_q.csr_fflags;
  assign csr_frm = ex_issue_control_q.csr_frm;
  assign csr_write = ex_issue_control_q.csr_write;
  assign cache_is_va = ex_issue_control_q.cache_is_va;
  assign cache_kind = ex_issue_control_q.cache_kind;
  assign f3 = ex_issue_control_q.funct3;
  assign funct7_bit5 = ex_issue_control_q.funct7_bit5;
  assign shamt = ex_issue_control_q.shamt;
  assign csr_uimm = ex_issue_control_q.csr_uimm;
  assign rd = ex_issue_control_q.write_rd;
  assign alu_op = ex_issue_control_q.alu_op;
  assign ex_writes_gpr = ex_issue_control_q.writes_gpr;
  assign ex_writes_fpr = ex_issue_control_q.writes_fpr;
  always @(posedge clk) begin
    if(id_capture_enable) begin
      ex_issue_control_q<=id_issue_control;
      ex_alu_imm_q<=id_alu_imm; ex_mem_imm_q<=id_mem_imm;
      ex_branch_imm_q<=id_branch_imm; ex_jump_imm_q<=id_jump_imm;
    end
  end
