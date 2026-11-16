// RV32 architectural stop boundary. No clocks/resets are sent to DMA or ASIC.
module edge32_debug_state #(
  parameter PC_WIDTH=32, parameter AUTO_START=0
)(
  input wire clk, reset_n, start, halt_req,
  input wire [PC_WIDTH-1:0] boot_pc,
  input wire resume, step, pc_write,
  input wire issue_fire,
  input wire [PC_WIDTH-1:0] pc_wdata,
  output reg control_ack,
  input wire breakpoint_hit,
  input wire ex_valid, ex_complete, wb_pending, wb_commit,
  input wire ex_terminal, ex_fault,
  input wire [PC_WIDTH-1:0] ex_next_pc,
  output wire block_issue, block_fetch,
  output reg debug_halted,
  output reg [PC_WIDTH-1:0] debug_pc,
  output reg [2:0] debug_cause
);
  reg halt_pending;
  reg step_active, step_issued;
  reg [PC_WIDTH-1:0] arch_next_pc, wb_next_pc;
  assign block_issue = halt_req || breakpoint_hit || halt_pending || debug_halted || step_issued;
  // ID suppresses the breakpoint instruction immediately. Fetch may stop one
  // edge later, once halt_pending owns the event; no branch-result cone is
  // allowed to control the external instruction request in this cycle.
  assign block_fetch = halt_req || halt_pending || debug_halted || step_issued;
  always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      control_ack <= 0;
      step_active <= 0; step_issued <= 0;
      halt_pending <= 0;
      debug_halted <= !AUTO_START;
      arch_next_pc <= 0;
      debug_pc <= 0;
      debug_cause <= 3'd5;
      wb_next_pc <= 0;
    end else begin
      control_ack <= 0;
      if (start) begin
        step_active <= 0; step_issued <= 0;
        halt_pending <= 0;
        debug_halted <= 0;
        arch_next_pc <= boot_pc;
        debug_pc <= boot_pc;
        debug_cause <= 0;
      end else if (debug_halted && (resume || step)) begin
        debug_halted <= 0;
        step_active <= step; step_issued <= 0;
        halt_pending <= 0;
        arch_next_pc <= debug_pc;
        control_ack <= 1;
      end else if (debug_halted && pc_write) begin
        debug_pc <= pc_wdata;
        arch_next_pc <= pc_wdata;
        control_ack <= 1;
      end else begin
        if (step_active && issue_fire) step_issued <= 1;
        if (ex_complete) wb_next_pc <= ex_next_pc;
        if (wb_commit) arch_next_pc <= wb_next_pc;
        if (!debug_halted) begin
          if (halt_req || breakpoint_hit || (ex_complete && (ex_terminal || (step_active && step_issued)))) begin
            halt_pending <= 1;
            if (!halt_pending)
              debug_cause <= halt_req ? 3'd3 : breakpoint_hit ? 3'd2 : ex_fault ? 3'd7 : ex_terminal ? 3'd1 : 3'd4;
          end
          // Wait one full edge beyond the last commit; debug_pc and GPRs agree.
          if ((halt_pending || halt_req || breakpoint_hit) && !ex_valid && !wb_pending) begin
            debug_halted <= 1;
            step_active <= 0; step_issued <= 0;
            debug_pc <= arch_next_pc;
            halt_pending <= 0;
          end
        end
      end
    end
  end
endmodule
