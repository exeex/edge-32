// SPDX-License-Identifier: Apache-2.0
// Combinational 16-bit carry-select leaf used inside the registered 64-bit CPA.
module edge_add16_carry_select8 (
  input  wire [15:0] lhs,
  input  wire [15:0] rhs,
  input  wire        carry_in,
  output wire [16:0] sum
);
  wire [8:0] low;
  wire [8:0] high_c0;
  wire [8:0] high_c1;
  wire [8:0] high_selected;

  assign low = {1'b0, lhs[7:0]} + {1'b0, rhs[7:0]} + carry_in;
  assign high_c0 = {1'b0, lhs[15:8]} + {1'b0, rhs[15:8]};
  assign high_c1 = {1'b0, lhs[15:8]} + {1'b0, rhs[15:8]} + 9'd1;
  assign high_selected = low[8] ? high_c1 : high_c0;
  assign sum = {high_selected, low[7:0]};
endmodule
