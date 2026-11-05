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
    wire router_valid, router_ready, router_resp, router_error;
    wire [71:0] router_payload;
    wire [63:0] router_base;
    wire [31:0] router_rdata, router_cache_addr, router_cache_data;
    wire [3:0] router_cache_strb;
    wire router_cache_valid, router_cache_write;
`ifdef EDGE32_INT_DTCM_PIPE
    localparam DTCM_ONLY = lane == 0;
`else
    localparam DTCM_ONLY = 0;
`endif
`ifdef EDGE32_INT_DTCM_PIPE
    if (DTCM_ONLY) begin: g_int_dtcm_pipe
      reg pending;
      reg [71:0] payload_q;
      reg [DTCM_ADDR_WIDTH+2:0] base_q;
      wire enqueue = lane_valid[lane] && int_dtcm_hit && !pending;
      assign lane_ready[lane] = int_dtcm_hit ? !pending : c_ready[lane];
      assign c_valid[lane] = lane_valid[lane] && !int_dtcm_hit;
      assign {c_addr[lane],c_data[lane],c_strb[lane],c_write[lane]} =
        {lane_payload[lane][71:4],lane_payload[lane][0]};
      assign lane_resp[lane] = router_resp || c_resp[lane];
      assign lane_error[lane] = c_resp[lane] && cache_core_resp_error;
      assign lane_rdata[lane] = router_resp ? router_rdata : cache_core_resp_rdata;
      assign router_payload = payload_q;
      assign router_base = {{(61-DTCM_ADDR_WIDTH){1'b0}},base_q};
      assign router_valid = pending;
      always @(posedge clk or negedge reset_n) begin
        if (!reset_n) pending <= 1'b0;
        else if (enqueue) pending <= 1'b1;
        else if (router_valid && router_ready) pending <= 1'b0;
      end
      always @(posedge clk) begin
        if (enqueue) begin
          payload_q <= lane_payload[lane];
          base_q <= int_dtcm_base_snapshot[DTCM_ADDR_WIDTH+2:0];
        end
      end
    end else
`endif
    begin: g_direct_route
      assign router_valid = lane_valid[lane];
      assign lane_ready[lane] = router_ready;
      assign router_payload = lane_payload[lane];
      assign router_base = dtcm_base;
      assign lane_resp[lane] = router_resp;
      assign lane_error[lane] = router_error;
      assign lane_rdata[lane] = router_rdata;
      assign {c_valid[lane],c_addr[lane],c_data[lane],c_strb[lane],c_write[lane]} =
        {router_cache_valid,router_cache_addr,router_cache_data,router_cache_strb,router_cache_write};
    end
    edge_32_dtcm_router #(.DTCM_ADDR_WIDTH(DTCM_ADDR_WIDTH),.DTCM_ONLY(DTCM_ONLY)) route(
      .clk(clk),.reset_n(reset_n),.dtcm_base(router_base),.dtcm_mask(dtcm_mask),
      .dtcm_enable(ENABLE_DTCM_PORT && dtcm_enable),
      .core_req_valid(router_valid),.core_req_ready(router_ready),
      .core_req_addr(router_payload[71:40]),.core_req_wdata(router_payload[39:8]),
      .core_req_wstrb(router_payload[7:4]),.core_req_size(router_payload[3:2]),
      .core_req_signed(router_payload[1]),.core_req_write(router_payload[0]),
      .core_resp_valid(router_resp),.core_resp_error(router_error),.core_resp_rdata(router_rdata),
      .cache_req_valid(router_cache_valid),.cache_req_ready(!DTCM_ONLY && c_ready[lane]),
      .cache_req_addr(router_cache_addr),.cache_req_wdata(router_cache_data),
      .cache_req_wstrb(router_cache_strb),.cache_req_write(router_cache_write),
      .cache_resp_valid(!DTCM_ONLY && c_resp[lane]),.cache_resp_error(cache_core_resp_error),
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
