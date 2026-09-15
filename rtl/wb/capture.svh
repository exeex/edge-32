// Implementation owned by this stage module.
  always @(posedge clk or negedge reset_n) begin
    if(!reset_n) wb_pending_q<=1'b0;
    else if(core_start_i||core_force_stop_i||halted) wb_pending_q<=1'b0;
    else wb_pending_q<=ex_wb_fire;
  end
  // WB payload has no reset; pending owns its visibility and cancellation.
  always @(posedge clk) begin
    if(ex_wb_fire) begin
      wb_fast_value_q<=ex_wb.fast_value; wb_other_value_q<=ex_wb.other_value;
      wb_alu_value_q<=ex_wb.alu_value; wb_alu_q<=ex_wb.alu;
      wb_fast_q<=ex_wb.fast; wb_rd_q<=ex_wb.rd;
      wb_gpr_q<=ex_wb.writes_gpr;
      wb_fault_q<=ex_wb.fault; wb_halt_q<=ex_wb.halt;
      wb_icache_header_q<=ex_wb.writes_icache_header;
      wb_dcache_header_q<=ex_wb.writes_dcache_header;
      wb_header_value_q<=ex_wb.header_value;
    end
  end

