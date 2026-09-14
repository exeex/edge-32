`timescale 1ns/1ps
// Exact enabled counter. Registered carry predicates split the increment into
// four 16-bit additions without changing architectural observation latency.
module edge_32_counter64 (
  input wire clk, input wire reset_n, input wire enable,
  output reg [63:0] value
);
  reg carry16_q, carry32_q, carry48_q;
  always @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
      value<=64'd0;
      carry16_q<=1'b0; carry32_q<=1'b0; carry48_q<=1'b0;
    end else if(enable) begin
      value[15:0]<=value[15:0]+16'd1;
      value[31:16]<=value[31:16]+{15'd0,carry16_q};
      value[47:32]<=value[47:32]+{15'd0,carry32_q};
      value[63:48]<=value[63:48]+{15'd0,carry48_q};
      // Predicates describe the NEW value and hold when counting is disabled.
      carry16_q<=value[15:0]==16'hfffe;
      carry32_q<=(&value[31:16])&&(value[15:0]==16'hfffe);
      carry48_q<=(&value[47:16])&&(value[15:0]==16'hfffe);
    end
  end
endmodule
