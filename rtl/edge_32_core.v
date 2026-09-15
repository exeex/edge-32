`timescale 1ns/1ps
// RV32IM_Zba IF/predecode -> ID/read -> EX/execute -> WB/retire core.
module edge_32_core #(
  parameter PC_WIDTH = 32,
  parameter DMEM_RESP_FORMATTED = 0,
  parameter ENABLE_FPU = 0,
  parameter AUTO_START = 1,
  parameter [46:0] EDGE_ASIC_ID = 47'd0
) (
  input wire clk, input wire reset_n,
  input wire [PC_WIDTH-1:0] boot_pc,
  input wire core_start,input wire core_force_stop,
  output wire [31:0] icache_address_header,
  output wire [31:0] dcache_address_header,
  output wire imem_req_valid, input wire imem_req_ready,
  output wire [PC_WIDTH-1:0] imem_req_addr,
  input wire imem_resp_valid, input wire [31:0] imem_resp_data,
  input wire imem_resp_error,
  output wire dmem_req_valid, input wire dmem_req_ready,
  output wire dmem_req_write, output wire [63:0] dmem_req_addr,
  output wire [63:0] dmem_req_wdata, output wire [7:0] dmem_req_wstrb,
  output wire [1:0] dmem_req_size, output wire dmem_req_signed,
  input wire dmem_resp_valid, input wire dmem_resp_error,
  input wire [63:0] dmem_resp_rdata,
  output wire cache_op_valid,input wire cache_op_ready,
  output wire cache_op_is_va,output wire [1:0] cache_op_kind,
  output wire [63:0] cache_op_addr,
  input wire cache_op_complete_valid,
  output wire icache_invalidate_valid,input wire icache_invalidate_ready,
  input wire icache_invalidate_complete,
  output wire accel_req_valid, input wire accel_req_ready,
  output wire [31:0] accel_req_inst,
  output wire [63:0] accel_req_src0, output wire [63:0] accel_req_src1,
  input wire accel_resp_valid, input wire accel_resp_error,
  input wire [63:0] accel_resp_value,
  output reg halted, output reg illegal,
  output wire [63:0] debug_x31, output wire [63:0] cycle_count,
  output wire [63:0] instret_count
);
  wire core_start_i = AUTO_START ? 1'b0 : core_start;
  wire core_force_stop_i = AUTO_START ? 1'b0 : core_force_stop;

  // Stage entries share this module scope; they add no hardware hierarchy.
  `include "edge_32_if.svh"
  `include "edge_32_id.svh"
  `include "edge_32_ex.svh"
  `include "edge_32_wb.svh"
endmodule
