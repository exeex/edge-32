// Included in edge_32_core; preserves the existing hardware hierarchy.
  assign accel_req_valid=ex_issue_ok&&is_accel&&!accel_started_q;
  assign accel_req_inst=ex_inst[31:0];
  assign accel_req_src0={32'd0,ex_rs1_value};
  assign accel_req_src1={32'd0,ex_rs2_value};
  wire accel_req_fire=accel_req_valid&&accel_req_ready;
  wire accel_done=is_accel&&accel_started_q&&accel_resp_valid;
  assign cache_op_valid=ex_issue_ok&&is_edge_cache&&!cache_started_q;
  assign cache_op_is_va=cache_is_va;
  assign cache_op_kind=cache_kind;
  assign cache_op_addr={32'd0,ex_rs1_value};
  wire cache_req_fire=cache_op_valid&&cache_op_ready;
  wire cache_done=is_edge_cache&&cache_started_q&&cache_op_complete_valid;
  assign icache_invalidate_valid=
    ex_issue_ok&&is_fence_i&&!icache_invalidate_started_q;
  wire icache_invalidate_fire=
    icache_invalidate_valid&&icache_invalidate_ready;
  wire fence_i_done=is_fence_i&&icache_invalidate_started_q&&
    icache_invalidate_complete;
  wire fast_done=ex_issue_ok&&is_fast_class;
  wire sys_done=ex_issue_ok&&is_supported_system&&!is_fence_i;
  // Pipeline already owns EX valid and cancels capture on stop/redirect.
  // Export execution readiness before WB's live-owner/commit qualification.
  wire ex_release_ready=(fast_done||sys_done||(is_muldiv&&mul_started_q&&mul_result_valid)||
     ((is_int_mem||is_fp_mem)&&mem_started_q&&lsu_done)||
     fp_compute_complete||
     accel_done||cache_done||fence_i_done||ex_decode_fault_q);
  wire ex_done=ex_valid&&!halted&&!core_start_i&&!core_force_stop_i&&
               ex_release_ready;
  wire ex_faulting=ex_decode_fault_q||
    ((is_int_mem||is_fp_mem)&&lsu_done&&lsu_error)||
    (is_accel&&accel_done&&accel_resp_error);
  // Same ID->EX edge, distinct physical owner beside the frontend. Execution
  // units export narrow owned fault events; no operand/result bus enters here.
  wire terminal_complete;
  edge_32_frontend_control frontend_control(
    .clk(clk),.id_capture_enable(id_capture_enable),
    .id_decode_fault(id_error||!id_issue_legal),
    .id_terminal_break(id_terminal_break),
    .ex_valid(ex_valid),.halted(halted),.wb_terminal(wb_terminal),
    .core_start(core_start_i),.core_force_stop(core_force_stop_i),
    .memory_fault_complete((is_int_mem||is_fp_mem)&&mem_started_q&&lsu_done&&lsu_error),
    .accel_fault_complete(accel_done&&accel_resp_error),
    .ex_decode_fault(ex_decode_fault_q),.ex_terminal_break(is_terminal_break),
    .terminal_complete(terminal_complete));
  wire frontend_stop=halted||terminal_complete||wb_terminal;
  wire ex_control=is_jal||is_jalr||is_branch;
  wire branch_redirect=fast_done&&ex_control&&branch_taken;
  wire redirect=branch_redirect||fence_i_done;
  wire [PC_WIDTH-1:0] redirect_pc=fence_i_done ?
    ex_pc+{{(PC_WIDTH-3){1'b0}},3'd4}:branch_target;
