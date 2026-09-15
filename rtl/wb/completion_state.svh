// Included in edge_32_core; preserves the existing hardware hierarchy.
  // One registered completion slot. EX can complete while old WB retires.
  reg wb_pending_q;
  reg [31:0] wb_fast_value_q, wb_other_value_q;
  reg wb_fast_q;
  wire [31:0] wb_value_q=wb_fast_q ? wb_fast_value_q:wb_other_value_q;
  reg [4:0] wb_rd_q;
  reg wb_gpr_q, wb_fault_q, wb_halt_q;
  wire wb_fp_csr_q;
  reg wb_icache_header_q, wb_dcache_header_q;
  reg [31:0] wb_header_value_q;
  wire wb_commit=wb_pending_q&&!halted&&!core_start_i&&!core_force_stop_i;
  edge_32_counter64 cycle_counter(.clk(clk),.reset_n(reset_n),
    .enable(1'b1),.value(cycle_q));
  edge_32_counter64 retire_counter(.clk(clk),.reset_n(reset_n),
    .enable(wb_commit&&!wb_fault_q),.value(instret_q));
  wire wb_terminal=wb_pending_q&&(wb_fault_q||wb_halt_q);
  wire wb_valid=wb_commit&&!wb_fault_q&&wb_gpr_q;
