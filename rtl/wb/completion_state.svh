// Implementation owned by this stage module.
  // One registered completion slot. EX can complete while old WB retires.
  assign wb_terminal=wb_pending_q&&(wb_fault_q||wb_halt_q);
  assign wb_valid=wb_commit&&!wb_fault_q&&wb_gpr_q;
