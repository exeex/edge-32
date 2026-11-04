// Packed tag/valid/dirty. Single port, clocked read, write-priority access.
module edge_dcache_metadata_array #(
  parameter TAG_WIDTH=49, parameter LINES=512
)(
  input wire clk, input wire reset_b,
  input wire write_valid,
  input wire [$clog2(LINES)-1:0] write_index,
  input wire [TAG_WIDTH-1:0] write_tag,
  input wire write_valid_bit, input wire write_dirty_bit,
  input wire [$clog2(LINES)-1:0] read_index,
  output wire [TAG_WIDTH-1:0] read_tag,
  output wire read_valid_bit, output wire read_dirty_bit,
  output wire read_ready
);
  reg [TAG_WIDTH+1:0] metadata_q [0:LINES-1];
  reg [TAG_WIDTH+1:0] read_q;
  reg [$clog2(LINES)-1:0] sampled_index_q;
  reg sampled_valid_q;
  always @(posedge clk) begin
    if (reset_b) begin
      if (write_valid)
        metadata_q[write_index] <= {write_dirty_bit,write_valid_bit,write_tag};
      else
        read_q <= metadata_q[read_index];
    end
  end
  always @(posedge clk or negedge reset_b) begin
    if (!reset_b) begin
      sampled_index_q <= '0;
      sampled_valid_q <= 1'b0;
    end else begin
      sampled_valid_q <= !write_valid;
      if (!write_valid) sampled_index_q <= read_index;
    end
  end
  // sampled_valid_q already has asynchronous reset; avoid a raw reset-to-lookup data path.
  assign read_ready = sampled_valid_q && sampled_index_q == read_index;
  assign read_tag = read_q[TAG_WIDTH-1:0];
  assign read_valid_bit = read_q[TAG_WIDTH];
  assign read_dirty_bit = read_q[TAG_WIDTH+1];
endmodule
