`ifdef EDGE32_EXTERNAL_FPU
`include "edge32_external_fpu.svh"
`endif
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
`endif
  input wire clk, input wire reset_n,
  input wire [PC_WIDTH-1:0] boot_pc,
  input wire core_start,input wire core_force_stop,
  output wire [31:0] icache_address_header,
  output wire [31:0] dcache_address_header,
  output wire imem_req_valid, input wire imem_req_ready,
  output wire [PC_WIDTH-1:0] imem_req_addr,
  input wire imem_resp_valid, input wire [31:0] imem_resp_data,
  input wire imem_resp_error,
`ifdef EDGE32_SPLIT_LSU
  output wire fp_dmem_req_valid, input wire fp_dmem_req_ready,
  output wire [71:0] fp_dmem_req_payload,
  input wire fp_dmem_resp_valid, input wire fp_dmem_resp_error,
  input wire [31:0] fp_dmem_resp_rdata,
`endif
`ifdef EDGE32_INT_DTCM_PIPE
  input wire [63:0] int_dtcm_base, int_dtcm_mask,
  input wire int_dtcm_enable,
  output wire int_dtcm_hit,
  output wire [31:0] int_dtcm_base_snapshot,
`endif
  output wire dmem_req_valid, input wire dmem_req_ready,
  output wire dmem_req_write, output wire [31:0] dmem_req_addr,
  output wire [31:0] dmem_req_wdata, output wire [3:0] dmem_req_wstrb,
  output wire [1:0] dmem_req_size, output wire dmem_req_signed,
  input wire dmem_resp_valid, input wire dmem_resp_error,
  input wire [31:0] dmem_resp_rdata,
  output wire cache_op_valid,input wire cache_op_ready,
  output wire cache_op_is_va,output wire [1:0] cache_op_kind,
  output wire [31:0] cache_op_addr,
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
  output wire [63:0] instret_count,
  output wire putchar_valid, output wire [7:0] putchar_char
);
  // IF -> ID -> EX -> WB
  // ^     ^          |     WB writes the GPR local read owner.
  // |     +----------+
  // +---- EX redirect      Resolution cancels younger IF/ID work.
`ifdef EDGE32_DEBUG
  wire core_start_i = (AUTO_START ? 1'b0 : core_start) || debug_resume || debug_step;
  // A debug HALT drains EX/WB; it must not cancel an accepted instruction.
  wire core_force_stop_i = 1'b0;
  wire wb_halted, debug_block, debug_fetch_block;
  wire [PC_WIDTH-1:0] debug_ex_next_pc;
  wire debug_break_candidate = debug_break_enable && id_valid &&
    !halted && id_pc == debug_break_pc;
  wire debug_id_hold = debug_break_candidate || debug_fetch_block;
  wire debug_break_hit = debug_break_candidate &&
    (!ex_valid || ex_release_ready) && !redirect && !pipeline_kill;
  assign debug_gpr_allowed = halted && !core_start_i;
  edge32_debug_state #(.PC_WIDTH(PC_WIDTH), .AUTO_START(AUTO_START)) debug_state (
    .clk(clk), .reset_n(reset_n), .start(core_start_i && !debug_resume && !debug_step),
    .halt_req(core_force_stop), .boot_pc(boot_pc), .resume(debug_resume),
    .step(debug_step), .issue_fire(id_valid && id_capture_enable),
    .pc_write(debug_pc_write), .pc_wdata(debug_pc_wdata), .control_ack(debug_control_ack),
    .breakpoint_hit(debug_break_hit), .ex_valid(ex_valid), .ex_complete(ex_wb_fire),
    .ex_terminal(ex_wb.halt || ex_wb.fault), .ex_fault(ex_wb.fault),
    .ex_next_pc(debug_ex_next_pc), .wb_pending(wb_pending_q), .wb_commit(wb_commit),
    .block_issue(debug_block), .block_fetch(debug_fetch_block),
    .debug_halted(halted), .debug_pc(debug_pc), .debug_cause(debug_cause));
`else
  wire core_start_i = AUTO_START ? 1'b0 : core_start;
  wire core_force_stop_i = AUTO_START ? 1'b0 : core_force_stop;
