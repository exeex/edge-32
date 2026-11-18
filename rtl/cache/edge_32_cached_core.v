`ifdef EDGE32_EXTERNAL_FPU
`include "edge32_external_fpu.svh"
`endif
`timescale 1ns/1ps

// Bootable lite scalar core composed with the maintained Edge I/D caches.
// The exposed refill/writeback ports are the cache-to-BIU boundary used by the
// later edge_core_top-compatible wrapper.
module edge_32_cached_core #(
  parameter PC_WIDTH = 32,
  parameter ICACHE_BYTES = 16384,
  parameter DCACHE_BYTES = 16384,
  parameter DTCM_ADDR_WIDTH = 14,
  parameter ENABLE_DTCM_PORT = 0,
  parameter ENABLE_FPU = 0,
  parameter AUTO_START = 1,
  parameter [46:0] EDGE_ASIC_ID = 47'd0,
  parameter DCACHE_METADATA_SYNC_READ = 0
) (
`ifdef EDGE32_EXTERNAL_FPU
  `EDGE32_FPU_PORTS
`endif
`ifdef EDGE32_DEBUG
  input wire debug_step, debug_resume, debug_pc_write,
  input wire [PC_WIDTH-1:0] debug_pc_wdata,
  output wire debug_control_ack,
  input wire debug_gpr_write,
  input wire [31:0] debug_gpr_wdata,
  input wire debug_break_enable,
  input wire [PC_WIDTH-1:0] debug_break_pc,
  output wire [PC_WIDTH-1:0] debug_pc,
  output wire [2:0] debug_cause,
  input wire debug_gpr_req_valid,
  output wire debug_gpr_req_ready,
  input wire [4:0] debug_gpr_addr,
  output wire debug_gpr_resp_valid,
  input wire debug_gpr_resp_ready,
  output wire [31:0] debug_gpr_data,
  output wire debug_gpr_allowed,
  input wire debug_dcache_invalidate,
  input wire [31:0] debug_dcache_addr,
  input wire debug_dcache_req_valid,
  output wire debug_dcache_req_ready, debug_dcache_complete,
  input wire [31:0] debug_icache_addr,
  input wire debug_icache_req_valid,
  output wire debug_icache_req_ready, debug_icache_complete,
`endif
  input  wire                   clk,
  input  wire                   reset_n,
  input  wire [PC_WIDTH-1:0]    boot_pc,
  input  wire                   core_start,
  input  wire                   core_force_stop,
  output wire [31:0]            icache_address_header,
  output wire [31:0]            dcache_address_header,

  output wire                   imem_refill_req_valid,
  input  wire                   imem_refill_req_ready,
  output wire [PC_WIDTH-1:0]    imem_refill_req_addr,
  input  wire                   imem_refill_resp_valid,
  output wire                   imem_refill_resp_ready,
  input  wire [127:0]           imem_refill_resp_data,
  input  wire                   imem_refill_resp_last,
  input  wire                   imem_refill_resp_error,

  output wire                   dmem_refill_req_valid,
  input  wire                   dmem_refill_req_ready,
  output wire [31:0]            dmem_refill_req_addr,
  input  wire                   dmem_refill_resp_valid,
  output wire                   dmem_refill_resp_ready,
  input  wire [127:0]           dmem_refill_resp_data,
  input  wire                   dmem_refill_resp_last,
  input  wire                   dmem_refill_resp_error,

  output wire                   dmem_clean_wb_valid,
  input  wire                   dmem_clean_wb_ready,
  output wire [31:0]            dmem_clean_wb_addr,
  output wire [127:0]           dmem_clean_wb_data,
  output wire                   dmem_clean_wb_last,
  input  wire                   dmem_clean_wb_complete,

  input  wire [63:0]            dtcm_base,
  input  wire [63:0]            dtcm_mask,
  input  wire                   dtcm_enable,
  output wire                   dtcm_lsu_req,
  input  wire                   dtcm_lsu_ready,
  output wire                   dtcm_lsu_we,
  output wire [DTCM_ADDR_WIDTH-1:0] dtcm_lsu_addr,
  output wire [63:0]            dtcm_lsu_wdata,
  output wire [7:0]             dtcm_lsu_wstrb,
  input  wire                   dtcm_lsu_rvalid,
  input  wire [63:0]            dtcm_lsu_rdata,

  output wire                   accel_req_valid,
  input  wire                   accel_req_ready,
  output wire [31:0]            accel_req_inst,
  output wire [63:0]            accel_req_src0,
  output wire [63:0]            accel_req_src1,
  input  wire                   accel_resp_valid,
  input  wire                   accel_resp_error,
  input  wire [63:0]            accel_resp_value,

  output wire                   halted,
  output wire                   illegal,
  output wire [63:0]            debug_x31,
  output wire [63:0]            cycle_count,
  output wire [63:0]            instret_count,
  output wire                   putchar_valid,
  output wire [7:0]             putchar_char,
  output wire                   debug_icache_hit,
  output wire                   debug_icache_miss_pending,
  output wire                   debug_dcache_load_miss_pending
);
  wire core_imem_req_valid;
  wire core_imem_req_ready;
  wire [PC_WIDTH-1:0] core_imem_req_addr;
  wire core_imem_resp_valid;
  wire [31:0] core_imem_resp_data;
  wire core_imem_resp_error;

  wire core_dmem_req_valid;
  wire core_dmem_req_ready;
  wire core_dmem_req_write;
  wire [31:0] core_dmem_req_addr;
  wire [31:0] core_dmem_req_wdata;
  wire [3:0] core_dmem_req_wstrb;
  wire [1:0] core_dmem_req_size;
  wire core_dmem_req_signed;
  wire core_dmem_resp_valid;
  wire core_dmem_resp_error;
  wire [31:0] core_dmem_resp_rdata;
`ifdef EDGE32_SPLIT_LSU
  wire fp_dmem_req_valid, fp_dmem_req_ready;
  wire [71:0] fp_dmem_req_payload;
  wire fp_dmem_resp_valid, fp_dmem_resp_error;
  wire [31:0] fp_dmem_resp_rdata;
`endif
`ifdef EDGE32_INT_DTCM_PIPE
  wire int_dtcm_hit;
  wire [31:0] int_dtcm_base_snapshot;
`endif
  wire [1:0] cache_core_req_size;
  wire cache_core_req_signed;
  wire cache_core_req_valid,cache_core_req_ready,cache_core_req_write;
  wire [31:0] cache_core_req_addr,cache_core_req_wdata;
  wire [3:0] cache_core_req_wstrb;
  wire cache_core_resp_valid,cache_core_resp_error;
  wire [31:0] cache_core_resp_rdata;

`ifdef EDGE32_DEBUG
  wire debug_inv_ready, debug_inv_complete;
  wire debug_clean_ready, debug_clean_complete;
  reg debug_inv_owned_q, debug_clean_owned_q;
  wire debug_inv_select = debug_icache_req_valid && !debug_inv_owned_q;
  wire debug_clean_select = debug_dcache_req_valid && !debug_clean_owned_q;
  assign debug_icache_req_ready = debug_inv_ready && !debug_inv_owned_q;
  assign debug_icache_complete = debug_inv_owned_q && debug_inv_complete;
  assign debug_dcache_req_ready = debug_clean_ready && !debug_clean_owned_q;
  assign debug_dcache_complete = debug_clean_owned_q && debug_clean_complete;
  assign icache_invalidate_ready = debug_inv_ready && !debug_icache_req_valid && !debug_inv_owned_q;
  assign icache_invalidate_complete = debug_inv_complete && !debug_inv_owned_q;
  assign cache_op_ready = debug_clean_ready && !debug_dcache_req_valid && !debug_clean_owned_q;
  assign cache_op_complete_valid = debug_clean_complete && !debug_clean_owned_q;
  always @(posedge clk) begin
    if (!reset_n) begin debug_inv_owned_q<=0; debug_clean_owned_q<=0; end
    else begin
      if (debug_icache_req_valid && debug_icache_req_ready) debug_inv_owned_q<=1;
      else if (debug_icache_complete) debug_inv_owned_q<=0;
      if (debug_dcache_req_valid && debug_dcache_req_ready) debug_clean_owned_q<=1;
      else if (debug_dcache_complete) debug_clean_owned_q<=0;
    end
  end
`endif
  wire icache_invalidate_valid;
  wire icache_invalidate_ready;
  wire icache_invalidate_complete;

  wire cache_op_valid,cache_op_ready,cache_op_is_va;
  wire [1:0] cache_op_kind;
  wire [31:0] cache_op_addr;
  wire cache_op_complete_valid;

  edge_32_core #(
    .PC_WIDTH(PC_WIDTH), .DMEM_RESP_FORMATTED(1),
    .ENABLE_FPU(ENABLE_FPU),
    .AUTO_START(AUTO_START),
    .EDGE_ASIC_ID(EDGE_ASIC_ID)
  ) core (
`ifdef EDGE32_DEBUG
    .debug_step(debug_step),
    .debug_resume(debug_resume),
    .debug_pc_write(debug_pc_write),
    .debug_pc_wdata(debug_pc_wdata),
    .debug_control_ack(debug_control_ack),
    .debug_gpr_write(debug_gpr_write),
    .debug_gpr_wdata(debug_gpr_wdata),
    .debug_break_enable(debug_break_enable),
    .debug_break_pc(debug_break_pc),
    .debug_pc(debug_pc),
    .debug_cause(debug_cause),
    .debug_gpr_req_valid(debug_gpr_req_valid),
    .debug_gpr_req_ready(debug_gpr_req_ready),
    .debug_gpr_addr(debug_gpr_addr),
    .debug_gpr_resp_valid(debug_gpr_resp_valid),
    .debug_gpr_resp_ready(debug_gpr_resp_ready),
    .debug_gpr_data(debug_gpr_data),
    .debug_gpr_allowed(debug_gpr_allowed),
`endif

`ifdef EDGE32_EXTERNAL_FPU
    `EDGE32_FPU_CONNECT
`endif
    .clk(clk), .reset_n(reset_n),
    .boot_pc(boot_pc),.core_start(core_start),
    .core_force_stop(core_force_stop),
    .icache_address_header(icache_address_header),
    .dcache_address_header(dcache_address_header),
    .imem_req_valid(core_imem_req_valid),
    .imem_req_ready(core_imem_req_ready),
    .imem_req_addr(core_imem_req_addr),
    .imem_resp_valid(core_imem_resp_valid),
    .imem_resp_data(core_imem_resp_data),
    .imem_resp_error(core_imem_resp_error),
    .dmem_req_valid(core_dmem_req_valid),
`ifdef EDGE32_SPLIT_LSU
    .fp_dmem_req_valid(fp_dmem_req_valid), .fp_dmem_req_ready(fp_dmem_req_ready),
    .fp_dmem_req_payload(fp_dmem_req_payload),
    .fp_dmem_resp_valid(fp_dmem_resp_valid), .fp_dmem_resp_error(fp_dmem_resp_error),
    .fp_dmem_resp_rdata(fp_dmem_resp_rdata),
`endif
`ifdef EDGE32_INT_DTCM_PIPE
    .int_dtcm_base(dtcm_base),.int_dtcm_mask(dtcm_mask),
    .int_dtcm_enable(ENABLE_DTCM_PORT && dtcm_enable),.int_dtcm_hit(int_dtcm_hit),
    .int_dtcm_base_snapshot(int_dtcm_base_snapshot),
`endif
    .dmem_req_ready(core_dmem_req_ready),
    .dmem_req_write(core_dmem_req_write),
    .dmem_req_addr(core_dmem_req_addr),
    .dmem_req_wdata(core_dmem_req_wdata),
    .dmem_req_wstrb(core_dmem_req_wstrb),
    .dmem_req_size(core_dmem_req_size),
    .dmem_req_signed(core_dmem_req_signed),
    .dmem_resp_valid(core_dmem_resp_valid),
    .dmem_resp_error(core_dmem_resp_error),
    .dmem_resp_rdata(core_dmem_resp_rdata),
    .cache_op_valid(cache_op_valid),.cache_op_ready(cache_op_ready),
    .cache_op_is_va(cache_op_is_va),.cache_op_kind(cache_op_kind),
    .cache_op_addr(cache_op_addr),
    .cache_op_complete_valid(cache_op_complete_valid),
    .icache_invalidate_valid(icache_invalidate_valid),
    .icache_invalidate_ready(icache_invalidate_ready),
    .icache_invalidate_complete(icache_invalidate_complete),
    .accel_req_valid(accel_req_valid), .accel_req_ready(accel_req_ready),
    .accel_req_inst(accel_req_inst), .accel_req_src0(accel_req_src0),
    .accel_req_src1(accel_req_src1), .accel_resp_valid(accel_resp_valid),
    .accel_resp_error(accel_resp_error), .accel_resp_value(accel_resp_value),
    .halted(halted), .illegal(illegal), .debug_x31(debug_x31),
    .cycle_count(cycle_count), .instret_count(instret_count),
    .putchar_valid(putchar_valid), .putchar_char(putchar_char)
  );

