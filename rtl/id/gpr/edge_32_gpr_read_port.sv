// GPR source-address lifetime and RAW backpressure owner.
module edge_32_gpr_read_port (
`ifdef EDGE32_DEBUG
  input wire debug_gpr_req_valid, debug_gpr_write,
  input wire [31:0] debug_gpr_wdata,
  input wire [4:0] debug_gpr_addr,
  output wire debug_gpr_req_ready,
  output reg debug_gpr_resp_valid,
  input wire debug_gpr_resp_ready,
  output reg [31:0] debug_gpr_data,
`endif
  input wire clk, reset_n, if_accept,
  input wire [4:0] if_rs1, if_rs2,
  input wire [1:0] uses_gpr,
  input wire ex_valid, ex_writes_gpr, input wire [4:0] ex_rd,
  output wire gpr_stall,
  output wire [31:0] read_value1, read_value2,
  input wire write_valid, input wire [4:0] write_rd,
  input wire [31:0] write_value, output wire [31:0] debug_x31
);
  // Resetless payload: ID validity masks canceled/stale read addresses.
  reg [4:0] id_rs1, id_rs2;
  // EX cannot bypass the registered WB boundary, including its completion cycle.
  assign gpr_stall = ex_valid && ex_writes_gpr && (ex_rd != 0) &&
    ((uses_gpr[0] && id_rs1 == ex_rd) || (uses_gpr[1] && id_rs2 == ex_rd));
  always @(posedge clk) if (if_accept) begin
    id_rs1 <= if_rs1; id_rs2 <= if_rs2;
  end
`ifdef EDGE32_DEBUG
  reg pending_q, read_q, write_q;
  reg [4:0] debug_addr_q;
  reg [31:0] debug_wdata_q;
  reg debug_write_q;
  wire debug_write_fire = write_q && !write_valid;
  assign debug_gpr_req_ready = !pending_q && !read_q && !write_q && !debug_gpr_resp_valid;
  always @(posedge clk) begin
    if (!reset_n) begin
      pending_q<=0; read_q<=0; write_q<=0; debug_gpr_resp_valid<=0;
      debug_addr_q<=0; debug_wdata_q<=0; debug_write_q<=0; debug_gpr_data<=0;
    end else begin
      if (debug_gpr_resp_valid && debug_gpr_resp_ready) debug_gpr_resp_valid<=0;
      if (debug_gpr_req_valid && debug_gpr_req_ready) begin
        pending_q<=1; debug_addr_q<=debug_gpr_addr;
        debug_wdata_q<=debug_gpr_wdata; debug_write_q<=debug_gpr_write;
      end
      if (pending_q && !if_accept && !write_valid) begin
        pending_q<=0;
        if (debug_write_q) write_q<=1; else read_q<=1;
      end
      if (read_q) begin
        read_q<=0; debug_gpr_data<=read_value1; debug_gpr_resp_valid<=1;
      end
      if (debug_write_fire) begin
        write_q<=0; debug_gpr_data<=0; debug_gpr_resp_valid<=1;
      end
    end
  end
  edge_32_gpr bank (
    .clk(clk), .reset_n(reset_n),
    .read_rs1(read_q ? debug_addr_q : id_rs1), .read_rs2(id_rs2),
    .read_value1(read_value1), .read_value2(read_value2),
    .write_valid(write_valid || debug_write_fire),
    .write_rd(debug_write_fire ? debug_addr_q : write_rd),
    .write_value(debug_write_fire ? debug_wdata_q : write_value), .debug_x31(debug_x31));
`else
  edge_32_gpr bank (
    .clk(clk),.reset_n(reset_n),.read_rs1(id_rs1),.read_rs2(id_rs2),
    .read_value1(read_value1),.read_value2(read_value2),
    .write_valid(write_valid),.write_rd(write_rd),.write_value(write_value),
    .debug_x31(debug_x31));
`endif
endmodule
