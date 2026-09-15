// Implementation owned by this stage module.
    assign is_address_header_csr=is_icache_header_csr||is_dcache_header_csr;
    assign ex_legal=decoded_legal;
    assign ex_issue_ok=ex_valid&&!halted&&!wb_terminal&&!ex_decode_fault_q&&
                   !core_start_i&&!core_force_stop_i;

  edge_32_alu #(.PC_WIDTH(PC_WIDTH)) fast_alu(
    .fast_issue_op(alu_op),.fast_issue_pc(ex_pc),
    .fast_issue_src0_value(ex_rs1_value),
    .fast_issue_src1_value(ex_rs2_value),
    .fast_issue_imm(ex_alu_imm_q),
    .fast_issue_funct3(f3),
    .fast_issue_funct7_bit5(funct7_bit5),.fast_issue_funct7_is_m(1'b0),
    .fast_issue_shamt(shamt),
    .fast_result(fast_result));

  edge_32_branch #(.PC_WIDTH(PC_WIDTH)) branch(
    .branch_issue_op(alu_op),.branch_issue_pc(ex_pc),
    .branch_issue_src0_value(ex_rs1_value),
    .branch_issue_src1_value(ex_rs2_value),
    .branch_issue_imm(ex_mem_imm_q),.branch_issue_branch_imm(ex_branch_imm_q),
    .branch_issue_jal_imm(ex_jump_imm_q),.branch_issue_funct3(f3),
    .branch_taken(branch_taken),.branch_target(branch_target));

    assign mul_start=ex_issue_ok&&is_muldiv&&!mul_started_q;
  edge_32_muldiv_asap7 muldiv(.clk(clk),.reset_n(reset_n),
    .op_valid(mul_start),.op_ready(mul_ready),
    .src0(ex_rs1_value),.src1(ex_rs2_value),.funct3(f3),
    .result_valid(mul_result_valid),.result_value(mul_result),.busy());

    assign lsu_start=ex_issue_ok&&(is_int_mem||is_fp_mem)&&!mem_started_q;

  edge_32_lsu #(.MEM_RESP_FORMATTED(DMEM_RESP_FORMATTED)) lsu(
    .clk(clk),.reset_n(reset_n),.op_valid(lsu_start),
    .op_ready(lsu_ready),.op_store(is_store||is_fp_store),
    .op_fp(is_fp_load||is_fp_store),.op_funct3(f3),
    .op_base(ex_rs1_value),
    .op_offset(ex_mem_imm_q),
    .op_store_data(is_fp_store?fp_store_value[31:0]:ex_rs2_value),
    .mem_req_valid(dmem_req_valid),
    .mem_req_ready(dmem_req_ready),.mem_req_write(dmem_req_write),
    .mem_req_addr(lsu_mem_addr),.mem_req_wdata(dmem_req_wdata),
    .mem_req_wstrb(dmem_req_wstrb),.mem_req_size(dmem_req_size),
    .mem_req_signed(dmem_req_signed),.mem_resp_valid(dmem_resp_valid),
    .mem_resp_error(dmem_resp_error),.mem_resp_rdata(dmem_resp_rdata),
    .op_done(lsu_done),.op_error(lsu_error),.op_load_value(lsu_value),.busy());
  assign dmem_req_addr={32'd0,lsu_mem_addr};

  generate if(ENABLE_FPU) begin: g_fpu
    edge_32_fpu fpu(
      .clk(clk),.reset_n(reset_n),.cancel(core_start_i||core_force_stop_i),
      .id_capture_enable(id_capture_enable),.id_inst(id_inst[31:0]),
      .id_frs0(id_frs0),.id_frs1(id_frs1),.id_frs2(id_frs2),
      .id_fpu_control(id_fpu_control),.ex_issue_ok(ex_issue_ok),.ex_done(ex_done),
      .is_fp_compute(is_fp_compute),.ex_writes_fpr(ex_writes_fpr),
      .is_fp_csr(is_fp_csr),.csr_fflags(csr_fflags),.csr_frm(csr_frm),
      .csr_write(csr_write),.f3(f3),.csr_uimm(csr_uimm),
      .ex_rs1_value(ex_rs1_value),.lsu_value(lsu_value),
      .fp_compute_complete(fp_compute_complete),.fpu_value(fpu_value),
      .fp_load_value(fp_load_value),.fp_store_value(fp_store_value),
      .fp_csr_value(fp_csr_value),.wb_commit(wb_commit),.wb_fault_q(wb_fault_q),
      .wb_rd_q(wb_rd_q),.wb_value_q(wb_value_q),.wb_fp_csr_q(wb_fp_csr_q));
  end else begin: g_no_fpu
    assign id_fpu_control=32'd0;
    assign fp_compute_complete=1'b0;
    assign fpu_value=32'd0; assign fp_csr_value=32'd0;
    assign fp_load_value=32'd0; assign fp_store_value=64'd0;
    assign wb_fp_csr_q=1'b0;
  end endgenerate

