`timescale 1ns/1ps

module edge_dcache_maintenance_tb;
  reg clk = 0;
  reg reset_n = 0;
  always #5 clk = ~clk;

  reg cache_op_valid = 0;
  wire cache_op_ready;
  reg cache_op_is_va = 0;
  reg [1:0] cache_op_kind = 0;
  reg [63:0] cache_op_addr = 0;
  reg [7:0] cache_op_seq_id = 0;
  reg [3:0] cache_op_epoch = 0;
  wire cache_op_complete_valid;
  wire [7:0] cache_op_complete_seq_id;
  wire [3:0] cache_op_complete_epoch;
  wire clean_wb_valid;
  wire [63:0] clean_wb_addr;
  wire [127:0] clean_wb_data;
  wire clean_wb_last;
  reg clean_wb_complete = 0;
  wire load_ready, store_ready;
  reg load_valid = 0;
  reg [7:0] load_seq_id = 0;
  reg [63:0] load_addr = 0;
  wire load_resp_valid;
  wire [7:0] load_resp_seq_id;
  wire load_resp_error;
  wire [63:0] load_resp_value;
  wire refill_req_valid;
  wire [63:0] refill_req_addr;
  reg refill_req_ready = 0;
  reg refill_resp_valid = 0;
  reg [127:0] refill_resp_data = 0;
  reg refill_resp_last = 0;
  reg refill_resp_error = 0;
  wire refill_resp_ready;
  reg redirect_valid = 0;
  reg [7:0] redirect_seq_id = 0;
  wire debug_cache_op_fire;
  integer i;
  integer timeout;
  integer init_cycles;
  integer wb_count;

  edge_dcache dut (
    .forever_cpuclk(clk), .cpurst_b(reset_n),
    .redirect_kill_valid(redirect_valid),
    .redirect_kill_seq_id(redirect_seq_id),
    .redirect_kill_epoch(4'ha),
    .backend_load_pause(1'b0), .backend_store_pause(1'b0),
    .lsu_load_req_valid(load_valid), .lsu_load_req_ready(load_ready),
    .lsu_load_req_seq_id(load_seq_id), .lsu_load_req_epoch(4'ha),
    .lsu_load_req_addr(load_addr), .lsu_load_req_size(2'd3),
    .lsu_load_req_signed(1'b0),
    .lsu_load_req1_valid(1'b0), .lsu_load_req1_ready(),
    .lsu_load_req1_seq_id(8'd0), .lsu_load_req1_epoch(4'd0),
    .lsu_load_req1_addr(64'd0), .lsu_load_req1_size(2'd0),
    .lsu_load_req1_signed(1'b0),
    .lsu_load_resp_valid(load_resp_valid),
    .lsu_load_resp_seq_id(load_resp_seq_id), .lsu_load_resp_epoch(),
    .lsu_load_resp_error(load_resp_error),
    .lsu_load_resp_value(load_resp_value),
    .lsu_store_req_valid(1'b0), .lsu_store_req_ready(store_ready),
    .lsu_store_req_seq_id(8'd0), .lsu_store_req_epoch(4'd0),
    .lsu_store_req_addr(64'd0), .lsu_store_req_size(2'd0),
    .lsu_store_req_data(64'd0), .lsu_store_req_wstrb(8'd0),
    .lsu_store_req1_valid(1'b0), .lsu_store_req1_ready(),
    .lsu_store_req1_seq_id(8'd0), .lsu_store_req1_epoch(4'd0),
    .lsu_store_req1_addr(64'd0), .lsu_store_req1_size(2'd0),
    .lsu_store_req1_data(64'd0), .lsu_store_req1_wstrb(8'd0),
    .cache_op_valid(cache_op_valid), .cache_op_ready(cache_op_ready),
    .cache_op_is_va(cache_op_is_va), .cache_op_kind(cache_op_kind),
    .cache_op_addr(cache_op_addr), .cache_op_seq_id(cache_op_seq_id),
    .cache_op_epoch(cache_op_epoch),
    .cache_op_complete_valid(cache_op_complete_valid),
    .cache_op_complete_seq_id(cache_op_complete_seq_id),
    .cache_op_complete_epoch(cache_op_complete_epoch),
    .clean_wb_valid(clean_wb_valid), .clean_wb_ready(1'b1),
    .clean_wb_addr(clean_wb_addr), .clean_wb_data(clean_wb_data),
    .clean_wb_last(clean_wb_last), .clean_wb_complete(clean_wb_complete),
    .refill_req_valid(refill_req_valid),
    .refill_req_ready(refill_req_ready), .refill_req_addr(refill_req_addr),
    .refill_resp_valid(refill_resp_valid),
    .refill_resp_ready(refill_resp_ready),
    .refill_resp_data(refill_resp_data),
    .refill_resp_last(refill_resp_last),
    .refill_resp_error(refill_resp_error),
    .debug_icache_bytes(), .debug_dcache_bytes(),
    .debug_load_pending(), .debug_load_miss_pending(),
    .debug_store_fire(), .store_predict_phase(),
    .store_predict_mem_active(), .store_predict_backend_blocked(),
    .debug_cache_op_fire(debug_cache_op_fire),
    .debug_cache_op_kind(), .debug_cache_op_is_va()
  );

  task issue_cache_op;
    input [1:0] kind;
    input [63:0] addr;
    input [7:0] seq_id;
    begin
      @(negedge clk);
      cache_op_valid = 1'b1;
      cache_op_is_va = 1'b1;
      cache_op_kind = kind;
      cache_op_addr = addr;
      cache_op_seq_id = seq_id;
      cache_op_epoch = 4'ha;
      #1;
      timeout = 0;
      while (!cache_op_ready && timeout < 40) begin
        @(negedge clk);
        timeout = timeout + 1;
      end
      if (!cache_op_ready || !debug_cache_op_fire)
        $fatal(1, "cache operation was not accepted kind=%0d addr=%h",
               kind, addr);
      @(posedge clk);
      @(negedge clk);
      cache_op_valid = 1'b0;
    end
  endtask

  task issue_load;
    input [7:0] seq_id;
    input [63:0] addr;
    begin
      @(negedge clk);
      load_valid = 1'b1;
      load_seq_id = seq_id;
      load_addr = addr;
      timeout = 0;
      while (!load_ready && timeout < 40) begin
        @(negedge clk);
        timeout = timeout + 1;
      end
      if (!load_ready) $fatal(1, "load request was not accepted addr=%h", addr);
      @(posedge clk);
      @(negedge clk);
      load_valid = 1'b0;
    end
  endtask

  task send_refill;
    input [63:0] expected_addr;
    input [127:0] beat0;
    input error_last;
    integer beat;
    begin
      timeout = 0;
      while (!refill_req_valid && timeout < 80) begin
        @(negedge clk);
        timeout = timeout + 1;
      end
      if (!refill_req_valid || refill_req_addr != expected_addr)
        $fatal(1, "refill request mismatch valid=%0d addr=%h expected=%h",
               refill_req_valid, refill_req_addr, expected_addr);
      refill_req_ready = 1'b1;
      @(posedge clk);
      @(negedge clk);
      refill_req_ready = 1'b0;
      refill_resp_valid = 1'b1;
      for (beat = 0; beat < 4; beat = beat + 1) begin
        refill_resp_data = beat == 0 ? beat0 : 128'd0;
        refill_resp_last = beat == 3;
        refill_resp_error = error_last && beat == 3;
        while (!refill_resp_ready) @(negedge clk);
        @(posedge clk);
        @(negedge clk);
      end
      refill_resp_valid = 1'b0;
      refill_resp_last = 1'b0;
      refill_resp_error = 1'b0;
    end
  endtask

  initial begin
    repeat (3) @(posedge clk);
    for (i = 0; i < 256; i = i + 1) begin
      dut.tag_array.valid_q[i] = i[0];
      dut.tag_array.tag_q[i] = {{18{1'b0}}, i[31:0]};
      dut.dirty_array.dirty_q[i] = ~i[0];
    end
    @(negedge clk);
    reset_n = 1'b1;

    timeout = 0;
    while (dut.metadata_init_active_q && timeout < 300) begin
      if (load_ready || store_ready || cache_op_ready)
        $fatal(1, "D-cache accepted traffic during metadata initialization");
      @(posedge clk);
      #1;
      timeout = timeout + 1;
    end
    if (dut.metadata_init_active_q || timeout != 256)
      $fatal(1, "metadata initialization length mismatch cycles=%0d", timeout);
    init_cycles = timeout;
    for (i = 0; i < 256; i = i + 1)
      if (dut.tag_array.valid_q[i] !== 1'b0 ||
          dut.dirty_array.dirty_q[i] !== 1'b0)
        $fatal(1, "metadata initialization left line %0d valid or dirty", i);

    // Seed a dirty resident line at address 0x100 (line index 4, tag 0).
    dut.tag_array.valid_q[4] = 1'b1;
    dut.tag_array.tag_q[4] = 0;
    dut.dirty_array.dirty_q[4] = 1'b1;
    dut.data_array.bank0_q[8] = 64'h1122_3344_5566_7788;
    dut.data_array.bank1_q[8] = 64'h99aa_bbcc_ddee_ff00;
    dut.data_array.bank2_q[8] = 64'h0102_0304_0506_0708;
    dut.data_array.bank3_q[8] = 64'h1112_1314_1516_1718;
    dut.data_array.bank0_q[9] = 64'h2122_2324_2526_2728;
    dut.data_array.bank1_q[9] = 64'h3132_3334_3536_3738;
    dut.data_array.bank2_q[9] = 64'h4142_4344_4546_4748;
    dut.data_array.bank3_q[9] = 64'h5152_5354_5556_5758;

    // Same-index, different-tag maintenance must not touch the resident line.
    issue_cache_op(2'b10, 64'h4100, 8'h31);
    #1;
    if (!cache_op_complete_valid || clean_wb_valid ||
        !dut.tag_array.valid_q[4] || !dut.dirty_array.dirty_q[4] ||
        dut.tag_array.tag_q[4] != 0)
      $fatal(1, "alias invalidate corrupted a different-tag resident line");

    issue_cache_op(2'b01, 64'h100, 8'h32);
    wb_count = 0;
    timeout = 0;
    while (wb_count < 4 && timeout < 80) begin
      @(negedge clk);
      timeout = timeout + 1;
      if (clean_wb_valid) begin
        if (clean_wb_addr != 64'h100 + wb_count * 16)
          $fatal(1, "clean writeback address mismatch beat=%0d addr=%h",
                 wb_count, clean_wb_addr);
        case (wb_count)
          0: if (clean_wb_data != 128'h99aa_bbcc_ddee_ff00_1122_3344_5566_7788) $fatal(1, "beat0 mismatch");
          1: if (clean_wb_data != 128'h1112_1314_1516_1718_0102_0304_0506_0708) $fatal(1, "beat1 mismatch");
          2: if (clean_wb_data != 128'h3132_3334_3536_3738_2122_2324_2526_2728) $fatal(1, "beat2 mismatch");
          3: if (clean_wb_data != 128'h5152_5354_5556_5758_4142_4344_4546_4748) $fatal(1, "beat3 mismatch");
        endcase
        if (clean_wb_last != (wb_count == 3))
          $fatal(1, "clean writeback last mismatch beat=%0d", wb_count);
        if (cache_op_complete_valid)
          $fatal(1, "clean completed before external writeback completion");
        wb_count = wb_count + 1;
      end
    end
    if (wb_count != 4) $fatal(1, "clean writeback stream timeout");
    if (!dut.dirty_array.dirty_q[4])
      $fatal(1, "dirty bit cleared before writeback completion");

    @(negedge clk);
    clean_wb_complete = 1'b1;
    @(posedge clk);
    #1;
    clean_wb_complete = 1'b0;
    if (!cache_op_complete_valid || cache_op_complete_seq_id != 8'h32 ||
        cache_op_complete_epoch != 4'ha)
      $fatal(1, "clean completion metadata mismatch");
    if (!dut.tag_array.valid_q[4] || dut.dirty_array.dirty_q[4])
      $fatal(1, "clean completion did not preserve valid and clear dirty");

    // A miss to the same index with a different tag must first write back the
    // dirty victim, then request and install the replacement line.
    dut.dirty_array.dirty_q[4] = 1'b1;
    issue_load(8'h40, 64'h4100);
    wb_count = 0;
    timeout = 0;
    while (wb_count < 4 && timeout < 80) begin
      @(negedge clk);
      timeout = timeout + 1;
      if (clean_wb_valid) begin
        if (clean_wb_addr != 64'h100 + wb_count * 16)
          $fatal(1, "victim writeback address mismatch beat=%0d addr=%h",
                 wb_count, clean_wb_addr);
        if (clean_wb_last != (wb_count == 3))
          $fatal(1, "victim writeback last mismatch beat=%0d", wb_count);
        wb_count = wb_count + 1;
      end
    end
    if (wb_count != 4 || refill_req_valid)
      $fatal(1, "replacement refill started before victim completion");
    @(negedge clk);
    clean_wb_complete = 1'b1;
    @(posedge clk);
    @(negedge clk);
    clean_wb_complete = 1'b0;
    if (cache_op_complete_valid)
      $fatal(1, "dirty victim writeback reported cache-op completion");
    send_refill(64'h4100,
      128'haaaa_bbbb_cccc_dddd_0123_4567_89ab_cdef, 1'b0);
    #1;
    if (!load_resp_valid || load_resp_error || load_resp_seq_id != 8'h40 ||
        load_resp_value != 64'h0123_4567_89ab_cdef)
      $fatal(1, "replacement refill completion mismatch");
    @(posedge clk);
    #1;
    if (!dut.tag_array.valid_q[4] || dut.dirty_array.dirty_q[4] ||
        dut.tag_array.tag_q[4] == 0)
      $fatal(1, "replacement refill metadata mismatch valid=%0d dirty=%0d tag=%h",
             dut.tag_array.valid_q[4], dut.dirty_array.dirty_q[4],
             dut.tag_array.tag_q[4]);

    // A failed refill reports the original request and must not install the
    // target line as valid.
    issue_load(8'h41, 64'h4200);
    send_refill(64'h4200,
      128'h1111_2222_3333_4444_5555_6666_7777_8888, 1'b1);
    #1;
    if (!load_resp_valid || !load_resp_error || load_resp_seq_id != 8'h41)
      $fatal(1, "refill error completion mismatch");
    @(posedge clk);
    #1;
    if (dut.tag_array.valid_q[8])
      $fatal(1, "failed refill installed a valid cache line");

    // A redirect may leave the physical refill active, but its stale response
    // must never complete into the architectural load stream.
    issue_load(8'h50, 64'hc240);
    timeout = 0;
    while (!refill_req_valid && timeout < 80) begin
      @(negedge clk);
      timeout = timeout + 1;
    end
    if (!refill_req_valid) $fatal(1, "stale-refill request was not created");
    redirect_seq_id = 8'h4f;
    redirect_valid = 1'b1;
    @(posedge clk);
    @(negedge clk);
    redirect_valid = 1'b0;
    send_refill(64'hc240,
      128'hdead_beef_0000_0000_1111_2222_3333_4444, 1'b0);
    repeat (4) begin
      #1;
      if (load_resp_valid)
        $fatal(1, "redirected stale refill emitted a load completion");
      @(posedge clk);
    end

    $display("EDGE32 DCACHE MAINTENANCE TEST PASS init=%0d victim_wb=%0d",
             init_cycles, wb_count);
    $finish;
  end
endmodule
