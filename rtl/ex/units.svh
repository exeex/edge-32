// Restore XLEN at the consumer; no second immediate register or format tag.
  wire [31:0] ex_imm = (is_lui || is_auipc) ? {ex_imm_q, 12'b0} :
    is_jal ? {{11{ex_imm_q[19]}}, ex_imm_q, 1'b0} :
    is_branch ? {{19{ex_imm_q[11]}}, ex_imm_q[11:0], 1'b0} :
                {{20{ex_imm_q[11]}}, ex_imm_q[11:0]};
// Implementation owned by this stage module.
`ifdef EDGE32_EXTERNAL_FPU
  reg fp_capture_pending_q;
  reg [4:0] fp_frs0_q, fp_frs1_q, fp_frs2_q;
  wire fp_capture_pending = ENABLE_FPU && fp_capture_pending_q;
  always @(posedge clk or negedge reset_n) begin
    if (!reset_n) fp_capture_pending_q <= 1'b0;
    else fp_capture_pending_q <= ENABLE_FPU && id_capture_enable && id_valid &&
      !id_error && id_issue_legal &&
      (id_issue_control.is_fp_compute || id_issue_control.is_fp_mem ||
       id_issue_control.is_fp_csr);
  end
  always @(posedge clk) begin
    if (id_capture_enable)
      {fp_frs0_q, fp_frs1_q, fp_frs2_q} <= {id_frs0, id_frs1, id_frs2};
  end
`else
  wire fp_capture_pending = 1'b0;
`endif
  wire fp_issue_ok = ex_issue_ok && !fp_capture_pending;

    assign is_address_header_csr=is_icache_header_csr||is_dcache_header_csr;
    assign ex_issue_ok=ex_valid&&!halted&&!wb_terminal&&!ex_decode_fault_q&&
                   !core_start_i&&!core_force_stop_i;

  edge_32_alu #(.PC_WIDTH(PC_WIDTH)) fast_alu(
    .fast_issue_op(alu_op),.fast_issue_pc(ex_pc),
    .fast_issue_src0_value(ex_rs1_value),
    .fast_issue_src1_value(ex_rs2_value),
    .fast_issue_imm(ex_imm),
    .fast_issue_funct3(f3),
    .fast_issue_funct7_bit5(funct7_bit5),.fast_issue_funct7_is_m(1'b0),
    .fast_issue_shamt(shamt),
    .fast_result(),.simple_result(fast_result),
    .complex_result(alu_result),.simple_select(simple_select));

  edge_32_branch #(.PC_WIDTH(PC_WIDTH)) branch(
    .branch_issue_op(alu_op),.branch_issue_pc(ex_pc),
    .branch_issue_src0_value(ex_rs1_value),
    .branch_issue_src1_value(ex_rs2_value),
    .branch_issue_imm(ex_imm),.branch_issue_funct3(f3),
    .branch_taken(branch_taken),.branch_target(branch_target));

    assign mul_start=ex_issue_ok&&is_muldiv&&!mul_started_q;
  edge_32_muldiv_asap7 muldiv(.clk(clk),.reset_n(reset_n),
    .op_valid(mul_start),.op_ready(mul_ready),
    .src0(ex_rs1_value),.src1(ex_rs2_value),.funct3(f3),
    .result_valid(mul_result_valid),.result_value(mul_result),.busy());

`ifdef EDGE32_SPLIT_LSU
  wire int_ready, int_done, int_error, int_busy;
  wire fp_ready, fp_done, fp_error, fp_busy;
  wire [31:0] fp_lsu_value;
  // The EX issue contract remains one memory operation at a time, including
  // draining the previous LSU after a start/force-stop.
  wire int_start = ex_issue_ok && is_int_mem && !mem_started_q && !fp_busy;
  wire fp_start = fp_issue_ok && is_fp_mem && !mem_started_q && !int_busy;
  assign lsu_start = int_start || fp_start;
  assign lsu_ready = is_fp_mem ? fp_ready : int_ready;
  assign lsu_done = is_fp_mem ? fp_done : int_done;
  assign lsu_error = is_fp_mem ? fp_error : int_error;
  edge_32_lsu #(.MEM_RESP_FORMATTED(DMEM_RESP_FORMATTED)) lsu(
`ifdef EDGE32_INT_DTCM_PIPE
    .int_dtcm_base(int_dtcm_base),.int_dtcm_mask(int_dtcm_mask),
    .int_dtcm_enable(int_dtcm_enable),.int_dtcm_hit(int_dtcm_hit),
    .int_dtcm_base_snapshot(int_dtcm_base_snapshot),
`endif
    .clk(clk),.reset_n(reset_n),.op_valid(int_start),
    .op_ready(int_ready),.op_store(is_store),
    .op_fp(1'b0),.op_funct3(f3),
    .op_base(ex_rs1_value),
    .op_offset(ex_imm),
    .op_store_data(ex_rs2_value),
    .mem_req_valid(dmem_req_valid),
    .mem_req_ready(dmem_req_ready),.mem_req_write(dmem_req_write),
    .mem_req_addr(lsu_mem_addr),.mem_req_wdata(dmem_req_wdata),
    .mem_req_wstrb(dmem_req_wstrb),.mem_req_size(dmem_req_size),
    .mem_req_signed(dmem_req_signed),.mem_resp_valid(dmem_resp_valid),
    .mem_resp_error(dmem_resp_error),.mem_resp_rdata(dmem_resp_rdata),
    .op_done(int_done),.op_error(int_error),.op_load_value(lsu_value),.busy(int_busy));
  assign dmem_req_addr=lsu_mem_addr;
`else
    assign lsu_start=((ex_issue_ok&&is_int_mem)||(fp_issue_ok&&is_fp_mem))&&!mem_started_q;

  edge_32_lsu #(.MEM_RESP_FORMATTED(DMEM_RESP_FORMATTED)) lsu(
    .clk(clk),.reset_n(reset_n),.op_valid(lsu_start),
    .op_ready(lsu_ready),.op_store(is_store||is_fp_store),
    .op_fp(is_fp_load||is_fp_store),.op_funct3(f3),
    .op_base(ex_rs1_value),
    .op_offset(ex_imm),
    .op_store_data(is_fp_store?fp_store_value[31:0]:ex_rs2_value),
    .mem_req_valid(dmem_req_valid),
    .mem_req_ready(dmem_req_ready),.mem_req_write(dmem_req_write),
    .mem_req_addr(lsu_mem_addr),.mem_req_wdata(dmem_req_wdata),
    .mem_req_wstrb(dmem_req_wstrb),.mem_req_size(dmem_req_size),
    .mem_req_signed(dmem_req_signed),.mem_resp_valid(dmem_resp_valid),
    .mem_resp_error(dmem_resp_error),.mem_resp_rdata(dmem_resp_rdata),
    .op_done(lsu_done),.op_error(lsu_error),.op_load_value(lsu_value),.busy());
  assign dmem_req_addr=lsu_mem_addr;

`endif
`ifdef EDGE32_EXTERNAL_FPU
  assign fpu_cancel = core_start_i || core_force_stop_i;
  assign fpu_id_capture_enable = fp_capture_pending;
  assign fpu_id_inst = ex_inst;
  assign fpu_id_frs0 = fp_frs0_q;
  assign fpu_id_frs1 = fp_frs1_q;
  assign fpu_id_frs2 = fp_frs2_q;
  assign fpu_ex_issue_ok = ENABLE_FPU && fp_issue_ok;
  assign fpu_ex_done = fp_done_q;
  assign fpu_is_fp_compute = is_fp_compute;
  assign fpu_ex_writes_fpr = ex_writes_fpr;
  assign fpu_is_fp_csr = is_fp_csr;
  assign fpu_csr_fflags = csr_fflags;
  assign fpu_csr_frm = csr_frm;
  assign fpu_csr_write = csr_write;
  assign fpu_f3 = f3;
  assign fpu_csr_uimm = csr_uimm;
  assign fpu_ex_rs1_value = ex_rs1_value;
`ifdef EDGE32_SPLIT_LSU
  assign fpu_lsu_value = fp_lsu_value;
`else
  assign fpu_lsu_value = lsu_value;
`endif
  assign fpu_wb_commit = wb_commit && fp_wb_valid_q;
  assign fpu_wb_fault_q = wb_fault_q;
`ifdef EDGE32_LOCAL_FP_WB
  assign fpu_is_fp_load = is_fp_load;
  assign fpu_ex_fpr_rd = rd;
`else
  assign fpu_wb_rd_q = wb_rd_q;
  assign fpu_wb_value_q = wb_value_q;
`endif
`endif
  generate if(ENABLE_FPU) begin: g_fpu
`ifdef EDGE32_SPLIT_LSU
    edge_32_lsu #(.MEM_RESP_FORMATTED(DMEM_RESP_FORMATTED)) fp_lsu(
`ifdef EDGE32_INT_DTCM_PIPE
      .int_dtcm_base(64'b0),.int_dtcm_mask(64'b0),
      .int_dtcm_enable(1'b0),.int_dtcm_hit(),.int_dtcm_base_snapshot(),
`endif
      .clk(clk),.reset_n(reset_n),.op_valid(fp_start),.op_ready(fp_ready),
      .op_store(is_fp_store),.op_fp(1'b1),.op_funct3(f3),
      .op_base(ex_rs1_value),.op_offset(ex_imm),.op_store_data(fp_store_value[31:0]),
      .mem_req_valid(fp_dmem_req_valid),.mem_req_ready(fp_dmem_req_ready),
      .mem_req_addr(fp_dmem_req_payload[71:40]),.mem_req_wdata(fp_dmem_req_payload[39:8]),
      .mem_req_wstrb(fp_dmem_req_payload[7:4]),.mem_req_size(fp_dmem_req_payload[3:2]),
      .mem_req_signed(fp_dmem_req_payload[1]),.mem_req_write(fp_dmem_req_payload[0]),
      .mem_resp_valid(fp_dmem_resp_valid),.mem_resp_error(fp_dmem_resp_error),
      .mem_resp_rdata(fp_dmem_resp_rdata),.op_done(fp_done),.op_error(fp_error),
      .op_load_value(fp_lsu_value),.busy(fp_busy));
`endif
`ifdef EDGE32_EXTERNAL_FPU
    // Resolve legality in scalar ID using the owner's registered FRM.
    // The owner independently decodes the registered instruction payload.
    edge_fpu_id_decode #(.GPR_WIDTH(32)) id_fp_legal_decode(
      .inst(id_inst),.frm(fpu_frm),.control(id_fpu_control));
    assign fp_compute_complete = fpu_fp_compute_complete;
    assign fpu_value = fpu_fpu_value;
    assign fp_load_value = fpu_fp_load_value;
    assign fp_store_value = fpu_fp_store_value;
    assign fp_csr_value = fpu_fp_csr_value;
    assign wb_fp_csr_q = fp_wb_valid_q && fpu_wb_fp_csr_q;
`else
    edge_32_fpu fpu(
      .clk(clk),.reset_n(reset_n),.cancel(core_start_i||core_force_stop_i),
      .id_capture_enable(id_capture_enable),.id_inst(id_inst[31:0]),
      .id_frs0(id_frs0),.id_frs1(id_frs1),.id_frs2(id_frs2),
      .id_fpu_control(id_fpu_control),.frm(),.ex_issue_ok(ex_issue_ok),.ex_done(ex_done),
      .is_fp_compute(is_fp_compute),.ex_writes_fpr(ex_writes_fpr),
      .is_fp_csr(is_fp_csr),.csr_fflags(csr_fflags),.csr_frm(csr_frm),
      .csr_write(csr_write),.f3(f3),.csr_uimm(csr_uimm),
      .ex_rs1_value(ex_rs1_value),
`ifdef EDGE32_SPLIT_LSU
      .lsu_value(fp_lsu_value),
`else
      .lsu_value(lsu_value),
`endif
      .fp_compute_complete(fp_compute_complete),.fpu_value(fpu_value),
      .fp_load_value(fp_load_value),.fp_store_value(fp_store_value),
      .fp_csr_value(fp_csr_value),.wb_commit(wb_commit),.wb_fault_q(wb_fault_q),
`ifdef EDGE32_LOCAL_FP_WB
      .is_fp_load(is_fp_load),.ex_fpr_rd(rd),
`else
      .wb_rd_q(wb_rd_q),.wb_value_q(wb_value_q),
`endif
      .wb_fp_csr_q(wb_fp_csr_q));
`endif
  end else begin: g_no_fpu
`ifdef EDGE32_SPLIT_LSU
    assign fp_ready=1'b0, fp_done=1'b0, fp_error=1'b0, fp_busy=1'b0;
    assign fp_lsu_value=32'b0;
    assign fp_dmem_req_valid=1'b0, fp_dmem_req_payload=72'b0;
`endif
    assign id_fpu_control=32'd0;
    assign fp_compute_complete=1'b0;
    assign fpu_value=32'd0; assign fp_csr_value=32'd0;
    assign fp_load_value=32'd0; assign fp_store_value=64'd0;
    assign wb_fp_csr_q=1'b0;
  end endgenerate

