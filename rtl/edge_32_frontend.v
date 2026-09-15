`timescale 1ns/1ps
// Single-outstanding fetch frontend. A resolved control transfer discards the
// F/D contents and restarts at redirect_pc; no epoch or prediction is needed.
module edge_32_frontend #(
  parameter PC_WIDTH = 32,
  parameter [PC_WIDTH-1:0] RESET_PC = {PC_WIDTH{1'b0}},
  parameter AUTO_START = 1
) (
  input  wire                clk,
  input  wire                reset_n,
  input  wire [PC_WIDTH-1:0] boot_pc,
  input  wire                fetch_start,
  input  wire                fetch_stop,
  output wire                imem_req_valid,
  input  wire                imem_req_ready,
  output wire [PC_WIDTH-1:0] imem_req_addr,
  input  wire                imem_resp_valid,
  input  wire [31:0]         imem_resp_data,
  input  wire                imem_resp_error,
  output wire                op_valid,
  input  wire                op_ready,
  input  wire                op_capacity_ready,
  output wire [PC_WIDTH-1:0] op_pc,
  output wire [31:0]         op_inst,
  output wire                op_error,
  input  wire                halt,
  input  wire                redirect_valid,
  input  wire [PC_WIDTH-1:0] redirect_pc
);
  reg [PC_WIDTH-1:0] fetch_pc_q;
  reg running_q;
  reg request_pending_q;
  reg request_killed_q;
  reg [PC_WIDTH-1:0] request_pc_q;
  reg [1:0] fifo_count_q;
  reg fifo_read_q, fifo_write_q;
  reg [PC_WIDTH-1:0] fifo_pc_q [0:1];
  reg [31:0] fifo_inst_q [0:1];
  reg fifo_error_q [0:1];

  // AUTO_START preserves leaf-test compatibility. Product integration sets it
  // to zero and therefore uses the edge-rv start/stop contract below.
  wire fetch_start_i = AUTO_START ? 1'b0 : fetch_start;
  wire fetch_stop_i = AUTO_START ? 1'b0 : fetch_stop;

  wire request_fire = imem_req_valid && imem_req_ready;
  wire response_fire = imem_resp_valid && request_pending_q;
  wire response_push = response_fire && !request_killed_q &&
                       !redirect_valid && !halt && !fetch_stop_i;
  wire output_pop = op_valid && op_ready;
  wire [2:0] reserved_count;
  wire request_without_pop, request_with_pop;
  // Evaluate both local occupancy/response cases before late pipeline capacity.
  // Preserve this combinational boundary so mapping cannot feed EX completion
  // back through the occupancy arithmetic. Cancellation remains at the output.
  edge_32_frontend_capacity capacity(
    .fifo_count(fifo_count_q),.request_pending(request_pending_q),
    .response_valid(imem_resp_valid),.running(running_q),
    .reserved_count(reserved_count),
    .request_without_pop(request_without_pop),.request_with_pop(request_with_pop));
  wire request_candidate=op_capacity_ready ? request_with_pop:request_without_pop;
  assign imem_req_valid=request_candidate &&
                        !redirect_valid && !halt && !fetch_stop_i;
  assign imem_req_addr = fetch_pc_q;
  assign op_valid = (fifo_count_q != 0) && !redirect_valid && !halt;
  assign op_pc = fifo_pc_q[fifo_read_q];
  assign op_inst = fifo_inst_q[fifo_read_q];
  assign op_error = fifo_error_q[fifo_read_q];

  always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      fetch_pc_q <= RESET_PC;
      running_q <= AUTO_START;
      request_pending_q <= 1'b0;
      request_killed_q <= 1'b0;
      fifo_count_q <= 2'd0;
      fifo_read_q <= 1'b0;
      fifo_write_q <= 1'b0;
    end else if (fetch_start_i) begin
      running_q <= 1'b1;
      fetch_pc_q <= boot_pc;
      fifo_count_q <= 2'd0;
      fifo_read_q <= 1'b0;
      fifo_write_q <= 1'b0;
      if (response_fire) begin
        request_pending_q <= 1'b0;
        request_killed_q <= 1'b0;
      end else if (request_pending_q) begin
        request_killed_q <= 1'b1;
      end
    end else if (fetch_stop_i || halt) begin
      running_q <= 1'b0;
      fifo_count_q <= 2'd0;
      fifo_read_q <= 1'b0;
      fifo_write_q <= 1'b0;
      if (response_fire) begin
        request_pending_q <= 1'b0;
        request_killed_q <= 1'b0;
      end else if (request_pending_q) begin
        request_killed_q <= 1'b1;
      end
    end else begin
      if (request_fire) begin
        request_pending_q <= 1'b1;
        request_killed_q <= 1'b0;
        fetch_pc_q <= fetch_pc_q + {{(PC_WIDTH-3){1'b0}}, 3'd4};
      end
      if (response_fire) begin
        request_pending_q <= 1'b0;
        request_killed_q <= 1'b0;
      end
      // A crossing request owns the newly freed outstanding slot.
      if (request_fire) request_pending_q <= 1'b1;

      if (response_push) begin
        fifo_write_q <= ~fifo_write_q;
      end
      if (output_pop) fifo_read_q <= ~fifo_read_q;
      case ({response_push, output_pop})
        2'b10: fifo_count_q <= fifo_count_q + 1'b1;
        2'b01: fifo_count_q <= fifo_count_q - 1'b1;
        default: fifo_count_q <= fifo_count_q;
      endcase

      if (redirect_valid) begin
        fetch_pc_q <= redirect_pc;
        fifo_count_q <= 2'd0;
        fifo_read_q <= 1'b0;
        fifo_write_q <= 1'b0;
        if (request_pending_q && !response_fire) request_killed_q <= 1'b1;
      end
    end
  end
  // Ownership, not payload reset, cancels outstanding/FIFO contents.
  // Keep the same start/stop/halt priority and crossing request/response edge.
  always @(posedge clk) begin
    if (!fetch_start_i && !fetch_stop_i && !halt) begin
      if (request_fire) request_pc_q <= fetch_pc_q;
      if (response_push) begin
        fifo_pc_q[fifo_write_q] <= request_pc_q;
        fifo_inst_q[fifo_write_q] <= imem_resp_data;
        fifo_error_q[fifo_write_q] <= imem_resp_error;
      end
    end
  end
endmodule

// EX-lifetime semantic sideband physically owned by the frontend control cone.
// Capture beside IF on the same edge as EX operands, using the same enable.
// The producer's valid cancels stale payload; these two bits need no reset.
module edge_32_frontend_control (
  input wire clk, id_capture_enable,
  input wire id_decode_fault, id_terminal_break,
  input wire ex_valid, halted, wb_terminal, core_start, core_force_stop,
  input wire memory_fault_complete, accel_fault_complete,
  output reg ex_decode_fault, ex_terminal_break,
  output wire terminal_complete
);
  always @(posedge clk) begin
    if(id_capture_enable) begin
      ex_decode_fault <= id_decode_fault;
      ex_terminal_break <= id_terminal_break;
    end
  end
  // Runs in parallel with normal ex_done. Producer-owned fault completions
  // retain their original qualifications; a break also waits for WB to clear.
  assign terminal_complete=ex_valid&&!halted&&!core_start&&!core_force_stop&&
    (ex_decode_fault || (!wb_terminal&&ex_terminal_break) ||
     memory_fault_complete || accel_fault_complete);
endmodule

// Local lookahead: no pipeline-ready, branch or terminal input enters here.
// A response may release the outstanding slot while FIFO credit is evaluated.
module edge_32_frontend_capacity (
  input wire [1:0] fifo_count,
  input wire request_pending, response_valid, running,
  output wire [2:0] reserved_count,
  output wire request_without_pop, request_with_pop
);
  assign reserved_count={1'b0,fifo_count}+request_pending;
  wire slot_available=!request_pending||response_valid;
  wire space_without_pop=reserved_count<3'd2;
  wire space_with_pop=space_without_pop ||
                      ((fifo_count!=0)&&(reserved_count==3'd2));
  assign request_without_pop=slot_available&&running&&space_without_pop;
  assign request_with_pop=slot_available&&running&&space_with_pop;
endmodule
