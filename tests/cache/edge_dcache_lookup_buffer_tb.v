`timescale 1ns/1ps

module edge_dcache_lookup_buffer_tb;
  reg clk = 1'b0;
  reg reset_b = 1'b0;
  reg redirect_valid = 1'b0;
  reg [7:0] redirect_seq_id = 8'b0;
  reg [3:0] redirect_epoch = 4'h1;
  reg push_valid = 1'b0;
  wire push_ready;
  reg [7:0] push_seq_id = 8'b0;
  reg [3:0] push_epoch = 4'h1;
  reg [63:0] push_addr = 64'b0;
  reg [1:0] push_size = 2'b11;
  reg push_signed = 1'b0;
  reg push1_valid = 1'b0;
  reg [7:0] push1_seq_id = 8'b0;
  reg [3:0] push1_epoch = 4'h1;
  reg [63:0] push1_addr = 64'b0;
  reg [1:0] push1_size = 2'b11;
  reg push1_signed = 1'b0;
  wire lookup_valid;
  wire [7:0] lookup_seq_id;
  wire [3:0] lookup_epoch;
  wire [63:0] lookup_addr;
  wire [1:0] lookup_size;
  wire lookup_signed;
  wire lookup1_valid;
  wire [7:0] lookup1_seq_id;
  wire [3:0] lookup1_epoch;
  wire [63:0] lookup1_addr;
  wire [1:0] lookup1_size;
  wire lookup1_signed;
  reg lookup_pop = 1'b0;
  reg lookup1_pop = 1'b0;
  reg lookup_park = 1'b0;
  reg retry_parked = 1'b0;
  wire empty;
  wire [1:0] count;

  edge_dcache_lookup_buffer dut (.*);
  always #5 clk = ~clk;

  task fail;
    input [8*100-1:0] message;
    begin $display("EDGE_DCACHE_LOOKUP_BUFFER TEST FAIL: %0s", message); $finish; end
  endtask

  task tick;
    begin @(posedge clk); #1; end
  endtask

  task do_reset;
    begin
      reset_b = 1'b0; redirect_valid = 1'b0; push_valid = 1'b0;
      push1_valid = 1'b0; lookup_pop = 1'b0; lookup1_pop = 1'b0;
      lookup_park = 1'b0; retry_parked = 1'b0;
      tick(); reset_b = 1'b1; tick();
    end
  endtask

  task push_bundle;
    input [7:0] seq0;
    input [7:0] seq1;
    input lane1;
    begin
      if (!push_ready) fail("push unexpectedly blocked");
      push_valid = 1'b1; push_seq_id = seq0; push_addr = {56'b0, seq0};
      push1_valid = lane1; push1_seq_id = seq1;
      push1_addr = {56'b0, seq1};
      tick(); push_valid = 1'b0; push1_valid = 1'b0;
    end
  endtask

  initial begin
    do_reset();

    // Partial paired kill keeps lane0 and removes only younger lane1.
    push_bundle(8'h10, 8'h12, 1'b1);
    redirect_valid = 1'b1; redirect_seq_id = 8'h10; tick();
    redirect_valid = 1'b0;
    if (!lookup_valid || lookup_seq_id != 8'h10 || lookup1_valid)
      fail("partial lane1 redirect cleanup failed");

    do_reset();
    // A parked older miss survives while the selectable younger slot dies.
    push_bundle(8'h20, 8'b0, 1'b0);
    lookup_park = 1'b1; tick(); lookup_park = 1'b0;
    push_bundle(8'h30, 8'b0, 1'b0);
    if (!lookup_valid || lookup_seq_id != 8'h30)
      fail("younger slot did not bypass parked head");
    redirect_valid = 1'b1; redirect_seq_id = 8'h25; tick();
    redirect_valid = 1'b0; retry_parked = 1'b1; tick(); retry_parked = 1'b0;
    if (count != 1 || !lookup_valid || lookup_seq_id != 8'h20)
      fail("parked older entry was not preserved alone");

    do_reset();
    // Redirect plus a fall-through younger push must not expose or retain it.
    push_valid = 1'b1; push_seq_id = 8'h00; push_epoch = 4'h2;
    redirect_valid = 1'b1; redirect_seq_id = 8'hff; redirect_epoch = 4'h2;
    #1;
    if (lookup_valid) fail("wrong-path fall-through push was exposed");
    tick(); push_valid = 1'b0; redirect_valid = 1'b0;
    if (!empty) fail("redirect-cycle younger push remained buffered");

    // Same-cycle older push must still be accepted.
    push_valid = 1'b1; push_seq_id = 8'hfe; push_epoch = 4'h2;
    redirect_valid = 1'b1; redirect_seq_id = 8'hff; redirect_epoch = 4'h2;
    tick(); push_valid = 1'b0; redirect_valid = 1'b0;
    if (!lookup_valid || lookup_seq_id != 8'hfe)
      fail("redirect-cycle older push was lost");

    do_reset();
    // Pop an older resident while a younger redirect-cycle request arrives.
    push_bundle(8'h40, 8'b0, 1'b0);
    push_valid = 1'b1; push_seq_id = 8'h50; push_epoch = 4'h1;
    lookup_pop = 1'b1;
    redirect_valid = 1'b1; redirect_seq_id = 8'h45; redirect_epoch = 4'h1;
    tick();
    push_valid = 1'b0; lookup_pop = 1'b0; redirect_valid = 1'b0;
    if (!empty) fail("redirect+pop+push retained younger request");

    $display("EDGE_DCACHE_LOOKUP_BUFFER TEST PASS");
    $finish;
  end
endmodule
