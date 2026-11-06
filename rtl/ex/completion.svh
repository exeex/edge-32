// Implementation owned by this stage module.
`include "ex/asic_control/issue.svh"
`include "ex/csr/cache_control.svh"
    assign fast_done=ex_issue_ok&&is_fast_class;
  // Capacity is independent of validity, launch permission and cancellation.
  // Static one-cycle classes were decoded at ID capture; slow units expose
  // completion of their owned transaction. Actual transfers are qualified below.
  wire immediate_done = ex_immediate_complete_q && !fp_capture_pending;
  wire memory_done = (is_int_mem || is_fp_mem) && mem_started_q && lsu_done;
`ifdef EDGE32_EXTERNAL_FPU
  reg fp_done_q, fp_wb_valid_q;
  // Only FP operations use this completion channel. Keep EX occupied so the
  // owner can capture the held result, flags and destination with fp_done_q.
  always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      fp_done_q <= 1'b0;
      fp_wb_valid_q <= 1'b0;
    end else begin
      fp_done_q <= ex_issue_ok && !fp_done_q &&
        ((is_fp_csr && immediate_done) || (is_fp_mem && memory_done) ||
         fp_compute_complete);
      fp_wb_valid_q <= ex_done && fp_done_q;
    end
  end
  wire immediate_release = !is_fp_csr && immediate_done;
  wire memory_release = is_fp_mem ? fp_done_q : memory_done;
  wire fp_release = fp_done_q;
`else
  wire immediate_release = immediate_done;
  wire memory_release = memory_done;
  wire fp_release = fp_compute_complete;
`endif
  assign ex_release_ready=(immediate_release||
     (is_instret&&instret_read_ready_q)||
     (is_muldiv&&mul_started_q&&mul_result_valid)||
     memory_release||fp_release||accel_done||cache_done||fence_i_done||ex_decode_fault_q);
  assign ex_done=ex_valid&&!halted&&!wb_terminal&&!core_start_i&&!core_force_stop_i&&
               ex_release_ready;
  wire memory_fault_complete = memory_release && lsu_error;
  assign ex_faulting=ex_decode_fault_q||memory_fault_complete||
    (is_accel&&accel_done&&accel_resp_error);
  // Same ID->EX edge, distinct physical owner beside the frontend. Execution
  // units export narrow owned fault events; no operand/result bus enters here.
  edge_32_frontend_control frontend_control(
    .clk(clk),.id_capture_enable(id_capture_enable),
    .id_decode_fault(id_error||!id_issue_legal),
    .id_terminal_break(id_terminal_break),
    .ex_valid(ex_valid),.halted(halted),.wb_terminal(wb_terminal),
    .core_start(core_start_i),.core_force_stop(core_force_stop_i),
    .memory_fault_complete(memory_fault_complete),
    .accel_fault_complete(accel_done&&accel_resp_error),
    .ex_decode_fault(ex_decode_fault_q),.ex_terminal_break(is_terminal_break),
    .terminal_complete(terminal_complete));
  assign frontend_stop=halted||terminal_complete||wb_terminal;
    assign ex_control=is_jal||is_jalr||is_branch;
    assign branch_redirect=fast_done&&ex_control&&branch_taken;
  assign redirect=branch_redirect||(ex_done&&fence_i_done);
  assign redirect_pc=fence_i_done ?
    ex_pc+{{(PC_WIDTH-3){1'b0}},3'd4}:branch_target;
