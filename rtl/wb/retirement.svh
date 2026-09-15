// Implementation owned by this stage module.

  assign icache_address_header = icache_address_header_q;
  assign dcache_address_header = dcache_address_header_q;
  assign cycle_count=cycle_q; assign instret_count=instret_q;
  always @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
      icache_address_header_q<=0; dcache_address_header_q<=0;
      halted<=0; illegal<=0;
    end else begin
      if(core_start_i) begin halted<=0; illegal<=0; end
      if(wb_commit) begin
        if(!wb_fault_q&&wb_icache_header_q)
          icache_address_header_q<=wb_header_value_q;
        if(!wb_fault_q&&wb_dcache_header_q)
          dcache_address_header_q<=wb_header_value_q;
        if(!wb_fault_q&&wb_halt_q) halted<=1;
        if(wb_fault_q) begin illegal<=1; halted<=1; end
      end
    end
  end
