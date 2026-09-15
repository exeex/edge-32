// Implementation owned by this stage module.
  assign accel_req_valid=ex_issue_ok&&is_accel&&!accel_started_q;
  assign accel_req_inst=ex_inst[31:0];
  assign accel_req_src0={32'd0,ex_rs1_value};
  assign accel_req_src1={32'd0,ex_rs2_value};
    assign accel_req_fire=accel_req_valid&&accel_req_ready;
    assign accel_done=is_accel&&accel_started_q&&accel_resp_valid;
  assign cache_op_valid=ex_issue_ok&&is_edge_cache&&!cache_started_q;
  assign cache_op_is_va=cache_is_va;
  assign cache_op_kind=cache_kind;
  assign cache_op_addr={32'd0,ex_rs1_value};
    assign cache_req_fire=cache_op_valid&&cache_op_ready;
    assign cache_done=is_edge_cache&&cache_started_q&&cache_op_complete_valid;
  assign icache_invalidate_valid=
    ex_issue_ok&&is_fence_i&&!icache_invalidate_started_q;
    assign icache_invalidate_fire=
    icache_invalidate_valid&&icache_invalidate_ready;
    assign fence_i_done=is_fence_i&&icache_invalidate_started_q&&
    icache_invalidate_complete;
    assign fast_done=ex_issue_ok&&is_fast_class;
  // Capacity is independent of validity, launch permission and cancellation.
  // Static one-cycle classes were decoded at ID capture; slow units expose
  // completion of their owned transaction. Actual transfers are qualified below.
  assign ex_release_ready=(ex_immediate_complete_q||
     (is_instret&&instret_read_ready_q)||
     (is_muldiv&&mul_started_q&&mul_result_valid)||
     ((is_int_mem||is_fp_mem)&&mem_started_q&&lsu_done)||
     fp_compute_complete||accel_done||cache_done||fence_i_done||ex_decode_fault_q);
  assign ex_done=ex_valid&&!halted&&!wb_terminal&&!core_start_i&&!core_force_stop_i&&
               ex_release_ready;
  assign ex_faulting=ex_decode_fault_q||
    ((is_int_mem||is_fp_mem)&&lsu_done&&lsu_error)||
    (is_accel&&accel_done&&accel_resp_error);
  // Same ID->EX edge, distinct physical owner beside the frontend. Execution
  // units export narrow owned fault events; no operand/result bus enters here.
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
  assign frontend_stop=halted||terminal_complete||wb_terminal;
    assign ex_control=is_jal||is_jalr||is_branch;
    assign branch_redirect=fast_done&&ex_control&&branch_taken;
  assign redirect=branch_redirect||(ex_done&&fence_i_done);
  assign redirect_pc=fence_i_done ?
    ex_pc+{{(PC_WIDTH-3){1'b0}},3'd4}:branch_target;
