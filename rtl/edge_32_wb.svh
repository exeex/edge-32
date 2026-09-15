// WB stage source entry. Included once by edge_32_core.
// Stage-owned signals and boundary payload.
  wire [63:0] cycle_q, instret_q;

`include "wb/completion_state.svh"
`include "wb/capture.svh"
`include "wb/retirement.svh"
