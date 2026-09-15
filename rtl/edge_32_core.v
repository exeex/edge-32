`include "edge_32_stage_types.svh"
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
  output wire halted, output wire illegal,
  output wire [63:0] debug_x31, output wire [63:0] cycle_count,
  output wire [63:0] instret_count
);
  // IF -> ID -> EX -> WB
  // ^     ^          |     WB writes the GPR local read owner.
  // |     +----------+
  // +---- EX redirect      Resolution cancels younger IF/ID work.
  wire core_start_i = AUTO_START ? 1'b0 : core_start;
  wire core_force_stop_i = AUTO_START ? 1'b0 : core_force_stop;

  // IF outputs: data, lifetime and feedback.
  wire if_csr_write;
  wire [3:0] if_decoded_class;
  wire if_decoded_legal;
  wire if_error;
  wire [4:0] if_frs0;
  wire [4:0] if_frs1;
  wire [4:0] if_frs2;
  wire [31:0] if_inst;
  wire [PC_WIDTH-1:0] if_pc;
  wire if_rd_fpr;
  wire if_rd_gpr;
  wire [4:0] if_rs1;
  wire [4:0] if_rs2;
  wire [2:0] if_uses_fpr;
  wire if_valid;
  wire [4:0] if_write_rd;

  // ID outputs: data, lifetime and feedback.
  wire [19:0] id_imm;
  wire id_capture_enable;
  wire id_error;
  wire [4:0] id_frs0;
  wire [4:0] id_frs1;
  wire [4:0] id_frs2;
  wire [31:0] id_inst;
  wire rv32::issue_control_t id_issue_control;
  wire id_issue_legal;
  wire [PC_WIDTH-1:0] id_pc;
  wire id_terminal_break;
  wire [1:0] id_uses_gpr;
  wire id_valid;
  wire if_capacity_ready;
  wire if_ready;

  // EX outputs: data, lifetime and feedback.
  wire csr_write;
  wire ex_done;
  wire ex_release_ready;
  wire ex_valid;
  wire edge32_stage::completion_payload_t ex_wb;
  wire ex_writes_fpr;
  wire ex_writes_gpr;
  wire frontend_stop;
  wire [31:0] id_fpu_control;
  wire is_dcache_header_csr;
  wire is_fp_compute;
  wire is_fp_csr;
  wire is_icache_header_csr;
  wire [4:0] ex_rd;
  wire redirect;
  wire [PC_WIDTH-1:0] redirect_pc;
  wire terminal_complete;
  wire wb_fp_csr_q;

  // WB outputs: data, lifetime and feedback.
  assign cycle_count = cycle_q;
  assign instret_count = instret_q;
  assign icache_address_header = icache_address_header_q;
  assign dcache_address_header = dcache_address_header_q;
  wire [63:0] cycle_q;
  wire [31:0] dcache_address_header_q;
  wire [31:0] icache_address_header_q;
  wire [63:0] instret_q;
  wire wb_commit;
  wire wb_dcache_header_q;
  wire wb_fault_q;
  wire wb_icache_header_q;
  wire wb_pending_q;
  wire [4:0] wb_rd_q;
  wire wb_terminal;
  wire wb_valid;
  wire [31:0] wb_value_q;

  wire ex_wb_fire = ex_done;
  wire pipeline_kill = redirect || terminal_complete || wb_terminal || halted ||
                       core_start_i || core_force_stop_i;

  edge_32_if_stage #(.PC_WIDTH(PC_WIDTH), .ENABLE_FPU(ENABLE_FPU), .AUTO_START(AUTO_START)) if_stage (
    .boot_pc(boot_pc),
    .clk(clk),
    .core_force_stop_i(core_force_stop_i),
    .core_start_i(core_start_i),
    .frontend_stop(frontend_stop),
    .if_capacity_ready(if_capacity_ready),
    .if_ready(if_ready),
    .imem_req_ready(imem_req_ready),
    .imem_resp_data(imem_resp_data),
    .imem_resp_error(imem_resp_error),
    .imem_resp_valid(imem_resp_valid),
    .redirect(redirect),
    .redirect_pc(redirect_pc),
    .reset_n(reset_n),
    .if_csr_write(if_csr_write),
    .if_decoded_class(if_decoded_class),
    .if_decoded_legal(if_decoded_legal),
    .if_error(if_error),
    .if_frs0(if_frs0),
    .if_frs1(if_frs1),
    .if_frs2(if_frs2),
    .if_inst(if_inst),
    .if_pc(if_pc),
    .if_rd_fpr(if_rd_fpr),
    .if_rd_gpr(if_rd_gpr),
    .if_rs1(if_rs1),
    .if_rs2(if_rs2),
    .if_uses_fpr(if_uses_fpr),
    .if_valid(if_valid),
    .if_write_rd(if_write_rd),
    .imem_req_addr(imem_req_addr),
    .imem_req_valid(imem_req_valid)
  );

  // IF -> GPR local indices; ID -> source use; EX -> RAW; WB -> writeback.

  wire [31:0] id_rs1_value, id_rs2_value;
  wire gpr_stall;
  wire [31:0] gpr_debug_x31;
  assign debug_x31 = {32'd0, gpr_debug_x31};
  edge_32_gpr_read_port gpr_read_port (
    .clk(clk), .reset_n(reset_n), .if_accept(if_valid && if_ready),
    .if_rs1(if_rs1), .if_rs2(if_rs2), .uses_gpr(id_uses_gpr),
    .ex_valid(ex_valid), .ex_writes_gpr(ex_writes_gpr), .ex_rd(ex_rd),
    .gpr_stall(gpr_stall), .read_value1(id_rs1_value), .read_value2(id_rs2_value),
    .write_valid(wb_valid), .write_rd(wb_rd_q), .write_value(wb_value_q),
    .debug_x31(gpr_debug_x31));

  edge_32_id_stage #(.PC_WIDTH(PC_WIDTH), .ENABLE_FPU(ENABLE_FPU)) id_stage (
    .clk(clk),
    .gpr_stall(gpr_stall),
    .csr_write(csr_write),
    .ex_release_ready(ex_release_ready),
    .ex_valid(ex_valid),
    .ex_writes_fpr(ex_writes_fpr),
    .id_fpu_control(id_fpu_control),
    .if_csr_write(if_csr_write),
    .if_decoded_class(if_decoded_class),
    .if_decoded_legal(if_decoded_legal),
    .if_error(if_error),
    .if_frs0(if_frs0),
    .if_frs1(if_frs1),
    .if_frs2(if_frs2),
    .if_inst(if_inst),
    .if_pc(if_pc),
    .if_rd_fpr(if_rd_fpr),
    .if_rd_gpr(if_rd_gpr),
    .if_uses_fpr(if_uses_fpr),
    .if_valid(if_valid),
    .if_write_rd(if_write_rd),
    .is_dcache_header_csr(is_dcache_header_csr),
    .is_fp_compute(is_fp_compute),
    .is_fp_csr(is_fp_csr),
    .is_icache_header_csr(is_icache_header_csr),
    .pipeline_kill(pipeline_kill),
    .rd(ex_rd),
    .reset_n(reset_n),
    .wb_dcache_header_q(wb_dcache_header_q),
    .wb_fp_csr_q(wb_fp_csr_q),
    .wb_icache_header_q(wb_icache_header_q),
    .wb_pending_q(wb_pending_q),
    .id_imm(id_imm),
    .id_capture_enable(id_capture_enable),
    .id_error(id_error),
    .id_frs0(id_frs0),
    .id_frs1(id_frs1),
    .id_frs2(id_frs2),
    .id_inst(id_inst),
    .id_issue_control(id_issue_control),
    .id_issue_legal(id_issue_legal),
    .id_pc(id_pc),
    .id_terminal_break(id_terminal_break),
    .id_uses_gpr(id_uses_gpr),
    .id_valid(id_valid),
    .if_capacity_ready(if_capacity_ready),
    .if_ready(if_ready)
  );

  edge_32_ex_stage #(.PC_WIDTH(PC_WIDTH), .DMEM_RESP_FORMATTED(DMEM_RESP_FORMATTED), .ENABLE_FPU(ENABLE_FPU), .EDGE_ASIC_ID(EDGE_ASIC_ID)) ex_stage (
    .accel_req_ready(accel_req_ready),
    .accel_resp_error(accel_resp_error),
    .accel_resp_valid(accel_resp_valid),
    .accel_resp_value(accel_resp_value),
    .cache_op_complete_valid(cache_op_complete_valid),
    .cache_op_ready(cache_op_ready),
    .clk(clk),
    .core_force_stop_i(core_force_stop_i),
    .core_start_i(core_start_i),
    .cycle_q(cycle_q),
    .dcache_address_header_q(dcache_address_header_q),
    .dmem_req_ready(dmem_req_ready),
    .dmem_resp_error(dmem_resp_error),
    .dmem_resp_rdata(dmem_resp_rdata),
    .dmem_resp_valid(dmem_resp_valid),
    .halted(halted),
    .icache_address_header_q(icache_address_header_q),
    .icache_invalidate_complete(icache_invalidate_complete),
    .icache_invalidate_ready(icache_invalidate_ready),
    .id_imm(id_imm),
    .id_capture_enable(id_capture_enable),
    .id_error(id_error),
    .id_frs0(id_frs0),
    .id_frs1(id_frs1),
    .id_frs2(id_frs2),
    .id_inst(id_inst),
    .id_issue_control(id_issue_control),
    .id_issue_legal(id_issue_legal),
    .id_pc(id_pc),
    .id_rs1_value(id_rs1_value),
    .id_rs2_value(id_rs2_value),
    .id_terminal_break(id_terminal_break),
    .id_uses_gpr(id_uses_gpr),
    .id_valid(id_valid),
    .instret_q(instret_q),
    .pipeline_kill(pipeline_kill),
    .reset_n(reset_n),
    .wb_commit(wb_commit),
    .wb_fault_q(wb_fault_q),
    .wb_rd_q(wb_rd_q),
    .wb_terminal(wb_terminal),
    .wb_value_q(wb_value_q),
    .accel_req_inst(accel_req_inst),
    .accel_req_src0(accel_req_src0),
    .accel_req_src1(accel_req_src1),
    .accel_req_valid(accel_req_valid),
    .cache_op_addr(cache_op_addr),
    .cache_op_is_va(cache_op_is_va),
    .cache_op_kind(cache_op_kind),
    .cache_op_valid(cache_op_valid),
    .csr_write(csr_write),
    .dmem_req_addr(dmem_req_addr),
    .dmem_req_signed(dmem_req_signed),
    .dmem_req_size(dmem_req_size),
    .dmem_req_valid(dmem_req_valid),
    .dmem_req_wdata(dmem_req_wdata),
    .dmem_req_write(dmem_req_write),
    .dmem_req_wstrb(dmem_req_wstrb),
    .ex_done(ex_done),
    .ex_release_ready(ex_release_ready),
    .ex_valid(ex_valid),
    .ex_wb(ex_wb),
    .ex_writes_fpr(ex_writes_fpr),
    .ex_writes_gpr(ex_writes_gpr),
    .frontend_stop(frontend_stop),
    .icache_invalidate_valid(icache_invalidate_valid),
    .id_fpu_control(id_fpu_control),
    .is_dcache_header_csr(is_dcache_header_csr),
    .is_fp_compute(is_fp_compute),
    .is_fp_csr(is_fp_csr),
    .is_icache_header_csr(is_icache_header_csr),
    .rd(ex_rd),
    .redirect(redirect),
    .redirect_pc(redirect_pc),
    .terminal_complete(terminal_complete),
    .wb_fp_csr_q(wb_fp_csr_q)
  );

  // Counters own arithmetic outside the completion/writeback stage.
  edge_32_counter64 cycle_counter(.clk(clk),.reset_n(reset_n),
    .enable(1'b1),.value(cycle_q));
  edge_32_counter64 retire_counter(.clk(clk),.reset_n(reset_n),
    .enable(wb_commit&&!wb_fault_q),.value(instret_q));

  edge_32_wb_stage wb_stage (
    .clk(clk),
    .core_force_stop_i(core_force_stop_i),
    .core_start_i(core_start_i),
    .ex_wb(ex_wb),
    .ex_wb_fire(ex_wb_fire),
    .reset_n(reset_n),
    .dcache_address_header_q(dcache_address_header_q),
    .halted(halted),
    .icache_address_header_q(icache_address_header_q),
    .illegal(illegal),
    .wb_commit(wb_commit),
    .wb_dcache_header_q(wb_dcache_header_q),
    .wb_fault_q(wb_fault_q),
    .wb_icache_header_q(wb_icache_header_q),
    .wb_pending_q(wb_pending_q),
    .wb_rd_q(wb_rd_q),
    .wb_terminal(wb_terminal),
    .wb_valid(wb_valid),
    .wb_value_q(wb_value_q)
  );
endmodule

// Stage module definitions compile with this core; includes do not share scope.
`include "edge_32_if.sv"
`include "edge_32_id.sv"
`include "edge_32_gpr_read_port.sv"
`include "edge_32_ex.sv"
`include "edge_32_wb.sv"
