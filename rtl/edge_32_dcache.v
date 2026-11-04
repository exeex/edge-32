// Stable RV32 scalar cache boundary v1. Owns adapter completion and cache state.
// Port widths/names are fixed; capacity and metadata implementation are internal.
module edge_32_dcache #(
  parameter ICACHE_BYTES=32768, parameter DCACHE_BYTES=32768,
  parameter METADATA_SYNC_READ=0,
`ifdef EDGE_DCACHE_REGISTERED_LOOKUP
  parameter LOOKUP_REGISTERED=1,
`else
  parameter LOOKUP_REGISTERED=METADATA_SYNC_READ,
`endif
`ifdef EDGE_DCACHE_HYBRID_LOOKUP
  parameter LOOKUP_HYBRID=1
`else
  parameter LOOKUP_HYBRID=0
`endif
)(
  input wire clk,
  input wire reset_n,
  input wire core_dmem_req_valid,
  output wire core_dmem_req_ready,
  input wire core_dmem_req_write,
  input wire [31:0] core_dmem_req_addr,
  input wire [31:0] core_dmem_req_wdata,
  input wire [3:0] core_dmem_req_wstrb,
  input wire [1:0] core_dmem_req_size,
  input wire core_dmem_req_signed,
  output wire core_dmem_resp_valid,
  output wire core_dmem_resp_error,
  output wire [31:0] core_dmem_resp_rdata,
  input wire cache_op_valid,
  output wire cache_op_ready,
  input wire cache_op_is_va,
  input wire [1:0] cache_op_kind,
  input wire [31:0] cache_op_addr,
  output wire cache_op_complete_valid,
  output wire dmem_refill_req_valid,
  input wire dmem_refill_req_ready,
  output wire [31:0] dmem_refill_req_addr,
  input wire dmem_refill_resp_valid,
  output wire dmem_refill_resp_ready,
  input wire [127:0] dmem_refill_resp_data,
  input wire dmem_refill_resp_last,
  input wire dmem_refill_resp_error,
  output wire dmem_clean_wb_valid,
  input wire dmem_clean_wb_ready,
  output wire [31:0] dmem_clean_wb_addr,
  output wire [127:0] dmem_clean_wb_data,
  output wire dmem_clean_wb_last,
  input wire dmem_clean_wb_complete,
  output wire debug_dcache_load_miss_pending
);
  wire dcache_load_req_valid;
  wire dcache_load_req_ready;
  wire [7:0] dcache_load_req_seq_id;
  wire [3:0] dcache_load_req_epoch;
  wire [31:0] dcache_load_req_addr;
  wire [1:0] dcache_load_req_size;
  wire dcache_load_req_signed;
  wire dcache_load_resp_valid;
  wire dcache_load_resp_error;
  wire [31:0] dcache_load_resp_value;
  wire dcache_store_req_valid;
  wire dcache_store_req_ready;
  wire [7:0] dcache_store_req_seq_id;
  wire [3:0] dcache_store_req_epoch;
  wire [31:0] dcache_store_req_addr;
  wire [1:0] dcache_store_req_size;
  wire [31:0] dcache_store_req_data;
  wire [3:0] dcache_store_req_wstrb;

  edge_32_dcache_adapter dcache_adapter (
    .clk(clk), .reset_n(reset_n),
    .core_req_valid(core_dmem_req_valid),
    .core_req_ready(core_dmem_req_ready),
    .core_req_write(core_dmem_req_write),
    .core_req_addr(core_dmem_req_addr),
    .core_req_wdata(core_dmem_req_wdata),
    .core_req_wstrb(core_dmem_req_wstrb),
    .core_req_size(core_dmem_req_size),
    .core_req_signed(core_dmem_req_signed),
    .core_resp_valid(core_dmem_resp_valid),
    .core_resp_error(core_dmem_resp_error),
    .core_resp_rdata(core_dmem_resp_rdata),
    .cache_load_req_valid(dcache_load_req_valid),
    .cache_load_req_ready(dcache_load_req_ready),
    .cache_load_req_seq_id(dcache_load_req_seq_id),
    .cache_load_req_epoch(dcache_load_req_epoch),
    .cache_load_req_addr(dcache_load_req_addr),
    .cache_load_req_size(dcache_load_req_size),
    .cache_load_req_signed(dcache_load_req_signed),
    .cache_load_resp_valid(dcache_load_resp_valid),
    .cache_load_resp_error(dcache_load_resp_error),
    .cache_load_resp_value(dcache_load_resp_value),
    .cache_store_req_valid(dcache_store_req_valid),
    .cache_store_req_ready(dcache_store_req_ready),
    .cache_store_req_seq_id(dcache_store_req_seq_id),
    .cache_store_req_epoch(dcache_store_req_epoch),
    .cache_store_req_addr(dcache_store_req_addr),
    .cache_store_req_size(dcache_store_req_size),
    .cache_store_req_data(dcache_store_req_data),
    .cache_store_req_wstrb(dcache_store_req_wstrb)
  );

  edge_dcache #(
    .SEQ_ID_WIDTH(8), .EPOCH_WIDTH(4), .VALUE_WIDTH(32),
    .METADATA_SYNC_READ(METADATA_SYNC_READ),
    .LOOKUP_REGISTERED(LOOKUP_REGISTERED), .LOOKUP_HYBRID(LOOKUP_HYBRID),
    .ICACHE_BYTES(ICACHE_BYTES), .DCACHE_BYTES(DCACHE_BYTES)
  ) dcache (
    .forever_cpuclk(clk), .cpurst_b(reset_n),
    .redirect_kill_valid(1'b0), .redirect_kill_seq_id(8'd0),
    .redirect_kill_epoch(4'd0),
    .backend_load_pause(1'b0), .backend_store_pause(1'b0),
    .lsu_load_req_valid(dcache_load_req_valid),
    .lsu_load_req_ready(dcache_load_req_ready),
    .lsu_load_req_seq_id(dcache_load_req_seq_id),
    .lsu_load_req_epoch(dcache_load_req_epoch),
    .lsu_load_req_addr(dcache_load_req_addr),
    .lsu_load_req_size(dcache_load_req_size),
    .lsu_load_req_signed(dcache_load_req_signed),
    .lsu_load_req1_valid(1'b0), .lsu_load_req1_ready(),
    .lsu_load_req1_seq_id(8'd0), .lsu_load_req1_epoch(4'd0),
    .lsu_load_req1_addr(32'd0), .lsu_load_req1_size(2'd0),
    .lsu_load_req1_signed(1'b0),
    .lsu_load_resp_valid(dcache_load_resp_valid),
    .lsu_load_resp_seq_id(), .lsu_load_resp_epoch(),
    .lsu_load_resp_error(dcache_load_resp_error),
    .lsu_load_resp_value(dcache_load_resp_value),
    .lsu_store_req_valid(dcache_store_req_valid),
    .lsu_store_req_ready(dcache_store_req_ready),
    .lsu_store_req_seq_id(dcache_store_req_seq_id),
    .lsu_store_req_epoch(dcache_store_req_epoch),
    .lsu_store_req_addr(dcache_store_req_addr),
    .lsu_store_req_size(dcache_store_req_size),
    .lsu_store_req_data(dcache_store_req_data),
    .lsu_store_req_wstrb(dcache_store_req_wstrb),
    .lsu_store_req1_valid(1'b0), .lsu_store_req1_ready(),
    .lsu_store_req1_seq_id(8'd0), .lsu_store_req1_epoch(4'd0),
    .lsu_store_req1_addr(32'd0), .lsu_store_req1_size(2'd0),
    .lsu_store_req1_data(32'd0), .lsu_store_req1_wstrb(4'd0),
    .cache_op_valid(cache_op_valid), .cache_op_ready(cache_op_ready),
    .cache_op_is_va(cache_op_is_va),
    .cache_op_kind(cache_op_kind), .cache_op_addr(cache_op_addr),
    .cache_op_seq_id(8'd0), .cache_op_epoch(4'd0),
    .cache_op_complete_valid(cache_op_complete_valid), .cache_op_complete_seq_id(),
    .cache_op_complete_epoch(),
    .clean_wb_valid(dmem_clean_wb_valid),
    .clean_wb_ready(dmem_clean_wb_ready),
    .clean_wb_addr(dmem_clean_wb_addr), .clean_wb_data(dmem_clean_wb_data),
    .clean_wb_last(dmem_clean_wb_last),
    .clean_wb_complete(dmem_clean_wb_complete),
    .refill_req_valid(dmem_refill_req_valid),
    .refill_req_ready(dmem_refill_req_ready),
    .refill_req_addr(dmem_refill_req_addr),
    .refill_resp_valid(dmem_refill_resp_valid),
    .refill_resp_ready(dmem_refill_resp_ready),
    .refill_resp_data(dmem_refill_resp_data),
    .refill_resp_last(dmem_refill_resp_last),
    .refill_resp_error(dmem_refill_resp_error),
    .debug_icache_bytes(), .debug_dcache_bytes(), .debug_load_pending(),
    .debug_load_miss_pending(debug_dcache_load_miss_pending),
    .debug_store_fire(), .store_predict_phase(),
    .store_predict_mem_active(), .store_predict_backend_blocked(),
    .debug_cache_op_fire(), .debug_cache_op_kind(),
    .debug_cache_op_is_va()
  );
endmodule
