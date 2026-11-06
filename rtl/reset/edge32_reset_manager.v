// Logical reset branches; APR owns physical distribution and timing.
module edge32_reset_manager #(
  parameter integer REPORT_CYCLES = 1  // Must be >= 1.
) (
  input wire clk,
  input wire reset_n,
  input wire asic_reset_done, // Synchronous completion pulse from edge-e3.
  output wire reset_icache_n,
  output wire reset_dcache_n,
  output wire reset_rv32core_n,
  output wire reset_rv32muldiv_n,
  output wire reset_lsu_n,
  output wire reset_fpu_n,
  output wire reset_asic_n,
  output reg interrupt
);
  assign reset_icache_n = reset_n;
  assign reset_dcache_n = reset_n;
  assign reset_rv32core_n = reset_n;
  assign reset_rv32muldiv_n = reset_n;
  assign reset_lsu_n = reset_n;
  assign reset_fpu_n = reset_n;
  assign reset_asic_n = reset_n;

  localparam integer COUNT_WIDTH = (REPORT_CYCLES > 1) ? $clog2(REPORT_CYCLES) : 1;
  localparam [COUNT_WIDTH-1:0] LAST_COUNT = COUNT_WIDTH'(REPORT_CYCLES - 1);
  reg [COUNT_WIDTH-1:0] count_q;
  reg reported_q;
  reg asic_done_q;

  always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      count_q <= {COUNT_WIDTH{1'b0}};
      reported_q <= 1'b0;
      asic_done_q <= 1'b0;
      interrupt <= 1'b0;
    end else begin
      interrupt <= 1'b0;
      if (asic_reset_done) asic_done_q <= 1'b1;
      if (!reported_q) begin
        if (count_q == LAST_COUNT) begin
          if (asic_done_q || asic_reset_done) begin
            reported_q <= 1'b1;
            interrupt <= 1'b1;
          end
        end else begin
          count_q <= count_q + 1'b1;
        end
      end
    end
  end
endmodule
