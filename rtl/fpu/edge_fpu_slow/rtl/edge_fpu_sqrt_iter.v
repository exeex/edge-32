// FP32 radix-2 square root. The parent owns transaction scheduling and cancel.
module edge_fpu_sqrt_iter (
  input wire clk, reset_n, cancel, load, step,
  input wire [23:0] significand,
  input wire exponent_even,
  output wire last,
  output wire [31:0] result_sig
);
  // Fixed-point radicand is sig * 2^(37 or 38), not an FP64 payload.
  reg [63:0] rad_r;
  // For partial root q: 0 <= r < 2*q+1; two new bits need 35 work bits.
  reg [32:0] rem_r;
  reg [31:0] root_r;
  reg [5:0] iter_r;
  wire [34:0] rem_shift = {rem_r, rad_r[63:62]};
  wire [34:0] trial = {1'b0, root_r, 2'b01};
  wire take = rem_shift >= trial;
  wire [34:0] rem_next = take ? rem_shift - trial : rem_shift;
  wire [31:0] root_next = {root_r[30:0], take};
  assign last = step && !cancel && (iter_r == 1);
  assign result_sig = {root_next[31:1], root_next[0] | (|rem_next)};
  always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      rad_r <= 0;
      rem_r <= 0;
      root_r <= 0;
      iter_r <= 0;
    end else if (!cancel) begin
      if (load) begin
        rad_r <= {40'b0, significand} << (exponent_even ? 38 : 37);
        rem_r <= 0;
        root_r <= 0;
        iter_r <= 6'd32;
      end else if (step) begin
        rad_r <= rad_r << 2;
        rem_r <= rem_next[32:0];
        root_r <= root_next;
        iter_r <= iter_r - 1'b1;
      end
    end
  end
endmodule
