`timescale 1ns/1ps
// Architectural 32 x 32-bit FPR bank. Three asynchronous reads, one commit.
// ID->EX owns operand capture; write arbitration belongs to the FPU owner.
(* keep_hierarchy = 1 *)
module edge_32_fpr (
  input wire clk, input wire reset_n,
  input wire [4:0] read_rs0, read_rs1, read_rs2,
  output wire [31:0] read_value0, read_value1, read_value2,
  input wire write_valid, input wire [4:0] write_rd,
  input wire [31:0] write_value
);
  wire forward0 = write_valid && (read_rs0 == write_rd);
  wire forward1 = write_valid && (read_rs1 == write_rd);
  wire forward2 = write_valid && (read_rs2 == write_rd);
  genvar bit_idx;
  generate for (bit_idx=0; bit_idx<32; bit_idx=bit_idx+1) begin : g_bit
    edge_32_fpr_bit_slice slice (
      .clk(clk), .reset_n(reset_n), .write_valid(write_valid),
      .write_rd(write_rd), .write_bit(write_value[bit_idx]),
      .read_rs0(read_rs0), .read_rs1(read_rs1), .read_rs2(read_rs2),
      .forward0(forward0), .forward1(forward1), .forward2(forward2),
      .read_bit0(read_value0[bit_idx]), .read_bit1(read_value1[bit_idx]),
      .read_bit2(read_value2[bit_idx])
    );
  end endgenerate
`ifndef SYNTHESIS
  wire [31:0] regs_q [0:31];
  generate for (genvar w=0; w<32; w=w+1) begin : g_debug_word
    for (genvar b=0; b<32; b=b+1) begin : g_debug_bit
      assign regs_q[w][b] = g_bit[b].slice.data_q[w];
    end
  end endgenerate
`endif
endmodule

(* keep_hierarchy = 1 *)
module edge_32_fpr_bit_slice (
  input wire clk, input wire reset_n, input wire write_valid,
  input wire [4:0] write_rd, input wire write_bit,
  input wire [4:0] read_rs0, read_rs1, read_rs2,
  input wire forward0, forward1, forward2,
  output wire read_bit0, read_bit1, read_bit2
);
  (* ram_style = "registers" *) reg [31:0] data_q;
  genvar entry;
  generate for (entry=0; entry<32; entry=entry+1) begin : g_entry
    always @(posedge clk or negedge reset_n)
      if (!reset_n) data_q[entry] <= 1'b0;
      else if (write_valid && (write_rd == entry[4:0])) data_q[entry] <= write_bit;
  end endgenerate
  assign read_bit0 = forward0 ? write_bit : data_q[read_rs0];
  assign read_bit1 = forward1 ? write_bit : data_q[read_rs1];
  assign read_bit2 = forward2 ? write_bit : data_q[read_rs2];
endmodule
