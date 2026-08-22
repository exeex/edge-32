module edge_dcache_banked_data_array_tb;
  reg clk;
  reg reset_b;
  reg phase;
  reg lsu0_valid;
  wire lsu0_ready;
  reg lsu0_write;
  reg [3:0] lsu0_line_index;
  reg [1:0] lsu0_beat_index;
  reg lsu0_word_hi;
  reg [63:0] lsu0_wdata;
  reg [7:0] lsu0_wstrb;
  wire lsu0_rvalid;
  wire [63:0] lsu0_rdata;
  reg lsu1_valid;
  wire lsu1_ready;
  reg lsu1_write;
  reg [3:0] lsu1_line_index;
  reg [1:0] lsu1_beat_index;
  reg lsu1_word_hi;
  reg [63:0] lsu1_wdata;
  reg [7:0] lsu1_wstrb;
  wire lsu1_rvalid;
  wire [63:0] lsu1_rdata;
  reg mem_valid;
  wire mem_ready;
  reg mem_write;
  reg [3:0] mem_line_index;
  reg [1:0] mem_beat_index;
  reg [127:0] mem_wdata;
  reg [15:0] mem_wstrb;
  wire mem_rvalid;
  wire [127:0] mem_rdata;

  edge_dcache_banked_data_array #(
    .LINE_COUNT(16),
    .LINE_INDEX_WIDTH(4)
  ) dut (
    .clk(clk),
    .reset_b(reset_b),
    .phase(phase),
    .lsu0_valid(lsu0_valid),
    .lsu0_ready(lsu0_ready),
    .lsu0_write(lsu0_write),
    .lsu0_line_index(lsu0_line_index),
    .lsu0_beat_index(lsu0_beat_index),
    .lsu0_word_hi(lsu0_word_hi),
    .lsu0_wdata(lsu0_wdata),
    .lsu0_wstrb(lsu0_wstrb),
    .lsu0_rvalid(lsu0_rvalid),
    .lsu0_rdata(lsu0_rdata),
    .lsu1_valid(lsu1_valid),
    .lsu1_ready(lsu1_ready),
    .lsu1_write(lsu1_write),
    .lsu1_line_index(lsu1_line_index),
    .lsu1_beat_index(lsu1_beat_index),
    .lsu1_word_hi(lsu1_word_hi),
    .lsu1_wdata(lsu1_wdata),
    .lsu1_wstrb(lsu1_wstrb),
    .lsu1_rvalid(lsu1_rvalid),
    .lsu1_rdata(lsu1_rdata),
    .mem_valid(mem_valid),
    .mem_ready(mem_ready),
    .mem_write(mem_write),
    .mem_line_index(mem_line_index),
    .mem_beat_index(mem_beat_index),
    .mem_wdata(mem_wdata),
    .mem_wstrb(mem_wstrb),
    .mem_rvalid(mem_rvalid),
    .mem_rdata(mem_rdata)
  );

  always #5 clk = ~clk;

  task fail;
    input [255:0] msg;
    begin
      $display("EDGE_DCACHE_BANKED_DATA_ARRAY TEST FAIL: %0s", msg);
      $finish;
    end
  endtask

  task tick;
    begin
      @(posedge clk);
      #1;
    end
  endtask

  task settle;
    begin
      #1;
    end
  endtask

  task clear_inputs;
    begin
      lsu0_valid = 1'b0;
      lsu0_write = 1'b0;
      lsu0_line_index = 4'h0;
      lsu0_beat_index = 2'b00;
      lsu0_word_hi = 1'b0;
      lsu0_wdata = 64'b0;
      lsu0_wstrb = 8'h00;
      lsu1_valid = 1'b0;
      lsu1_write = 1'b0;
      lsu1_line_index = 4'h0;
      lsu1_beat_index = 2'b00;
      lsu1_word_hi = 1'b0;
      lsu1_wdata = 64'b0;
      lsu1_wstrb = 8'h00;
      mem_valid = 1'b0;
      mem_write = 1'b0;
      mem_line_index = 4'h0;
      mem_beat_index = 2'b00;
      mem_wdata = 128'b0;
      mem_wstrb = 16'h0000;
    end
  endtask

  initial begin
    clk = 1'b0;
    reset_b = 1'b0;
    phase = 1'b0;
    clear_inputs();
    repeat (3) tick();
    reset_b = 1'b1;
    tick();

    phase = 1'b0;
    lsu0_valid = 1'b1;
    lsu0_write = 1'b1;
    lsu0_line_index = 4'h2;
    lsu0_beat_index = 2'b00;
    lsu0_word_hi = 1'b0;
    lsu0_wdata = 64'haaaa_bbbb_cccc_dddd;
    lsu0_wstrb = 8'hff;
    lsu1_valid = 1'b1;
    lsu1_write = 1'b1;
    lsu1_line_index = 4'h7;
    lsu1_beat_index = 2'b10;
    lsu1_word_hi = 1'b1;
    lsu1_wdata = 64'h1111_2222_3333_4444;
    lsu1_wstrb = 8'hff;
    mem_valid = 1'b1;
    mem_write = 1'b1;
    mem_line_index = 4'h2;
    mem_beat_index = 2'b01;
    mem_wdata = 128'h5555_6666_7777_8888_eeee_ffff_0000_1234;
    mem_wstrb = 16'hffff;
    settle();
    if (!lsu0_ready || !lsu1_ready || !mem_ready)
      fail("phase0 independent LSU banks and opposite MEM half should be ready");
    tick();
    clear_inputs();
    tick();

    phase = 1'b0;
    lsu0_valid = 1'b1;
    lsu0_line_index = 4'h2;
    lsu0_beat_index = 2'b00;
    lsu0_word_hi = 1'b0;
    lsu1_valid = 1'b1;
    lsu1_line_index = 4'h7;
    lsu1_beat_index = 2'b10;
    lsu1_word_hi = 1'b1;
    mem_valid = 1'b1;
    mem_line_index = 4'h2;
    mem_beat_index = 2'b01;
    settle();
    if (!lsu0_ready || !lsu1_ready || !mem_ready)
      fail("phase0 independent LSU bank reads and MEM read should be ready");
    tick();
    if (!lsu0_rvalid || lsu0_rdata !== 64'haaaa_bbbb_cccc_dddd)
      fail("LSU lane0 bank0 read data mismatch");
    if (!lsu1_rvalid || lsu1_rdata !== 64'h1111_2222_3333_4444)
      fail("LSU lane1 bank1 read data mismatch");
    if (!mem_rvalid || mem_rdata !== 128'h5555_6666_7777_8888_eeee_ffff_0000_1234)
      fail("MEM half1 read data mismatch");
    clear_inputs();
    tick();

    phase = 1'b0;
    lsu0_valid = 1'b1;
    lsu0_line_index = 4'h2;
    lsu0_beat_index = 2'b00;
    lsu0_word_hi = 1'b0;
    lsu1_valid = 1'b1;
    lsu1_line_index = 4'h3;
    lsu1_beat_index = 2'b10;
    lsu1_word_hi = 1'b0;
    settle();
    if (!lsu0_ready || lsu1_ready)
      fail("same LSU bank should accept lane0 and hold lane1");
    tick();
    if (!lsu0_rvalid || lsu1_rvalid)
      fail("same-bank conflict should only return lane0");
    lsu0_valid = 1'b0;
    phase = 1'b1;
    mem_valid = 1'b1;
    mem_beat_index = 2'b00;
    settle();
    if (lsu1_ready)
      fail("same-bank lane1 replay should wait while MEM owns its half");
    tick();
    mem_valid = 1'b0;
    phase = 1'b0;
    settle();
    if (!lsu1_ready)
      fail("same-bank lane1 replay should be ready on next LSU-owned phase");
    tick();
    if (!lsu1_rvalid)
      fail("same-bank lane1 replay did not return after next LSU-owned phase");
    tick();
    clear_inputs();

    phase = 1'b0;
    lsu0_valid = 1'b1;
    lsu0_line_index = 4'h2;
    lsu0_beat_index = 2'b01;
    settle();
    if (!lsu0_ready)
      fail("idle MEM port should release the opposite half to LSU");
    tick();
    if (!lsu0_rvalid || lsu0_rdata !== 64'heeee_ffff_0000_1234)
      fail("idle-phase bypass read data mismatch");

    mem_valid = 1'b1;
    mem_beat_index = 2'b01;
    settle();
    if (lsu0_ready)
      fail("active MEM port should restore deterministic half ownership");
    tick();
    if (lsu0_rvalid)
      fail("active-MEM phase mismatch should not create LSU response");
    mem_valid = 1'b0;
    phase = 1'b1;
    settle();
    if (!lsu0_ready)
      fail("LSU half1 should be ready after phase flips");
    tick();
    if (!lsu0_rvalid || lsu0_rdata !== 64'heeee_ffff_0000_1234)
      fail("LSU replayed half1 low-bank read data mismatch");
    clear_inputs();
    tick();

    phase = 1'b1;
    lsu0_valid = 1'b1;
    lsu0_write = 1'b1;
    lsu0_line_index = 4'h3;
    lsu0_beat_index = 2'b11;
    lsu0_word_hi = 1'b0;
    lsu0_wdata = 64'hffff_ffff_ffff_ffff;
    lsu0_wstrb = 8'hff;
    tick();
    lsu0_wdata = 64'h1234_5678_9abc_def0;
    lsu0_wstrb = 8'hf0;
    tick();
    lsu0_write = 1'b0;
    tick();
    if (!lsu0_rvalid || lsu0_rdata !== 64'h1234_5678_ffff_ffff)
      fail("byte-masked 64-bit write did not preserve untouched bytes");
    clear_inputs();
    tick();

    $display("EDGE_DCACHE_BANKED_DATA_ARRAY TEST PASS");
    $finish;
  end
endmodule
