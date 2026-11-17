// SoC-side async capture; excluded from the full-core physical boundary.
// Clock must run through reset. The final output changes only on clock edges.
module edge32_core_reset_bridge (
  input wire clk, reset_n,
  output reg core_reset_n
);
  `include "reset/edge32_reset_release.svh"
  always @(posedge clk) core_reset_n <= local_reset_n;
endmodule
