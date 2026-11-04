// Yosys/Xilinx synthesis view for the I-cache data array.
// Keeps the RTL module interface but uses a synchronous SRAM shape so Yosys
// infers RAMB resources instead of flattening the cache into LUTs.
module edge_ifu_icache_data_array #(
  parameter LINE_BITS = 128,
  parameter READ_BITS = LINE_BITS,
  parameter LINES = 1024
) (
  input  wire                     clk,
  input  wire                     write_valid,
  input  wire [$clog2(LINES)-1:0] write_index,
  input  wire [LINE_BITS-1:0]     write_data,
  input  wire [$clog2(LINES)-1:0] read_index,
  input wire [1:0] read_word,
  output wire [READ_BITS-1:0]     read_data
);

  wire [LINE_BITS-1:0] line_data;
  reg [1:0] read_word_q;
  always @(posedge clk) read_word_q <= read_word;
  assign read_data = READ_BITS == 32 ? line_data[read_word_q*32 +: 32] : line_data;
  fpga_ram #(
    .DATAWIDTH(LINE_BITS),
    .ADDRWIDTH($clog2(LINES))
  ) data_ram (
    .PortAClk(clk),
    .PortAAddr(write_valid ? write_index : read_index),
    .PortADataIn(write_data),
    .PortAWriteEnable(write_valid),
    .PortADataOut(line_data)
  );

endmodule
