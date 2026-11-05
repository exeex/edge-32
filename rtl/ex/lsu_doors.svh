// Included by cached_core only for the split LSU experiment. Each private
// router handles its own address selection, byte lanes and load formatting.
  wire [71:0] lane_payload [0:1];
  wire [1:0] lane_valid, lane_ready, lane_resp, lane_error;
  wire [31:0] lane_rdata [0:1];
  assign lane_payload[0] = {core_dmem_req_addr,core_dmem_req_wdata,core_dmem_req_wstrb,
                           core_dmem_req_size,core_dmem_req_signed,core_dmem_req_write};
  assign lane_payload[1] = fp_dmem_req_payload;
  assign lane_valid = {fp_dmem_req_valid,core_dmem_req_valid};
  assign {fp_dmem_req_ready,core_dmem_req_ready} = lane_ready;
  assign {fp_dmem_resp_valid,core_dmem_resp_valid} = lane_resp;
  assign {fp_dmem_resp_error,core_dmem_resp_error} = lane_error;
  assign core_dmem_resp_rdata = lane_rdata[0];
  assign fp_dmem_resp_rdata = lane_rdata[1];

  wire [1:0] c_valid, c_ready, c_resp, c_write;
  wire [31:0] c_addr [0:1], c_data [0:1];
  wire [3:0] c_strb [0:1];
  wire [1:0] t_valid, t_ready, t_we, t_resp;
  wire [DTCM_ADDR_WIDTH-1:0] t_addr [0:1];
  wire [63:0] t_data [0:1];
  wire [7:0] t_strb [0:1];

  for (genvar lane=0; lane<2; lane=lane+1) begin: g_lsu_route
    edge_32_dtcm_router #(.DTCM_ADDR_WIDTH(DTCM_ADDR_WIDTH)) route(
      .clk(clk),.reset_n(reset_n),.dtcm_base(dtcm_base),.dtcm_mask(dtcm_mask),
      .dtcm_enable(ENABLE_DTCM_PORT && dtcm_enable),
      .core_req_valid(lane_valid[lane]),.core_req_ready(lane_ready[lane]),
      .core_req_addr(lane_payload[lane][71:40]),.core_req_wdata(lane_payload[lane][39:8]),
      .core_req_wstrb(lane_payload[lane][7:4]),.core_req_size(lane_payload[lane][3:2]),
      .core_req_signed(lane_payload[lane][1]),.core_req_write(lane_payload[lane][0]),
      .core_resp_valid(lane_resp[lane]),.core_resp_error(lane_error[lane]),
      .core_resp_rdata(lane_rdata[lane]),
      .cache_req_valid(c_valid[lane]),.cache_req_ready(c_ready[lane]),
      .cache_req_addr(c_addr[lane]),.cache_req_wdata(c_data[lane]),
      .cache_req_wstrb(c_strb[lane]),.cache_req_write(c_write[lane]),
      .cache_resp_valid(c_resp[lane]),.cache_resp_error(cache_core_resp_error),
      .cache_resp_rdata(cache_core_resp_rdata),
      .dtcm_req(t_valid[lane]),.dtcm_ready(t_ready[lane]),.dtcm_we(t_we[lane]),
      .dtcm_addr(t_addr[lane]),.dtcm_wdata(t_data[lane]),.dtcm_wstrb(t_strb[lane]),
      .dtcm_rvalid(t_resp[lane]),.dtcm_rdata(dtcm_lsu_rdata));
  end

  // Separate grants and response owners at the two shared doors. EX issues
  // at most one memory operation so the active request cannot change lanes
  // while downstream ready is low. Stores to DTCM finish at acceptance.
  wire t_select_fp = t_valid[1];
  reg c_pending, c_owner_fp, t_pending, t_owner_fp;
  wire [71:0] cache_payload [0:1];
  assign cache_payload[0] = {c_addr[0],c_data[0],c_strb[0],lane_payload[0][3:1],c_write[0]};
  assign cache_payload[1] = {c_addr[1],c_data[1],c_strb[1],lane_payload[1][3:1],c_write[1]};
  wire fp_cache_valid;
  wire [71:0] fp_cache_payload;
  wire cache_fire = cache_core_req_valid && cache_core_req_ready;
  wire c_select_fp = fp_cache_valid;
  assign cache_core_req_valid = !c_pending && (c_valid[0] || fp_cache_valid);
  assign c_ready[0] = !c_pending && !c_select_fp && cache_core_req_ready;
  assign {cache_core_req_addr,cache_core_req_wdata,cache_core_req_wstrb,
          cache_core_req_size,cache_core_req_signed,cache_core_req_write} =
          c_select_fp ? fp_cache_payload : cache_payload[0];

`ifdef EDGE32_FP_CACHE_PIPE
  // One entry on the FP cache leg only. Private router ownership begins on
  // enqueue, shared cache ownership begins on dequeue.
  reg fp_cache_pending;
  reg [71:0] fp_cache_payload_q;
  assign fp_cache_valid = fp_cache_pending;
  assign fp_cache_payload = fp_cache_payload_q;
  assign c_ready[1] = !fp_cache_pending;
  always @(posedge clk or negedge reset_n) begin
    if (!reset_n) fp_cache_pending <= 1'b0;
    else if (c_valid[1] && c_ready[1]) fp_cache_pending <= 1'b1;
    else if (cache_fire && c_select_fp) fp_cache_pending <= 1'b0;
  end
  always @(posedge clk)
    if (c_valid[1] && c_ready[1]) fp_cache_payload_q <= cache_payload[1];
`else
  assign fp_cache_valid = c_valid[1];
  assign fp_cache_payload = cache_payload[1];
  assign c_ready[1] = !c_pending && c_select_fp && cache_core_req_ready;
`endif
  assign c_resp = {2{c_pending && cache_core_resp_valid}} & {c_owner_fp,!c_owner_fp};

  assign dtcm_lsu_req = !t_pending && (|t_valid);
  assign t_ready = {2{!t_pending && dtcm_lsu_ready}} & {t_select_fp,!t_select_fp};
  assign dtcm_lsu_we = t_we[t_select_fp];
  assign dtcm_lsu_addr = t_addr[t_select_fp];
  assign dtcm_lsu_wdata = t_data[t_select_fp];
  assign dtcm_lsu_wstrb = t_strb[t_select_fp];
  assign t_resp = {2{t_pending && dtcm_lsu_rvalid}} & {t_owner_fp,!t_owner_fp};

  always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      c_pending <= 1'b0;
      c_owner_fp <= 1'b0;
      t_pending <= 1'b0;
      t_owner_fp <= 1'b0;
    end else begin
      if (cache_fire) begin
        c_pending <= 1'b1;
        c_owner_fp <= c_select_fp;
      end else if (cache_core_resp_valid) begin
        c_pending <= 1'b0;
      end
      if (dtcm_lsu_req && dtcm_lsu_ready && !dtcm_lsu_we) begin
        t_pending <= 1'b1;
        t_owner_fp <= t_select_fp;
      end else if (dtcm_lsu_rvalid) begin
        t_pending <= 1'b0;
      end
    end
  end
