// Included in edge_32_core.
  always @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
      mem_started_q<=0; mul_started_q<=0;
      accel_started_q<=0; cache_started_q<=0;
      icache_invalidate_started_q<=0;
    end else begin
      if(core_start_i||core_force_stop_i) begin
        mem_started_q<=0; mul_started_q<=0;
        accel_started_q<=0; cache_started_q<=0;
        icache_invalidate_started_q<=0;
      end
      if(lsu_start&&lsu_ready) mem_started_q<=1;
      if(mul_start&&mul_ready) mul_started_q<=1;
      if(accel_req_fire) accel_started_q<=1;
      if(cache_req_fire) cache_started_q<=1;
      if(icache_invalidate_fire) icache_invalidate_started_q<=1;
      if(ex_done&&!halted&&!core_start_i&&!core_force_stop_i) begin
        mem_started_q<=0; mul_started_q<=0; accel_started_q<=0;
        cache_started_q<=0; icache_invalidate_started_q<=0;
      end
    end
  end
