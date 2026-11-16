// Include inside a module with clk/reset_n. External assertion is captured
// without a clock; two clock edges qualify release. Consumers use local_reset_n
// synchronously. Keep clock running until reset and initialization complete.
(* ASYNC_REG = "TRUE" *) reg [1:0] reset_release_q;
always @(posedge clk or negedge reset_n) begin
  if (!reset_n) reset_release_q <= 2'b00;
  else reset_release_q <= {reset_release_q[0], 1'b1};
end
wire local_reset_n = reset_release_q[1];