`endif

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
  assign putchar_valid = ex_wb.putchar;
  assign putchar_char = ex_wb.putchar_value;
  wire pipeline_kill = redirect || terminal_complete || wb_terminal || halted ||
                       core_start_i || core_force_stop_i;

  edge_32_if_stage #(.PC_WIDTH(PC_WIDTH), .ENABLE_FPU(ENABLE_FPU), .AUTO_START(AUTO_START)) if_stage (
`ifdef EDGE32_DEBUG
    .boot_pc((debug_resume || debug_step) ? debug_pc : boot_pc),
`else
    .boot_pc(boot_pc),
`endif
    .clk(clk),
`ifdef EDGE32_DEBUG
    .core_force_stop_i(debug_fetch_block),
`else
    .core_force_stop_i(core_force_stop_i),
`endif
    .core_start_i(core_start_i),
`ifdef EDGE32_DEBUG
    .frontend_stop(frontend_stop || debug_fetch_block),
`else
    .frontend_stop(frontend_stop),
`endif
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
`ifdef EDGE32_DEBUG
    .debug_gpr_write(debug_gpr_write),
    .debug_gpr_wdata(debug_gpr_wdata),
    .debug_gpr_req_valid(debug_gpr_req_valid),
    .debug_gpr_req_ready(debug_gpr_req_ready),
    .debug_gpr_addr(debug_gpr_addr),
    .debug_gpr_resp_valid(debug_gpr_resp_valid),
    .debug_gpr_resp_ready(debug_gpr_resp_ready),
    .debug_gpr_data(debug_gpr_data),
`endif
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
`ifdef EDGE32_DEBUG
    .pipeline_kill(pipeline_kill || debug_fetch_block), .debug_hold(debug_id_hold),
`else
    .pipeline_kill(pipeline_kill),
`endif
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
`ifdef EDGE32_EXTERNAL_FPU
    `EDGE32_FPU_CONNECT
`endif
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
`ifdef EDGE32_SPLIT_LSU
    .fp_dmem_req_valid(fp_dmem_req_valid), .fp_dmem_req_ready(fp_dmem_req_ready),
    .fp_dmem_req_payload(fp_dmem_req_payload),
    .fp_dmem_resp_valid(fp_dmem_resp_valid), .fp_dmem_resp_error(fp_dmem_resp_error),
    .fp_dmem_resp_rdata(fp_dmem_resp_rdata),
`endif
`ifdef EDGE32_INT_DTCM_PIPE
    .int_dtcm_base(int_dtcm_base),.int_dtcm_mask(int_dtcm_mask),
    .int_dtcm_enable(int_dtcm_enable),.int_dtcm_hit(int_dtcm_hit),
    .int_dtcm_base_snapshot(int_dtcm_base_snapshot),
`endif
    .dmem_req_ready(dmem_req_ready),
    .dmem_resp_error(dmem_resp_error),
    .dmem_resp_rdata(dmem_resp_rdata),
    .dmem_resp_valid(dmem_resp_valid),
`ifdef EDGE32_DEBUG
    .halted(wb_halted),
`else
    .halted(halted),
`endif
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
`ifdef EDGE32_DEBUG
    .debug_ex_next_pc(debug_ex_next_pc),
`endif
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
`ifdef EDGE32_DEBUG
    .halted(wb_halted),
`else
    .halted(halted),
`endif
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
`include "if/edge_32_if.sv"
`include "id/edge_32_id.sv"
`include "id/gpr/edge_32_gpr_read_port.sv"
`include "ex/edge_32_ex.sv"
`include "wb/edge_32_wb.sv"