`ifdef EDGE32_SPLIT_LSU
  `include "ex/lsu_doors.svh"
`else
  assign cache_core_req_size = core_dmem_req_size;
  assign cache_core_req_signed = core_dmem_req_signed;
  generate if(ENABLE_DTCM_PORT) begin: g_dtcm
    edge_32_dtcm_router #(.DTCM_ADDR_WIDTH(DTCM_ADDR_WIDTH)) dtcm_router(
      .clk(clk),.reset_n(reset_n),.dtcm_base(dtcm_base),.dtcm_mask(dtcm_mask),
      .dtcm_enable(dtcm_enable),.core_req_valid(core_dmem_req_valid),
      .core_req_ready(core_dmem_req_ready),.core_req_write(core_dmem_req_write),
      .core_req_addr(core_dmem_req_addr),.core_req_wdata(core_dmem_req_wdata),
      .core_req_wstrb(core_dmem_req_wstrb),.core_resp_valid(core_dmem_resp_valid),
      .core_resp_error(core_dmem_resp_error),.core_resp_rdata(core_dmem_resp_rdata),
      .cache_req_valid(cache_core_req_valid),.cache_req_ready(cache_core_req_ready),
      .cache_req_write(cache_core_req_write),.cache_req_addr(cache_core_req_addr),
      .cache_req_wdata(cache_core_req_wdata),.cache_req_wstrb(cache_core_req_wstrb),
      .core_req_size(core_dmem_req_size),.core_req_signed(core_dmem_req_signed),
      .cache_resp_valid(cache_core_resp_valid),.cache_resp_error(cache_core_resp_error),
      .cache_resp_rdata(cache_core_resp_rdata),.dtcm_req(dtcm_lsu_req),
      .dtcm_ready(dtcm_lsu_ready),.dtcm_we(dtcm_lsu_we),.dtcm_addr(dtcm_lsu_addr),
      .dtcm_wdata(dtcm_lsu_wdata),.dtcm_wstrb(dtcm_lsu_wstrb),
      .dtcm_rvalid(dtcm_lsu_rvalid),.dtcm_rdata(dtcm_lsu_rdata));
  end else begin: g_no_dtcm
    assign cache_core_req_valid=core_dmem_req_valid;
    assign core_dmem_req_ready=cache_core_req_ready;
    assign cache_core_req_write=core_dmem_req_write;
    assign cache_core_req_addr=core_dmem_req_addr;
    assign cache_core_req_wdata=core_dmem_req_wdata;
    assign cache_core_req_wstrb=core_dmem_req_wstrb;
    assign core_dmem_resp_valid=cache_core_resp_valid;
    assign core_dmem_resp_error=cache_core_resp_error;
    assign core_dmem_resp_rdata=cache_core_resp_rdata;
    assign dtcm_lsu_req=1'b0; assign dtcm_lsu_we=1'b0;
    assign dtcm_lsu_addr={DTCM_ADDR_WIDTH{1'b0}};
    assign dtcm_lsu_wdata=64'b0;
    assign dtcm_lsu_wstrb=8'b0;
  end endgenerate

`endif

  edge_32_icache #(.ICACHE_BYTES(ICACHE_BYTES)
