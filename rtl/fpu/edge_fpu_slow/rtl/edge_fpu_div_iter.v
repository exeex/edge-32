// FP32 restoring divider. The parent owns transaction scheduling and cancel.
module edge_fpu_div_iter (
  input wire clk, reset_n, cancel, load, step,
  input wire [23:0] numerator, denominator,
  output wire last,
  output wire [31:0] result_sig
);
  reg [24:0] rem_r;
  reg [31:0] quot_r;
  reg [5:0] iter_r;
  wire take = rem_r >= {1'b0, denominator};
  wire [24:0] rem_sub = take ? rem_r - {1'b0, denominator} : rem_r;
  wire [31:0] quot_next = {quot_r[30:0], take};
  assign last = step && !cancel && (iter_r == 1);
  assign result_sig = {quot_next[31:1], quot_next[0] | (|rem_sub)};
  always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      rem_r <= 0;
      quot_r <= 0;
      iter_r <= 0;
    end else if (!cancel) begin
      if (load) begin
        rem_r <= {1'b0, numerator};
        quot_r <= 0;
        iter_r <= numerator < denominator ? 6'd32 : 6'd31;
      end else if (step) begin
        rem_r <= rem_sub << 1;
        quot_r <= quot_next;
        iter_r <= iter_r - 1'b1;
      end
    end
  end
endmodule
