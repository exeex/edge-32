// IF stage: explicit ports; implementation is private to this module.
module edge_32_if_stage #(
  parameter PC_WIDTH=32, parameter ENABLE_FPU=0, parameter AUTO_START=1
)(
  input wire [PC_WIDTH-1:0] boot_pc,
  input wire clk,
  input wire core_force_stop_i,
  input wire core_start_i,
  input wire frontend_stop,
  input wire if_capacity_ready,
  input wire if_ready,
  input wire imem_req_ready,
  input wire [31:0] imem_resp_data,
  input wire imem_resp_error,
  input wire imem_resp_valid,
  input wire redirect,
  input wire [PC_WIDTH-1:0] redirect_pc,
  input wire reset_n,
  output wire if_csr_write,
  output wire [3:0] if_decoded_class,
  output wire if_decoded_legal,
  output wire if_error,
  output wire [4:0] if_frs0,
  output wire [4:0] if_frs1,
  output wire [4:0] if_frs2,
  output wire [31:0] if_inst,
  output wire [PC_WIDTH-1:0] if_pc,
  output wire if_rd_fpr,
  output wire if_rd_gpr,
  output wire [4:0] if_rs1,
  output wire [4:0] if_rs2,
  output wire [2:0] if_uses_fpr,
  output wire if_valid,
  output wire [4:0] if_write_rd,
  output wire [PC_WIDTH-1:0] imem_req_addr,
  output wire imem_req_valid
);
  wire if_flush;
  wire parcel_error;
  wire [31:0] parcel_inst;
  wire [PC_WIDTH-1:0] parcel_pc;
  wire parcel_ready;
  wire parcel_valid;

`include "if/predecode.svh"
`include "if/admission.svh"
`include "if/fetch.svh"
endmodule
