// WB stage: explicit ports; implementation is private to this module.
module edge_32_wb_stage (
  input wire clk,
  input wire core_force_stop_i,
  input wire core_start_i,
  input wire edge32_stage::completion_payload_t ex_wb,
  input wire ex_wb_fire,
  input wire reset_n,
  output reg [31:0] dcache_address_header_q,
  output reg halted,
  output reg [31:0] icache_address_header_q,
  output reg illegal,
  output wire wb_commit,
  output reg wb_dcache_header_q,
  output reg wb_fault_q,
  output reg wb_icache_header_q,
  output reg wb_pending_q,
  output reg [4:0] wb_rd_q,
  output wire wb_terminal,
  output wire wb_valid,
  output wire [31:0] wb_value_q
);
  reg wb_fast_q;
  reg [31:0] wb_fast_value_q;
  reg wb_gpr_q;
  reg wb_halt_q;
  reg [31:0] wb_header_value_q;
  reg [31:0] wb_other_value_q;

`include "wb/completion_state.svh"
`include "wb/capture.svh"
`include "wb/retirement.svh"
  assign wb_value_q = wb_fast_q ? wb_fast_value_q : wb_other_value_q;
  assign wb_commit = wb_pending_q && !halted && !core_start_i && !core_force_stop_i;
endmodule
