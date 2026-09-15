`timescale 1ns/1ps

// Fixed-width RV32 instruction adapter. ASIC opcode 7'h3f is a complete
// 32-bit command; no second parcel is fetched or buffered.
module edge_32_instruction_assembler #(
  parameter PC_WIDTH = 32
) (
  input  wire                 clk,
  input  wire                 reset_n,
  input  wire                 parcel_valid,
  output wire                 parcel_ready,
  input  wire [PC_WIDTH-1:0]  parcel_pc,
  input  wire [31:0]          parcel_data,
  input  wire                 parcel_error,
  output wire                 op_valid,
  input  wire                 op_ready,
  output wire [PC_WIDTH-1:0]  op_pc,
  output wire [31:0]          op_inst,
  output wire                 op_error,
  input  wire                 flush
);
  assign op_valid = parcel_valid && !flush;
  assign op_pc = parcel_pc;
  assign op_inst = parcel_data;
  assign op_error = parcel_error;
  assign parcel_ready = !flush && op_ready;
endmodule
