`timescale 1ns/1ps

module edge_dcache_registered_lookup_buffer_tb;
  localparam SEQ_ID_WIDTH = 8;
  localparam EPOCH_WIDTH = 4;
  localparam VALUE_WIDTH = 64;
  localparam LINE_OFFSET_WIDTH = 6;
  localparam LINE_INDEX_WIDTH = 8;
  localparam TAG_WIDTH = VALUE_WIDTH - LINE_OFFSET_WIDTH - LINE_INDEX_WIDTH;
  localparam LANE_WIDTH = SEQ_ID_WIDTH + EPOCH_WIDTH + VALUE_WIDTH + 3;
  localparam BUNDLE_WIDTH = 2*LANE_WIDTH + 1;
  localparam ADDR0_LSB = 3;

  reg clk = 1'b0;
  reg reset_b = 1'b0;
  reg redirect_valid = 1'b0;
  reg [7:0] redirect_seq_id = 8'b0;
  reg [3:0] redirect_epoch = 4'b0;
  reg push_valid = 1'b0;
  wire push_ready;
  reg [7:0] push_seq_id;
  reg [3:0] push_epoch;
  reg [63:0] push_addr;
  reg [1:0] push_size = 2'b11;
  reg push_signed = 1'b0;
  reg push_classified = 1'b1;
  reg push_hit = 1'b1;
  reg push_dirty_conflict = 1'b0;
  reg [TAG_WIDTH-1:0] push_dirty_tag = {TAG_WIDTH{1'b0}};
  reg push1_valid = 1'b0;
  reg [7:0] push1_seq_id;
  reg [3:0] push1_epoch;
  reg [63:0] push1_addr;
  reg [1:0] push1_size = 2'b11;
  reg push1_signed = 1'b0;
  reg classify_valid = 1'b0;
  reg classify_index = 1'b0;
  reg classify_hit = 1'b0;
  reg classify_dirty_conflict = 1'b0;
  reg [TAG_WIDTH-1:0] classify_dirty_tag = {TAG_WIDTH{1'b0}};
  reg invalidate_classification = 1'b0;
  reg pop_valid = 1'b0;
  reg pop_index = 1'b0;
  reg pop_lane1 = 1'b0;
  wire candidate0_valid, candidate0_classified, candidate0_hit;
  wire candidate0_dirty_conflict;
  wire [TAG_WIDTH-1:0] candidate0_dirty_tag;
  wire [BUNDLE_WIDTH-1:0] candidate0_bundle;
  wire candidate1_valid, candidate1_classified, candidate1_hit;
  wire candidate1_dirty_conflict;
  wire [TAG_WIDTH-1:0] candidate1_dirty_tag;
  wire [BUNDLE_WIDTH-1:0] candidate1_bundle;
  wire empty;
  wire [1:0] count;
  wire oldest_index;

  always #5 clk = ~clk;

  edge_dcache_registered_lookup_buffer #(
    .SEQ_ID_WIDTH(SEQ_ID_WIDTH), .EPOCH_WIDTH(EPOCH_WIDTH),
    .VALUE_WIDTH(VALUE_WIDTH),
    .LINE_OFFSET_WIDTH(LINE_OFFSET_WIDTH),
    .LINE_INDEX_WIDTH(LINE_INDEX_WIDTH),
    .BUNDLE_WIDTH(BUNDLE_WIDTH)
  ) dut (.*);

  task fail;
    input [511:0] message;
    begin $display("TEST FAIL: %0s", message); $finish; end
  endtask

  task push_bundle;
    input [7:0] seq;
    input [63:0] addr;
    input lane1;
    input [7:0] seq1;
    input [63:0] addr1;
    begin
      @(negedge clk);
      push_valid = 1'b1; push_seq_id = seq; push_epoch = 4'h1;
      push_addr = addr; push1_valid = lane1; push1_seq_id = seq1;
      push1_epoch = 4'h1; push1_addr = addr1;
      #1;
      if (!push_ready) begin
        $display("blocked push seq=%0h count=%0d valid=%0b/%0b",
                 seq, count, dut.valid0_q, dut.valid1_q);
        fail("push unexpectedly blocked");
      end
      @(posedge clk); #1; push_valid = 1'b0; push1_valid = 1'b0;
    end
  endtask

  task pop_bundle;
    input index;
    input lane1;
    begin
      @(negedge clk);
      pop_valid = 1'b1; pop_index = index; pop_lane1 = lane1;
      @(posedge clk); #1; pop_valid = 1'b0;
    end
  endtask

  function [63:0] candidate_addr;
    input [BUNDLE_WIDTH-1:0] bundle;
    begin candidate_addr = bundle[ADDR0_LSB +: VALUE_WIDTH]; end
  endfunction

  initial begin
    repeat (2) @(negedge clk);
    reset_b = 1'b1;

    push_bundle(8'h10, 64'h1000, 1'b0, 8'h0, 64'h0);
    push_bundle(8'h20, 64'h2000, 1'b0, 8'h0, 64'h0);
    if (count != 2 || candidate_addr(candidate0_bundle) != 64'h1000 ||
        candidate_addr(candidate1_bundle) != 64'h2000)
      fail("two-entry insertion order is wrong");

    pop_bundle(1'b1, 1'b0);
    if (count != 1 || candidate_addr(candidate0_bundle) != 64'h1000)
      fail("younger pop disturbed the oldest physical payload");
    @(negedge clk);
    classify_valid = 1'b1;
    classify_index = 1'b0;
    classify_hit = 1'b0;
    classify_dirty_conflict = 1'b1;
    classify_dirty_tag = 50'h12345;
    @(posedge clk);
    #1;
    classify_valid = 1'b0;
    if (!candidate0_classified || !candidate0_dirty_conflict ||
        candidate0_dirty_tag != 50'h12345)
      fail("classification did not retain dirty victim tag");
    pop_bundle(1'b0, 1'b0);

    push_bundle(8'h30, 64'h3000, 1'b1, 8'h31, 64'h3100);
    pop_bundle(1'b0, 1'b0);
    if (!candidate0_valid || candidate0_classified ||
        candidate_addr(candidate0_bundle) != 64'h3100)
      fail("lane1 promotion did not stay in place or clear classification");

    push_bundle(8'h40, 64'h4000, 1'b0, 8'h0, 64'h0);
    if (candidate_addr(candidate0_bundle) != 64'h3100 ||
        candidate_addr(candidate1_bundle) != 64'h4000)
      fail("hole refill changed logical age order");
    pop_bundle(1'b0, 1'b1);
    if (count != 1 || candidate1_valid == 1'b0 || oldest_index != 1'b1 ||
        candidate_addr(candidate1_bundle) != 64'h4000)
      fail("oldest pop did not select the remaining stationary slot");

    redirect_valid = 1'b1; redirect_seq_id = 8'h35; redirect_epoch = 4'h1;
    @(posedge clk); #1; redirect_valid = 1'b0;
    if (!empty) fail("redirect did not remove the remaining younger entry");

    $display("EDGE_DCACHE_REGISTERED_LOOKUP_BUFFER TEST PASS");
    $finish;
  end
endmodule
