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
  wire debug_cache_op_fire;
  integer i;
  integer timeout;
  integer init_cycles;
  integer wb_count;

  edge_dcache dut (
    .forever_cpuclk(clk), .cpurst_b(reset_n),
    .redirect_kill_valid(1'b0), .redirect_kill_seq_id(8'd0),
    .redirect_kill_epoch(4'd0),
    .backend_load_pause(1'b0), .backend_store_pause(1'b0),
    .lsu_load_req_valid(1'b0), .lsu_load_req_ready(load_ready),
    .lsu_load_req_seq_id(8'd0), .lsu_load_req_epoch(4'd0),
    .lsu_load_req_addr(64'd0), .lsu_load_req_size(2'd0),
    .lsu_load_req_signed(1'b0),
    .lsu_load_req1_valid(1'b0), .lsu_load_req1_ready(),
    .lsu_load_req1_seq_id(8'd0), .lsu_load_req1_epoch(4'd0),
    .lsu_load_req1_addr(64'd0), .lsu_load_req1_size(2'd0),
    .lsu_load_req1_signed(1'b0),
    .lsu_load_resp_valid(), .lsu_load_resp_seq_id(),
    .lsu_load_resp_epoch(), .lsu_load_resp_error(),
    .lsu_load_resp_value(),
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
    .refill_req_valid(), .refill_req_ready(1'b0), .refill_req_addr(),
    .refill_resp_valid(1'b0), .refill_resp_ready(),
    .refill_resp_data(128'd0), .refill_resp_last(1'b0),
    .refill_resp_error(1'b0),
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

    $display("EDGE32 DCACHE MAINTENANCE TEST PASS init=%0d writeback=%0d",
             init_cycles, wb_count);
    $finish;
  end
endmodule
