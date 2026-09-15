// Implementation owned by this stage module.
  // One registered completion slot. EX can complete while old WB retires.
  edge_32_counter64 cycle_counter(.clk(clk),.reset_n(reset_n),
    .enable(1'b1),.value(cycle_q));
  edge_32_counter64 retire_counter(.clk(clk),.reset_n(reset_n),
    .enable(wb_commit&&!wb_fault_q),.value(instret_q));
  assign wb_terminal=wb_pending_q&&(wb_fault_q||wb_halt_q);
  assign wb_valid=wb_commit&&!wb_fault_q&&wb_gpr_q;
