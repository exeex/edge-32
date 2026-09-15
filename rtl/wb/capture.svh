// Included in edge_32_core; preserves the existing hardware hierarchy.
  always @(posedge clk or negedge reset_n) begin
    if(!reset_n) wb_pending_q<=1'b0;
    else if(core_start_i||core_force_stop_i||halted) wb_pending_q<=1'b0;
    else wb_pending_q<=ex_done;
  end
  // WB payload has no reset; pending owns its visibility and cancellation.
  always @(posedge clk) begin
    if(ex_done) begin
      wb_fast_value_q<=fast_result; wb_other_value_q<=ex_result;
      wb_fast_q<=is_fast_class; wb_rd_q<=rd;
      wb_gpr_q<=ex_writes_gpr;
      wb_fault_q<=ex_faulting; wb_halt_q<=is_terminal_break;
      wb_icache_header_q<=is_icache_header_csr&&address_header_write;
      wb_dcache_header_q<=is_dcache_header_csr&&address_header_write;
      wb_header_value_q<=address_header_new;
    end
  end

