`timescale 1ns/1ps
module edge_dcache_hit_queue_tb;
  reg clk, rst_b, redirect_valid;
  reg [7:0] redirect_seq_id;
  reg [3:0] redirect_epoch;
  reg alloc0_valid, alloc1_valid, capture0_valid, capture1_valid;
  wire alloc0_ready, alloc1_ready;
  wire alloc0_buffered_ready, alloc1_buffered_ready;
  wire [1:0] alloc0_slot, alloc1_slot;
  reg [7:0] alloc0_seq_id, alloc1_seq_id;
  reg [3:0] alloc0_epoch, alloc1_epoch;
  reg [63:0] alloc0_addr, alloc1_addr;
  reg [1:0] capture0_slot, capture1_slot;
  reg [63:0] capture0_word, capture1_word;
  wire complete_valid;
  reg complete_ready;
  wire [7:0] complete_seq_id;
  wire [63:0] complete_word;
  wire [2:0] debug_count;

  edge_dcache_hit_queue #(.LOAD_LATENCY(2)) dut (
    .forever_cpuclk(clk), .cpurst_b(rst_b),
    .redirect_valid(redirect_valid), .redirect_seq_id(redirect_seq_id),
    .redirect_epoch(redirect_epoch),
    .alloc0_valid(alloc0_valid), .alloc0_ready(alloc0_ready),
    .alloc0_buffered_ready(alloc0_buffered_ready),
    .alloc0_slot(alloc0_slot), .alloc0_seq_id(alloc0_seq_id),
    .alloc0_epoch(alloc0_epoch), .alloc0_addr(alloc0_addr),
    .alloc0_size(2'b11), .alloc0_signed(1'b0),
    .alloc1_valid(alloc1_valid), .alloc1_ready(alloc1_ready),
    .alloc1_buffered_ready(alloc1_buffered_ready),
    .alloc1_slot(alloc1_slot), .alloc1_seq_id(alloc1_seq_id),
    .alloc1_epoch(alloc1_epoch), .alloc1_addr(alloc1_addr),
    .alloc1_size(2'b11), .alloc1_signed(1'b0),
    .capture0_valid(capture0_valid), .capture0_slot(capture0_slot),
    .capture0_word(capture0_word), .capture1_valid(capture1_valid),
    .capture1_slot(capture1_slot), .capture1_word(capture1_word),
    .complete_valid(complete_valid), .complete_ready(complete_ready),
    .complete_seq_id(complete_seq_id), .complete_epoch(),
    .complete_addr(), .complete_size(), .complete_signed(),
    .complete_word(complete_word), .debug_count(debug_count)
  );

  always #5 clk = ~clk;
  task tick; begin @(posedge clk); #1; end endtask
  task fail; input [255:0] msg; begin
    $display("TEST FAIL: %0s", msg); $finish;
  end endtask

  initial begin
    clk=0; rst_b=0; redirect_valid=0; redirect_seq_id=0; redirect_epoch=1;
    alloc0_valid=0; alloc1_valid=0; capture0_valid=0; capture1_valid=0;
    alloc0_seq_id=0; alloc1_seq_id=0; alloc0_epoch=1; alloc1_epoch=1;
    alloc0_addr=0; alloc1_addr=0; capture0_slot=0; capture1_slot=0;
    capture0_word=0; capture1_word=0; complete_ready=1;
    repeat (2) tick(); rst_b=1; tick();

    alloc0_valid=1; alloc1_valid=1;
    alloc0_seq_id=8'd10; alloc1_seq_id=8'd11;
    alloc0_addr=64'h1000; alloc1_addr=64'h1008;
    #1;
    if (!alloc0_ready || !alloc1_ready || alloc0_slot != 0 || alloc1_slot != 1)
      fail("dual allocation slots");
    capture0_slot=alloc0_slot; capture1_slot=alloc1_slot;
    tick();
    alloc0_valid=0; alloc1_valid=0;
    capture0_valid=1; capture1_valid=1;
    capture0_word=64'haaaa; capture1_word=64'hbbbb;
    tick();
    capture0_valid=0; capture1_valid=0;
    tick();
    if (!complete_valid || complete_seq_id != 8'd10 ||
        complete_word != 64'haaaa) fail("first completion");
    tick();
    if (!complete_valid || complete_seq_id != 8'd11 ||
        complete_word != 64'hbbbb) fail("second completion");
    tick();

    alloc0_valid=1; alloc0_seq_id=8'd20; alloc0_addr=64'h2000;
    capture0_slot=alloc0_slot; tick(); alloc0_valid=0;
    capture0_valid=1; capture0_word=64'hcccc; tick(); capture0_valid=0;
    redirect_valid=1; redirect_seq_id=8'd19; redirect_epoch=1; tick();
    redirect_valid=0; tick(); tick();
    if (complete_valid || debug_count != 0) fail("stale completion reclaim");

    // Direct allocation may reuse a same-cycle pop. Buffered admission uses
    // only registered capacity so completion state does not feed lookup pop.
    rst_b=0; tick(); rst_b=1; tick();
    complete_ready=0; alloc0_valid=1; alloc1_valid=1;
    alloc0_seq_id=8'd30; alloc1_seq_id=8'd31;
    #1;
    capture0_slot=alloc0_slot; capture1_slot=alloc1_slot;
    tick();
    capture0_valid=1; capture1_valid=1;
    capture0_word=64'hdddd; capture1_word=64'heeee;
    alloc0_seq_id=8'd32; alloc1_seq_id=8'd33;
    #1;
    if (!alloc0_ready || !alloc1_ready ||
        !alloc0_buffered_ready || !alloc1_buffered_ready)
      fail("second dual allocation capacity");
    tick();
    alloc0_valid=0; alloc1_valid=0;
    capture0_slot=2; capture1_slot=3;
    capture0_word=64'hffff; capture1_word=64'h1111;
    tick();
    capture0_valid=0; capture1_valid=0;
    #1;
    if (debug_count != 4 || alloc0_ready || alloc0_buffered_ready)
      fail("full capacity flags");
    complete_ready=1; #1;
    if (!complete_valid) fail("full queue head completion");
    if (!alloc0_ready) fail("direct same-cycle pop lookahead");
    if (alloc0_buffered_ready) fail("buffered capacity excludes pop lookahead");
    tick();
    if (!alloc0_buffered_ready) fail("buffered capacity after registered pop");

    // Reset and allocate a paired older/younger hit in the redirect cycle.
    // Only the younger lane may be reclaimed as stale.
    rst_b=0; tick(); rst_b=1; tick();
    complete_ready=1; alloc0_valid=1; alloc1_valid=1;
    alloc0_seq_id=8'hfe; alloc1_seq_id=8'h00;
    alloc0_epoch=2; alloc1_epoch=2;
    redirect_valid=1; redirect_seq_id=8'hff; redirect_epoch=2;
    #1; capture0_slot=alloc0_slot; capture1_slot=alloc1_slot;
    tick(); alloc0_valid=0; alloc1_valid=0; redirect_valid=0;
    capture0_valid=1; capture1_valid=1;
    capture0_word=64'hfefe; capture1_word=64'h0000;
    tick(); capture0_valid=0; capture1_valid=0;
    tick();
    if (!complete_valid || complete_seq_id != 8'hfe)
      fail("older redirect-cycle paired hit was suppressed");
    tick(); tick();
    if (complete_valid || debug_count != 0)
      fail("younger redirect-cycle paired hit was not reclaimed stale");

    $display("EDGE_DCACHE_HIT_QUEUE TEST PASS");
    $finish;
  end
endmodule
