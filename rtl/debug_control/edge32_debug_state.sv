// RV32 architectural stop boundary. No clocks/resets are sent to DMA or ASIC.
module edge32_debug_state #(
  parameter PC_WIDTH=32, parameter AUTO_START=0
)(
  input wire clk, reset_n, start, halt_req,
  input wire [PC_WIDTH-1:0] boot_pc,
  input wire breakpoint_hit,
  input wire ex_valid, ex_complete, wb_pending, wb_commit,
  input wire ex_terminal, ex_fault,
  input wire [PC_WIDTH-1:0] ex_next_pc,
  output wire block_issue,
  output reg debug_halted,
  output reg [PC_WIDTH-1:0] debug_pc,
  output reg [2:0] debug_cause
);
  reg halt_pending;
  reg [PC_WIDTH-1:0] arch_next_pc, wb_next_pc;
  assign block_issue = halt_req || breakpoint_hit || halt_pending || debug_halted;
  always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      halt_pending <= 0;
      debug_halted <= !AUTO_START;
      arch_next_pc <= 0;
      debug_pc <= 0;
      debug_cause <= 3'd5;
      wb_next_pc <= 0;
    end else if (start) begin
      halt_pending <= 0;
      debug_halted <= 0;
      arch_next_pc <= boot_pc;
      debug_pc <= boot_pc;
      debug_cause <= 0;
    end else begin
      if (ex_complete) wb_next_pc <= ex_next_pc;
      if (wb_commit) arch_next_pc <= wb_next_pc;
      if (!debug_halted) begin
        if (halt_req || breakpoint_hit || (ex_complete && ex_terminal)) begin
          halt_pending <= 1;
          if (!halt_pending)
            debug_cause <= halt_req ? 3'd3 : breakpoint_hit ? 3'd2 : ex_fault ? 3'd7 : 3'd1;
        end
        // Wait one full edge beyond the last commit; debug_pc and GPRs agree.
        if ((halt_pending || halt_req || breakpoint_hit) && !ex_valid && !wb_pending) begin
          debug_halted <= 1;
          debug_pc <= arch_next_pc;
          halt_pending <= 0;
        end
      end
    end
  end
endmodule
