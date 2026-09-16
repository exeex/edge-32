`timescale 1ns/1ps
// Architectural 31 x 32-bit FF bank, physically organized by data bit.
// Each slice owns both local read muxes; ID->EX owns the read boundary.
module edge_32_gpr (
  input wire clk, input wire reset_n,
  input wire [4:0] read_rs1, input wire [4:0] read_rs2,
  output wire [31:0] read_value1, output wire [31:0] read_value2,
  input wire write_valid, input wire [4:0] write_rd,
  input wire [31:0] write_value,
  output wire [31:0] debug_x31
);
  wire write_enable = write_valid && (write_rd != 5'd0);
  wire forward1 = write_enable && (read_rs1 == write_rd);
  wire forward2 = write_enable && (read_rs2 == write_rd);
  wire [31:1] write_select;
  wire [31:0] initialized_q;
  assign initialized_q[0] = 1'b0;
  wire visible1 = (read_rs1 != 0) && initialized_q[read_rs1];
  wire visible2 = (read_rs2 != 0) && initialized_q[read_rs2];

  // Shared visibility metadata; each physical slice decodes its own WB address.
  genvar entry;
  generate for (entry=1; entry<32; entry=entry+1) begin : g_entry
    reg initialized;
    assign write_select[entry] = write_enable && (write_rd == entry[4:0]);
    assign initialized_q[entry] = initialized;
    always @(posedge clk or negedge reset_n)
      if (!reset_n) initialized <= 1'b0;
      else if (write_select[entry]) initialized <= 1'b1;
  end endgenerate

  genvar bit_idx;
  generate for (bit_idx=0; bit_idx<32; bit_idx=bit_idx+1) begin : g_bit
    edge_32_gpr_bit_slice slice (
      .clk(clk), .write_valid(write_valid), .write_rd(write_rd),
      .write_bit(write_value[bit_idx]),
      .read_rs1(read_rs1), .read_rs2(read_rs2),
      .visible1(visible1), .visible2(visible2),
      .forward1(forward1), .forward2(forward2),
      .debug_visible(initialized_q[31]),
      .read_bit1(read_value1[bit_idx]), .read_bit2(read_value2[bit_idx]),
      .debug_bit(debug_x31[bit_idx])
    );
  end endgenerate

`ifndef SYNTHESIS
  // Testbench-only raw-word view; no cross-slice payload bus in synthesis.
  wire [31:0] regs_q [0:31];
  assign regs_q[0] = 32'd0;
  generate for (genvar w=1; w<32; w=w+1) begin : g_debug_word
    for (genvar b=0; b<32; b=b+1) begin : g_debug_bit
      assign regs_q[w][b] = g_bit[b].slice.data_q[w];
    end
  end endgenerate
`endif
endmodule

// Keep numerical state, write muxes, both read muxes and WB bypass local.
(* keep_hierarchy = 1 *)
module edge_32_gpr_bit_slice (
  input wire clk, input wire write_valid, input wire [4:0] write_rd,
  input wire write_bit,
  input wire [4:0] read_rs1, read_rs2,
  input wire visible1, visible2, forward1, forward2, debug_visible,
  output wire read_bit1, read_bit2, debug_bit
);
  (* ram_style = "registers" *) reg [31:1] data_q;
  wire [31:0] values = {data_q, 1'b0};
  genvar entry;
  generate for (entry=1; entry<32; entry=entry+1) begin : g_entry
    always @(posedge clk)
      if (write_valid && (write_rd == entry[4:0])) data_q[entry] <= write_bit;
  end endgenerate
  assign read_bit1 = forward1 ? write_bit : (visible1 ? values[read_rs1] : 1'b0);
  assign read_bit2 = forward2 ? write_bit : (visible2 ? values[read_rs2] : 1'b0);
  assign debug_bit = debug_visible ? data_q[31] : 1'b0;
endmodule
