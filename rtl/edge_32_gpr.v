`timescale 1ns/1ps
// ID register read and architectural writeback. FF storage, two operand
// outputs, one committed write port. ID->EX owns the synchronous read boundary.
module edge_32_gpr (
  input wire clk, input wire reset_n,
  input wire [4:0] read_rs1, input wire [4:0] read_rs2,
  output wire [31:0] read_value1, output wire [31:0] read_value2,
  input wire write_valid, input wire [4:0] write_rd,
  input wire [31:0] write_value,
  output wire [31:0] debug_x31
);
  reg [31:0] regs_q [0:31];
  integer i;
  wire write_enable = write_valid && (write_rd != 5'd0);
  wire same_source = read_rs1 == read_rs2;
  wire forward1 = write_enable && (read_rs1 == write_rd);
  wire forward2 = write_enable && (read_rs2 == write_rd);
  // Select storage only when needed. Equal sources share the first resolved
  // operand, including its bypass. x0 never consumes a stored register value.
  wire [4:0] slot1 = forward1 ? 5'd0 : read_rs1;
  wire [4:0] slot2 = (same_source || forward2) ? 5'd0 : read_rs2;
  wire [31:0] value1 = (slot1 == 5'd0) ? 32'd0 : regs_q[slot1];
  wire [31:0] value2 = (slot2 == 5'd0) ? 32'd0 : regs_q[slot2];
  assign read_value1 = forward1 ? write_value : value1;
  assign read_value2 = same_source ? read_value1 :
                       forward2 ? write_value : value2;
  assign debug_x31 = regs_q[31];
  always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      for (i=0; i<32; i=i+1) regs_q[i] <= 32'd0;
    end else if (write_enable) begin
      regs_q[write_rd] <= write_value;
    end
  end
endmodule
