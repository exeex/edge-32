// ID stage: explicit ports; implementation is private to this module.
module edge_32_id_stage #(
  parameter PC_WIDTH=32, parameter ENABLE_FPU=0
)(
  input wire clk,
  input wire gpr_stall,
  input wire csr_write,
  input wire ex_release_ready,
  input wire ex_valid,
  input wire ex_writes_fpr,
  input wire [31:0] id_fpu_control,
  input wire if_csr_write,
  input wire [3:0] if_decoded_class,
  input wire if_decoded_legal,
  input wire if_error,
  input wire [4:0] if_frs0,
  input wire [4:0] if_frs1,
  input wire [4:0] if_frs2,
  input wire [31:0] if_inst,
  input wire [PC_WIDTH-1:0] if_pc,
  input wire if_rd_fpr,
  input wire if_rd_gpr,
  input wire [2:0] if_uses_fpr,
  input wire if_valid,
  input wire [4:0] if_write_rd,
  input wire is_dcache_header_csr,
  input wire is_fp_compute,
  input wire is_fp_csr,
  input wire is_icache_header_csr,
  input wire pipeline_kill,
  input wire [4:0] rd,
  input wire reset_n,
  input wire wb_dcache_header_q,
  input wire wb_fp_csr_q,
  input wire wb_icache_header_q,
  input wire wb_pending_q,
  output wire [19:0] id_imm,
  output wire id_capture_enable,
  output reg id_error,
  output reg [4:0] id_frs0,
  output reg [4:0] id_frs1,
  output reg [4:0] id_frs2,
  output reg [31:0] id_inst,
  output wire rv32::issue_control_t id_issue_control,
  output wire id_issue_legal,
  output reg [PC_WIDTH-1:0] id_pc,
  output wire id_terminal_break,
  output wire [1:0] id_uses_gpr,
  output reg id_valid,
  output wire if_capacity_ready,
  output wire if_ready
);
  wire csr_interlock;
  wire id_can_advance;
  wire id_csr_hazard;
  reg id_csr_write;
  reg [3:0] id_decoded_class;
  reg id_decoded_legal;
  wire id_fpr_hazard;
  reg id_rd_fpr;
  reg id_rd_gpr;
  wire id_reads_fp_csr;
  wire id_stall;
  reg [2:0] id_uses_fpr;
  reg [4:0] id_write_rd;
  wire if_id_fire;

`include "id/decode.svh"
`include "id/dependencies.svh"

`include "id/admission.svh"
`include "id/slot.svh"
    assign if_id_fire = if_valid && if_ready;
endmodule
