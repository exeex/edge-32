`timescale 1ns/1ps
module edge_dcache_mshr_tb;
  reg clk, rst_b, redirect_valid;
  reg [7:0] redirect_seq_id;
  reg [3:0] redirect_epoch;
  reg miss_valid, miss_wait_writeback, victim_writeback_complete;
  reg [63:0] miss_addr;
  reg [7:0] miss_seq_id;
  reg [3:0] miss_epoch;
  reg [1:0] miss_size;
  reg miss_signed;
  wire miss_ready, miss_allocate;
  wire refill_req_valid;
  reg refill_req_ready;
  wire [63:0] refill_req_addr;
  reg refill_resp_valid, refill_resp_last, refill_resp_error;
  reg [127:0] refill_resp_data;
  reg refill_store_ready;
  wire refill_resp_ready, refill_store_valid;
  wire [1:0] refill_store_beat;
  wire [127:0] refill_store_data;
  wire complete, complete_valid, complete_error, complete_signed;
  wire [7:0] complete_seq_id;
  wire [3:0] complete_epoch;
  wire [63:0] complete_addr, complete_word, active_addr;
  wire [1:0] complete_size, active_beat;
  wire active, refill_active;

  edge_dcache_mshr dut (
    .forever_cpuclk(clk), .cpurst_b(rst_b),
    .redirect_valid(redirect_valid), .redirect_seq_id(redirect_seq_id),
    .redirect_epoch(redirect_epoch),
    .miss_valid(miss_valid), .miss_ready(miss_ready),
    .miss_addr(miss_addr), .miss_seq_id(miss_seq_id),
    .miss_epoch(miss_epoch), .miss_size(miss_size),
    .miss_signed(miss_signed),
    .miss_wait_writeback(miss_wait_writeback),
    .miss_allocate(miss_allocate),
    .victim_writeback_complete(victim_writeback_complete),
    .refill_req_valid(refill_req_valid),
    .refill_req_ready(refill_req_ready), .refill_req_addr(refill_req_addr),
    .refill_resp_valid(refill_resp_valid),
    .refill_resp_ready(refill_resp_ready),
    .refill_resp_data(refill_resp_data),
    .refill_resp_last(refill_resp_last),
    .refill_resp_error(refill_resp_error),
    .refill_store_ready(refill_store_ready),
    .refill_store_valid(refill_store_valid),
    .refill_store_beat(refill_store_beat),
    .refill_store_data(refill_store_data),
    .complete(complete), .complete_valid(complete_valid),
    .complete_seq_id(complete_seq_id), .complete_epoch(complete_epoch),
    .complete_addr(complete_addr), .complete_size(complete_size),
    .complete_signed(complete_signed), .complete_error(complete_error),
    .complete_word(complete_word), .active(active),
    .refill_active(refill_active), .active_addr(active_addr),
    .active_beat(active_beat)
  );

  always #5 clk = ~clk;
  task tick; begin @(posedge clk); #1; end endtask
  task fail; input [255:0] msg; begin
    $display("TEST FAIL: %0s", msg); $finish;
  end endtask
  task send_beat;
    input [127:0] data; input last; input error;
    begin
      refill_resp_data=data; refill_resp_last=last;
      refill_resp_error=error; refill_resp_valid=1; #1;
      if (!refill_resp_ready) fail("refill beat should be ready");
      tick(); refill_resp_valid=0; refill_resp_last=0; refill_resp_error=0;
    end
  endtask

  initial begin
    clk=0; rst_b=0; redirect_valid=0; redirect_seq_id=0;
    redirect_epoch=1; miss_valid=0; miss_wait_writeback=0;
    victim_writeback_complete=0; miss_addr=0; miss_seq_id=0;
    miss_epoch=1; miss_size=2; miss_signed=1;
    refill_req_ready=0; refill_resp_valid=0; refill_resp_data=0;
    refill_resp_last=0; refill_resp_error=0; refill_store_ready=1;
    repeat (2) tick(); rst_b=1; tick();

    miss_valid=1; miss_addr=64'h0000_0000_0000_1068;
    miss_seq_id=8'd10; #1;
    if (!miss_ready || !miss_allocate) fail("clean miss allocation");
    tick(); miss_valid=0;
    if (!active || active_addr != 64'h1068 ||
        !refill_req_valid || refill_req_addr != 64'h1040)
      fail("clean miss request state");
    refill_req_ready=1; tick(); refill_req_ready=0;
    if (!refill_active || active_beat != 0) fail("refill should start");

    refill_store_ready=0; refill_resp_valid=1; #1;
    if (refill_resp_ready || !refill_store_valid)
      fail("array backpressure must hold a valid refill beat");
    refill_resp_valid=0; refill_store_ready=1;
    send_beat(128'h0011, 0, 0);
    if (refill_store_beat != 1) fail("beat should advance");
    send_beat(128'h0022, 0, 0);
    send_beat(128'h3333_3333_3333_3333_2222_2222_2222_2222, 0, 0);
    send_beat(128'h0044, 1, 0);
    if (!complete || !complete_valid || complete_seq_id != 8'd10 ||
        complete_epoch != 1 || complete_addr != 64'h1068 ||
        complete_size != 2 || !complete_signed || complete_error ||
        complete_word != 64'h3333_3333_3333_3333)
      fail("clean miss completion payload");
    tick();
    if (active || complete) fail("completion should release entry");

    miss_valid=1; miss_wait_writeback=1; miss_addr=64'h2080;
    miss_seq_id=8'd20; #1;
    if (!miss_ready) fail("dirty miss allocation");
    tick(); miss_valid=0;
    if (!active || refill_req_valid) fail("dirty miss must wait writeback");
    victim_writeback_complete=1; tick(); victim_writeback_complete=0;
    if (!refill_req_valid || refill_req_addr != 64'h2080)
      fail("writeback completion should release refill request");
    refill_req_ready=1; tick(); refill_req_ready=0;
    send_beat(128'h1, 0, 0); send_beat(128'h2, 0, 0);
    redirect_valid=1; redirect_seq_id=8'd19; redirect_epoch=1; tick();
    redirect_valid=0;
    send_beat(128'h3, 0, 0); send_beat(128'h4, 1, 1);
    if (!complete || complete_valid || !complete_error)
      fail("redirected miss should refill but suppress response");
    tick();
    if (active) fail("redirected refill should release entry");

    // Allocation in the redirect cycle must inherit stale state instead of
    // clearing it after redirect processing.
    miss_valid=1; miss_wait_writeback=0; miss_addr=64'h3080;
    miss_seq_id=8'h00; miss_epoch=2;
    redirect_valid=1; redirect_seq_id=8'hff; redirect_epoch=2;
    tick(); miss_valid=0; redirect_valid=0;
    refill_req_ready=1; tick(); refill_req_ready=0;
    send_beat(128'h1, 0, 0); send_beat(128'h2, 0, 0);
    send_beat(128'h3, 0, 0); send_beat(128'h4, 1, 0);
    if (!complete || complete_valid)
      fail("redirect-cycle wrap miss allocation was not stale");
    tick();

    miss_valid=1; miss_addr=64'h4080; miss_seq_id=8'hfe; miss_epoch=2;
    redirect_valid=1; redirect_seq_id=8'hff; redirect_epoch=2;
    tick(); miss_valid=0; redirect_valid=0;
    refill_req_ready=1; tick(); refill_req_ready=0;
    send_beat(128'h1, 0, 0); send_beat(128'h2, 0, 0);
    send_beat(128'h3, 0, 0); send_beat(128'h4, 1, 0);
    if (!complete || !complete_valid)
      fail("older redirect-cycle miss allocation was suppressed");
    tick();

    $display("EDGE_DCACHE_MSHR TEST PASS"); $finish;
  end
endmodule
