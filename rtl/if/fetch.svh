// Included in edge_32_core; preserves the existing hardware hierarchy.
  edge_32_frontend #(.PC_WIDTH(PC_WIDTH),.AUTO_START(AUTO_START)) frontend(
    .clk(clk),.reset_n(reset_n),.boot_pc(boot_pc),
    .fetch_start(core_start_i),.fetch_stop(core_force_stop_i),
    .imem_req_valid(imem_req_valid),.imem_req_ready(imem_req_ready),
    .imem_req_addr(imem_req_addr),.imem_resp_valid(imem_resp_valid),
    .imem_resp_data(imem_resp_data),.imem_resp_error(imem_resp_error),
    .op_valid(parcel_valid),.op_ready(parcel_ready),
    // Stop/redirect qualify actual transfers at the frontend, after capacity.
    .op_capacity_ready(if_capacity_ready && !core_start_i && !core_force_stop_i),.op_pc(parcel_pc),
    .op_inst(parcel_inst), .op_error(parcel_error), .halt(frontend_stop),
    .redirect_valid(redirect),.redirect_pc(redirect_pc));
  // Fixed 32-bit fetch: cancel actual transfers without changing capacity.
  wire if_flush = redirect || frontend_stop || core_start_i || core_force_stop_i;
  assign if_valid = parcel_valid && !if_flush;
  assign parcel_ready = if_ready && !if_flush;
  assign if_pc = parcel_pc;
  assign if_inst = parcel_inst;
  assign if_error = parcel_error;