`ifdef EDGE32_DEBUG
    , .ENABLE_LINE_INVALIDATE(1)
`endif
  ) icache_boundary (
    .clk(clk),
    .reset_n(reset_n),
    .core_imem_req_valid(core_imem_req_valid),
    .core_imem_req_ready(core_imem_req_ready),
    .core_imem_req_addr(core_imem_req_addr),
    .core_imem_resp_valid(core_imem_resp_valid),
    .core_imem_resp_data(core_imem_resp_data),
    .core_imem_resp_error(core_imem_resp_error),
`ifdef EDGE32_DEBUG
    .icache_invalidate_valid((icache_invalidate_valid && !debug_icache_req_valid && !debug_inv_owned_q) || debug_inv_select),
    .icache_invalidate_line(debug_inv_select), .icache_invalidate_addr(debug_icache_addr),
    .icache_invalidate_ready(debug_inv_ready), .icache_invalidate_complete(debug_inv_complete),
`else
    .icache_invalidate_valid(icache_invalidate_valid),
    .icache_invalidate_line(1'b0), .icache_invalidate_addr(32'd0),
    .icache_invalidate_ready(icache_invalidate_ready),
    .icache_invalidate_complete(icache_invalidate_complete),
`endif
    .imem_refill_req_valid(imem_refill_req_valid),
    .imem_refill_req_ready(imem_refill_req_ready),
    .imem_refill_req_addr(imem_refill_req_addr),
    .imem_refill_resp_valid(imem_refill_resp_valid),
    .imem_refill_resp_ready(imem_refill_resp_ready),
    .imem_refill_resp_data(imem_refill_resp_data),
    .imem_refill_resp_last(imem_refill_resp_last),
    .imem_refill_resp_error(imem_refill_resp_error),
    .debug_icache_hit(debug_icache_hit),
    .debug_icache_miss_pending(debug_icache_miss_pending)
  );

  edge_32_dcache #(
    .ICACHE_BYTES(ICACHE_BYTES), .METADATA_SYNC_READ(DCACHE_METADATA_SYNC_READ),
    .DCACHE_BYTES(DCACHE_BYTES)
  ) dcache_boundary (
    .clk(clk),
    .reset_n(reset_n),
    .core_dmem_req_valid(cache_core_req_valid),
    .core_dmem_req_ready(cache_core_req_ready),
    .core_dmem_req_write(cache_core_req_write),
    .core_dmem_req_addr(cache_core_req_addr),
    .core_dmem_req_wdata(cache_core_req_wdata),
    .core_dmem_req_wstrb(cache_core_req_wstrb),
    .core_dmem_req_size(cache_core_req_size),
    .core_dmem_req_signed(cache_core_req_signed),
    .core_dmem_resp_valid(cache_core_resp_valid),
    .core_dmem_resp_error(cache_core_resp_error),
    .core_dmem_resp_rdata(cache_core_resp_rdata),
`ifdef EDGE32_DEBUG
    .cache_op_valid((cache_op_valid && !debug_dcache_req_valid && !debug_clean_owned_q) || debug_clean_select),
    .cache_op_ready(debug_clean_ready), .cache_op_is_va(debug_clean_select ? 1'b1 : cache_op_is_va),
    .cache_op_kind(debug_clean_select ? {debug_dcache_invalidate,1'b1} : cache_op_kind),
    .cache_op_addr(debug_clean_select ? debug_dcache_addr : cache_op_addr),
    .cache_op_complete_valid(debug_clean_complete),
`else
    .cache_op_valid(cache_op_valid),
    .cache_op_ready(cache_op_ready),
    .cache_op_is_va(cache_op_is_va),
    .cache_op_kind(cache_op_kind),
    .cache_op_addr(cache_op_addr),
    .cache_op_complete_valid(cache_op_complete_valid),
`endif
    .dmem_refill_req_valid(dmem_refill_req_valid),
    .dmem_refill_req_ready(dmem_refill_req_ready),
    .dmem_refill_req_addr(dmem_refill_req_addr),
    .dmem_refill_resp_valid(dmem_refill_resp_valid),
    .dmem_refill_resp_ready(dmem_refill_resp_ready),
    .dmem_refill_resp_data(dmem_refill_resp_data),
    .dmem_refill_resp_last(dmem_refill_resp_last),
    .dmem_refill_resp_error(dmem_refill_resp_error),
    .dmem_clean_wb_valid(dmem_clean_wb_valid),
    .dmem_clean_wb_ready(dmem_clean_wb_ready),
    .dmem_clean_wb_addr(dmem_clean_wb_addr),
    .dmem_clean_wb_data(dmem_clean_wb_data),
    .dmem_clean_wb_last(dmem_clean_wb_last),
    .dmem_clean_wb_complete(dmem_clean_wb_complete),
    .debug_dcache_load_miss_pending(debug_dcache_load_miss_pending)
  );
endmodule
