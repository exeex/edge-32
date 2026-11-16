// External-master-controlled shared bus around the registered debug port.
module edge32_debug_bus #(
  parameter PC_WIDTH = 32
) (
  input wire clk, reset_n,
  input wire req_valid, req_write, read_enable,
  input wire [2:0] req_id,
  output wire req_ready,
  input wire [63:0] data_in,
  output wire [63:0] data_out,
  output wire data_oe,
  output wire resp_valid, resp_error, interrupt,
  input wire resp_ready,
  output wire debug_icache_req_valid,
  output wire [31:0] debug_icache_addr,
  input wire debug_icache_req_ready, debug_icache_complete,
  output wire debug_resume, debug_pc_write,
  output wire [PC_WIDTH-1:0] debug_pc_wdata,
  input wire debug_control_ack,
  input wire halted, illegal,
  input wire debug_gpr_allowed,
  input wire [PC_WIDTH-1:0] debug_pc,
  input wire [2:0] debug_cause,
  output wire [PC_WIDTH-1:0] debug_break_pc,
  output wire debug_break_enable, debug_gpr_write,
  output wire [31:0] debug_gpr_wdata,
  output wire debug_gpr_req_valid,
  input wire debug_gpr_req_ready,
  output wire [4:0] debug_gpr_addr,
  input wire debug_gpr_resp_valid,
  output wire debug_gpr_resp_ready,
  input wire [31:0] debug_gpr_data,
  input wire [63:0] cycle_count, instret_count,
  output wire [PC_WIDTH-1:0] boot_pc,
  output wire core_start, core_force_stop
);
  reg write_q;
  wire port_valid;
  assign resp_valid = reset_n && port_valid;
  // External OE and direction always control the physical read drivers.
  assign data_oe = read_enable && !req_write && resp_valid && !write_q;

  edge32_debug_port #(.PC_WIDTH(PC_WIDTH)) port (
    .clk(clk), .reset_n(reset_n),
    .req_valid(req_valid), .req_ready(req_ready),
    .req_write(req_write), .req_id(req_id), .req_data(data_in),
    .resp_valid(port_valid), .resp_ready(resp_ready),
    .resp_error(resp_error), .interrupt(interrupt), .resp_data(data_out),
    .debug_icache_req_valid(debug_icache_req_valid), .debug_icache_addr(debug_icache_addr),
    .debug_icache_req_ready(debug_icache_req_ready), .debug_icache_complete(debug_icache_complete),
    .debug_resume(debug_resume), .debug_pc_write(debug_pc_write),
    .debug_pc_wdata(debug_pc_wdata), .debug_control_ack(debug_control_ack),
    .debug_pc(debug_pc), .debug_cause(debug_cause),
    .debug_break_pc(debug_break_pc), .debug_break_enable(debug_break_enable),
    .debug_gpr_write(debug_gpr_write), .debug_gpr_wdata(debug_gpr_wdata),
    .halted(halted), .illegal(illegal), .debug_gpr_allowed(debug_gpr_allowed), .debug_gpr_req_valid(debug_gpr_req_valid), .debug_gpr_req_ready(debug_gpr_req_ready), .debug_gpr_addr(debug_gpr_addr), .debug_gpr_resp_valid(debug_gpr_resp_valid), .debug_gpr_resp_ready(debug_gpr_resp_ready), .debug_gpr_data(debug_gpr_data),
    .cycle_count(cycle_count), .instret_count(instret_count),
    .boot_pc(boot_pc), .core_start(core_start), .core_force_stop(core_force_stop)
  );
  always @(posedge clk or negedge reset_n) begin
    if (!reset_n)
      write_q <= 1'b0;
    else if (req_valid && req_ready)
      write_q <= req_write;
  end
endmodule
