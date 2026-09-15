`timescale 1ns/1ps
// ID register read and architectural writeback. FF storage, two operand
// outputs, one committed write port. ID->EX owns the synchronous read boundary.
module edge_32_gpr #(parameter PREDECODED_WRITE = 0) (
  input wire clk, input wire reset_n,
  input wire [4:0] read_rs1, input wire [4:0] read_rs2,
  output wire [31:0] read_value1, output wire [31:0] read_value2,
  input wire write_valid, input wire [4:0] write_rd,
  input wire [31:1] write_select,
  input wire [31:0] write_value,
  output wire [31:0] debug_x31
);
  // Keep the numerical bank in FFs on FPGA; reset only visibility metadata.
  wire [31:0] regs_q [0:31];
  wire [31:0] initialized_q;
  wire [31:0] selected = {write_select, 1'b0};
  wire write_enable = write_valid && (PREDECODED_WRITE || (write_rd != 5'd0));
  wire forward1 = write_enable && (PREDECODED_WRITE ? selected[read_rs1] : (read_rs1 == write_rd));
  wire forward2 = write_enable && (PREDECODED_WRITE ? selected[read_rs2] : (read_rs2 == write_rd));
  // Read storage in parallel with WB comparison; resolve bypass at the output.
  // Both FF read muxes may select the same entry; no read arbitration is needed.
  wire [4:0] slot1 = read_rs1;
  wire [4:0] slot2 = read_rs2;
  wire [31:0] value1 = ((slot1 == 5'd0) || !initialized_q[slot1]) ? 32'd0 : regs_q[slot1];
  wire [31:0] value2 = ((slot2 == 5'd0) || !initialized_q[slot2]) ? 32'd0 : regs_q[slot2];
  assign read_value1 = forward1 ? write_value : value1;
  assign read_value2 = forward2 ? write_value : value2;
  assign debug_x31 = initialized_q[31] ? regs_q[31] : 32'd0;
  // Decode the committed destination once per entry for both payload and valid.
  // x0 has no physical payload or initialization flop.
  assign regs_q[0] = 32'd0;
  assign initialized_q[0] = 1'b0;
  genvar entry;
  generate for (entry=1; entry<32; entry=entry+1) begin : g_entry
    (* ram_style = "registers" *) reg [31:0] data_q;
    reg initialized;
    assign regs_q[entry] = data_q;
    assign initialized_q[entry] = initialized;
    wire write_entry = write_enable &&
      (PREDECODED_WRITE ? write_select[entry] : (write_rd == entry));
    always @(posedge clk)
      if (write_entry) data_q <= write_value;
    always @(posedge clk or negedge reset_n)
      if (!reset_n) initialized <= 1'b0;
      else if (write_entry) initialized <= 1'b1;
  end endgenerate
endmodule
