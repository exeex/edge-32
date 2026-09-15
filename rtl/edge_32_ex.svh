// EX stage source entry. Included once by edge_32_core.
// Stage-owned signals and boundary payload.
  reg mem_started_q, mul_started_q, accel_started_q;
  reg cache_started_q, icache_invalidate_started_q;
  wire ex_decode_fault_q;
  wire id_terminal_break;
  wire ex_valid, ex_error;
  wire [PC_WIDTH-1:0] ex_pc; wire [31:0] ex_inst;
  wire [31:0] ex_rs1_value, ex_rs2_value;
  wire decoded_legal;
  wire is_lui;
  wire is_auipc;
  wire is_jal;
  wire is_jalr;
  wire is_branch;
  wire is_load;
  wire is_store;
  wire is_fp_load;
  wire is_fp_store;
  wire is_fp_compute;
  wire is_muldiv;
  wire is_cycle;
  wire is_instret;
  wire is_hardware_id;
  wire is_icache_header_csr;
  wire is_dcache_header_csr;
  wire is_fp_csr;
  wire is_terminal_break;
  wire is_edge_break;
  wire is_edge_cache;
  wire is_fast_class;
  wire is_int_mem;
  wire is_fp_mem;
  wire is_fence_i;
  wire is_supported_system;
  wire is_accel;
  wire csr_fflags;
  wire csr_frm;
  wire csr_write;
  wire cache_is_va;
  wire [1:0] cache_kind;
  wire [2:0] f3;
  wire funct7_bit5;
  wire [4:0] shamt;
  wire [4:0] csr_uimm;
  wire [4:0] rd;
  wire [3:0] alu_op;
  wire ex_writes_gpr;
  wire ex_writes_fpr;
  rv32::issue_control_t ex_issue_control_q;
  reg [31:0] ex_alu_imm_q, ex_mem_imm_q, ex_branch_imm_q, ex_jump_imm_q;

`include "ex/issue_registers.svh"
`include "ex/units.svh"
`include "ex/completion.svh"
`include "ex/result.svh"
`include "ex/transaction_state.svh"
