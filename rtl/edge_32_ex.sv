// EX stage: explicit ports; implementation is private to this module.
module edge_32_ex_stage #(
  parameter PC_WIDTH=32, parameter DMEM_RESP_FORMATTED=0, parameter ENABLE_FPU=0, parameter [46:0] EDGE_ASIC_ID=47'd0
)(
  input wire accel_req_ready,
  input wire accel_resp_error,
  input wire accel_resp_valid,
  input wire [63:0] accel_resp_value,
  input wire cache_op_complete_valid,
  input wire cache_op_ready,
  input wire clk,
  input wire core_force_stop_i,
  input wire core_start_i,
  input wire [63:0] cycle_q,
  input wire [31:0] dcache_address_header_q,
  input wire dmem_req_ready,
  input wire dmem_resp_error,
  input wire [63:0] dmem_resp_rdata,
  input wire dmem_resp_valid,
  input wire halted,
  input wire [31:0] icache_address_header_q,
  input wire icache_invalidate_complete,
  input wire icache_invalidate_ready,
  input wire [19:0] id_imm,
  input wire id_capture_enable,
  input wire id_error,
  input wire [4:0] id_frs0,
  input wire [4:0] id_frs1,
  input wire [4:0] id_frs2,
  input wire [31:0] id_inst,
  input wire rv32::issue_control_t id_issue_control,
  input wire id_issue_legal,
  input wire [PC_WIDTH-1:0] id_pc,
  input wire [31:0] id_rs1_value,
  input wire [31:0] id_rs2_value,
  input wire id_terminal_break,
  input wire [1:0] id_uses_gpr,
  input wire id_valid,
  input wire [63:0] instret_q,
  input wire pipeline_kill,
  input wire reset_n,
  input wire wb_commit,
  input wire wb_fault_q,
  input wire [4:0] wb_rd_q,
  input wire wb_terminal,
  input wire [31:0] wb_value_q,
  output wire [31:0] accel_req_inst,
  output wire [63:0] accel_req_src0,
  output wire [63:0] accel_req_src1,
  output wire accel_req_valid,
  output wire [63:0] cache_op_addr,
  output wire cache_op_is_va,
  output wire [1:0] cache_op_kind,
  output wire cache_op_valid,
  output wire csr_write,
  output wire [63:0] dmem_req_addr,
  output wire dmem_req_signed,
  output wire [1:0] dmem_req_size,
  output wire dmem_req_valid,
  output wire [63:0] dmem_req_wdata,
  output wire dmem_req_write,
  output wire [7:0] dmem_req_wstrb,
  output wire ex_done,
  output wire ex_release_ready,
  output reg ex_valid,
  output wire edge32_stage::completion_payload_t ex_wb,
  output wire ex_writes_fpr,
  output wire ex_writes_gpr,
  output wire frontend_stop,
  output wire icache_invalidate_valid,
  output wire [31:0] id_fpu_control,
  output wire is_dcache_header_csr,
  output wire is_fp_compute,
  output wire is_fp_csr,
  output wire is_icache_header_csr,
  output wire [4:0] rd,
  output wire redirect,
  output wire [PC_WIDTH-1:0] redirect_pc,
  output wire terminal_complete,
  output wire wb_fp_csr_q
);
  wire accel_done;
  wire accel_req_fire;
  reg accel_started_q;
  wire [31:0] address_header_new;
  wire [31:0] address_header_old;
  wire [31:0] address_header_source;
  wire [3:0] alu_op;
  wire branch_redirect;
  wire branch_taken;
  wire [PC_WIDTH-1:0] branch_target;
  wire cache_done;
  wire cache_is_va;
  wire [1:0] cache_kind;
  wire cache_req_fire;
  reg cache_started_q;
  wire csr_fflags;
  wire csr_frm;
  wire [4:0] csr_uimm;
  reg [19:0] ex_imm_q;
  wire ex_control;
  wire ex_decode_fault_q;
  wire ex_faulting;
  reg [31:0] ex_inst;
  rv32::issue_control_t ex_issue_control_q;
  wire ex_issue_ok;
  reg [PC_WIDTH-1:0] ex_pc;
  wire [31:0] ex_result;
  reg [31:0] ex_rs1_value;
  reg [31:0] ex_rs2_value;
  wire [2:0] f3;
  wire fast_done;
  wire [31:0] fast_result;
  wire fence_i_done;
  wire fp_compute_complete;
  wire [31:0] fp_csr_value;
  wire [31:0] fp_load_value;
  wire [63:0] fp_store_value;
  wire [31:0] fpu_value;
  wire funct7_bit5;
  wire icache_invalidate_fire;
  reg icache_invalidate_started_q;
  wire is_accel;
  wire is_address_header_csr;
  wire is_auipc;
  wire is_branch;
  wire is_cycle;
  wire is_edge_break;
  wire is_edge_cache;
  wire is_fast_class;
  wire is_fence_i;
  wire is_fp_load;
  wire is_fp_mem;
  wire is_fp_store;
  wire is_hardware_id;
  wire is_instret;
  wire is_int_mem;
  wire is_jal;
  wire is_jalr;
  wire is_load;
  wire is_lui;
  wire is_muldiv;
  wire is_store;
  wire is_supported_system;
  wire is_terminal_break;
  wire lsu_done;
  wire lsu_error;
  wire [31:0] lsu_mem_addr;
  wire lsu_ready;
  wire lsu_start;
  wire [31:0] lsu_value;
  reg mem_started_q;
  wire mul_ready;
  wire [31:0] mul_result;
  wire mul_result_valid;
  wire mul_start;
  reg mul_started_q;
  wire [4:0] shamt;
  wire sys_done;

`include "ex/issue_registers.svh"
`include "ex/units.svh"
`include "ex/completion.svh"
`include "ex/result.svh"
`include "ex/transaction_state.svh"
`include "ex/slot.svh"
  assign ex_wb.fast_value = fast_result;
  assign ex_wb.other_value = ex_result;
  assign ex_wb.fast = is_fast_class;
  assign ex_wb.rd = rd;
  assign ex_wb.writes_gpr = ex_writes_gpr;
  assign ex_wb.fault = ex_faulting;
  assign ex_wb.halt = is_terminal_break;
  assign ex_wb.writes_icache_header = is_icache_header_csr && csr_write;
  assign ex_wb.writes_dcache_header = is_dcache_header_csr && csr_write;
  assign ex_wb.header_value = address_header_new;
endmodule
