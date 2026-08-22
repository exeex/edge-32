// Yosys/Xilinx synthesis view for the I-cache tag RAM.
module edge_ifu_icache_tag_array #(
  parameter TAG_WIDTH = 24,
  parameter LINES = 1024
) (
  input  wire                     clk,
  input  wire                     rst_b,
  input  wire                     write_valid,
  input  wire [$clog2(LINES)-1:0] write_index,
  input  wire [TAG_WIDTH-1:0]     write_tag,
  input  wire                     write_valid_bit,
  input  wire                     clear_valid,
  input  wire [$clog2(LINES)-1:0] clear_index,
  input  wire [$clog2(LINES)-1:0] read_index,
  output wire [TAG_WIDTH-1:0]     read_tag,
  output wire                     read_valid_bit
);

  localparam METADATA_WIDTH = TAG_WIDTH + 1;
  wire tag_write_valid = write_valid || clear_valid;
  wire [$clog2(LINES)-1:0] tag_addr =
    clear_valid ? clear_index :
    write_valid ? write_index : read_index;
  wire [METADATA_WIDTH-1:0] metadata_wdata = clear_valid
    ? {METADATA_WIDTH{1'b0}} : {write_valid_bit, write_tag};
  wire [METADATA_WIDTH-1:0] metadata_rdata;

  fpga_ram #(
    .DATAWIDTH(METADATA_WIDTH),
    .ADDRWIDTH($clog2(LINES))
  ) tag_ram (
    .PortAClk(clk),
    .PortAAddr(tag_addr),
    .PortADataIn(metadata_wdata),
    .PortAWriteEnable(tag_write_valid),
    .PortADataOut(metadata_rdata)
  );

  assign read_tag = rst_b ? metadata_rdata[TAG_WIDTH-1:0]
                          : {TAG_WIDTH{1'b0}};
  assign read_valid_bit = rst_b && metadata_rdata[TAG_WIDTH];

endmodule
