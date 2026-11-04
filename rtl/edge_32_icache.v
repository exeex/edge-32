// Fixed RV32 I-cache boundary: scalar fetch, 128-bit AXI refill, invalidate owner.
module edge_32_icache #(
  parameter ICACHE_BYTES=32768
)(
  input wire clk,
  input wire reset_n,
  input wire core_imem_req_valid,
  output wire core_imem_req_ready,
  input wire [31:0] core_imem_req_addr,
  output wire core_imem_resp_valid,
  output wire [31:0] core_imem_resp_data,
  output wire core_imem_resp_error,
  input wire icache_invalidate_valid,
  output wire icache_invalidate_ready,
  output wire icache_invalidate_complete,
  output wire imem_refill_req_valid,
  input wire imem_refill_req_ready,
  output wire [31:0] imem_refill_req_addr,
  input wire imem_refill_resp_valid,
  output wire imem_refill_resp_ready,
  input wire [127:0] imem_refill_resp_data,
  input wire imem_refill_resp_error,
  output wire debug_icache_hit,
  output wire debug_icache_miss_pending
);
  wire icache_req_valid;
  wire icache_req_ready;
  wire [31:0] icache_req_addr;
  wire icache_resp_valid;
  wire icache_resp_ready;
  wire [31:0] icache_resp_bits;
  wire icache_resp_error;
  wire icache_array_req_ready;
  wire icache_invalidate_busy;
  reg icache_invalidate_inflight_q;

  edge_32_icache_adapter #(.PC_WIDTH(32)) icache_adapter (
    .clk(clk), .reset_n(reset_n),
    .core_req_valid(core_imem_req_valid),
    .core_req_ready(core_imem_req_ready),
    .core_req_addr(core_imem_req_addr),
    .core_resp_valid(core_imem_resp_valid),
    .core_resp_data(core_imem_resp_data),
    .core_resp_error(core_imem_resp_error),
    .cache_req_valid(icache_req_valid),
    .cache_req_ready(icache_req_ready), .cache_req_addr(icache_req_addr),
    .cache_resp_valid(icache_resp_valid),
    .cache_resp_ready(icache_resp_ready), .cache_resp_bits(icache_resp_bits),
    .cache_resp_error(icache_resp_error)
  );

  edge_ifu_icache #(
    .PC_WIDTH(32), .ICACHE_BYTES(ICACHE_BYTES), .LINE_BYTES(16)
  ) icache (
    .forever_cpuclk(clk), .cpurst_b(reset_n),
    .fetch_req_valid(icache_req_valid && !icache_invalidate_valid &&
                     !icache_invalidate_inflight_q &&
                     !icache_invalidate_busy),
    .fetch_req_ready(icache_array_req_ready),
    .fetch_req_addr(icache_req_addr),
    .invalidate_valid(icache_invalidate_valid),
    .invalidate_ready(icache_invalidate_ready),
    .fetch_resp_valid(icache_resp_valid),
    .fetch_resp_ready(icache_resp_ready), .fetch_resp_bits(icache_resp_bits),
    .fetch_resp_error(icache_resp_error),
    .imem_req_valid(imem_refill_req_valid),
    .imem_req_ready(imem_refill_req_ready),
    .imem_req_addr(imem_refill_req_addr),
    .imem_resp_valid(imem_refill_resp_valid),
    .imem_resp_ready(imem_refill_resp_ready),
    .imem_resp_bits(imem_refill_resp_data),
    .imem_resp_error(imem_refill_resp_error),
    .debug_icache_bytes(), .debug_hit(debug_icache_hit),
    .debug_miss_pending(debug_icache_miss_pending),
    .debug_invalidate_busy(icache_invalidate_busy)
  );

  assign icache_req_ready=icache_array_req_ready&&
    !icache_invalidate_valid&&!icache_invalidate_inflight_q&&
    !icache_invalidate_busy;
  assign icache_invalidate_complete=
    icache_invalidate_inflight_q&&!icache_invalidate_busy;

  always @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
      icache_invalidate_inflight_q<=1'b0;
    end else begin
      if(icache_invalidate_valid&&icache_invalidate_ready)
        icache_invalidate_inflight_q<=1'b1;
      else if(icache_invalidate_complete)
        icache_invalidate_inflight_q<=1'b0;
    end
  end

endmodule
