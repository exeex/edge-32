// Purely synchronous core-side reset distribution root. APR owns the fanout
// tree and per-branch setup/hold repair. No raw asynchronous input enters here.
module edge32_core_reset_manager (
  input wire clk, core_reset_n,
  output reg distributed_reset_n
);
  always @(posedge clk) distributed_reset_n <= core_reset_n;
endmodule
