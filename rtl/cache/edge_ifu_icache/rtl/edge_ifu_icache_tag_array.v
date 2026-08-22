// First Edge I-cache tag/valid array slice with one-cycle synchronous reads.
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
  reg [METADATA_WIDTH-1:0] metadata_q [0:LINES-1];
  reg [METADATA_WIDTH-1:0] read_metadata_q;

  always @(posedge clk) begin
    read_metadata_q <= metadata_q[read_index];
    if (clear_valid) begin
      metadata_q[clear_index] <= {METADATA_WIDTH{1'b0}};
    end else if (write_valid) begin
      metadata_q[write_index] <= {write_valid_bit, write_tag};
    end
  end

  assign read_tag = rst_b ? read_metadata_q[TAG_WIDTH-1:0]
                          : {TAG_WIDTH{1'b0}};
  assign read_valid_bit = rst_b && read_metadata_q[TAG_WIDTH];

`ifdef IVERILOG_SIM
  integer init_i;
  initial begin
    read_metadata_q = {METADATA_WIDTH{1'b0}};
    for (init_i = 0; init_i < LINES; init_i = init_i + 1) begin
      metadata_q[init_i] = {METADATA_WIDTH{1'b0}};
    end
  end
`endif

endmodule
