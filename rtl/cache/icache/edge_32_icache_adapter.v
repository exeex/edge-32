`timescale 1ns/1ps

// Converts the lite core's single 32-bit fetch into the maintained Edge
// I-cache scalar request/32-bit response contract. One request is outstanding.
module edge_32_icache_adapter #(
  parameter PC_WIDTH = 32
) (
  input  wire                clk,
  input  wire                reset_n,

  input  wire                core_req_valid,
  output wire                core_req_ready,
  input  wire [PC_WIDTH-1:0] core_req_addr,
  output wire                core_resp_valid,
  output wire [31:0]         core_resp_data,
  output wire                core_resp_error,

  output wire                cache_req_valid,
  input  wire                cache_req_ready,
  output wire [PC_WIDTH-1:0] cache_req_addr,
  input  wire                cache_resp_valid,
  output wire                cache_resp_ready,
  input  wire [31:0]         cache_resp_bits,
  input  wire                cache_resp_error
);
  reg pending_q;
  wire request_fire = core_req_valid && core_req_ready;
  wire response_fire = cache_resp_valid && cache_resp_ready;

  assign core_req_ready = (!pending_q || response_fire) && cache_req_ready;
  assign cache_req_valid = core_req_valid && (!pending_q || response_fire);
  assign cache_req_addr = core_req_addr;
  assign cache_resp_ready = pending_q;
  assign core_resp_valid = cache_resp_valid && pending_q;
  assign core_resp_error = cache_resp_error && pending_q;
  assign core_resp_data = cache_resp_bits;

  always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      pending_q <= 1'b0;
    end else begin
      if (response_fire) pending_q <= 1'b0;
      if (request_fire) begin
        pending_q <= 1'b1;
      end
    end
  end
endmodule
