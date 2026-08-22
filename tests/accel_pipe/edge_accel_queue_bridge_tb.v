`timescale 1ns/1ps

module edge_accel_queue_bridge_tb;
  localparam PC_WIDTH = 40;
  localparam SEQ_ID_WIDTH = 8;
  localparam EPOCH_WIDTH = 4;
  localparam CAPTURE_SLOTS = 8;
  localparam CAPTURE_ID_WIDTH = 3;
  localparam REG_INDEX_WIDTH = 5;
  localparam VALUE_WIDTH = 64;
  localparam EDGE64_OPCODE = 7'h3f;
  localparam SUB_DMA_START = 7'h01;
  localparam SUB_DMA_SETSRC = 7'h06;
  localparam SUB_DMA_SETTAR = 7'h07;
  localparam SUB_SETIN = 7'h12;
  localparam SUB_START = 7'h15;

  reg clk;
  reg rst_b;

  reg cmd_valid;
  wire cmd_ready;
  reg [PC_WIDTH-1:0] cmd_pc;
  reg [63:0] cmd_inst64;
  reg [SEQ_ID_WIDTH-1:0] cmd_seq_id;
  reg [EPOCH_WIDTH-1:0] cmd_epoch;
  reg [2:0] cmd_capture_count;
  reg cmd_n_capture_valid;
  reg [CAPTURE_ID_WIDTH-1:0] cmd_n_capture_id;
  reg cmd_n_capture_bank;
  reg [REG_INDEX_WIDTH-1:0] cmd_n_src_gpr;
  reg cmd_base_capture_valid;
  reg [CAPTURE_ID_WIDTH-1:0] cmd_base_capture_id;
  reg cmd_base_capture_bank;
  reg [REG_INDEX_WIDTH-1:0] cmd_base_src_gpr;

  reg snapshot_valid;
  reg [SEQ_ID_WIDTH-1:0] snapshot_seq_id;
  reg [EPOCH_WIDTH-1:0] snapshot_epoch;
  reg [1:0] snapshot_target;
  reg snapshot_n_valid;
  reg [VALUE_WIDTH-1:0] snapshot_n_value;
  reg snapshot_base_valid;
  reg [VALUE_WIDTH-1:0] snapshot_base_value;
  reg snapshot_rd_valid;
  reg [VALUE_WIDTH-1:0] snapshot_rd_value;

  wire issue_valid;
  wire issue_ready;
  reg allow_issue;
  reg redirect_valid;
  reg [SEQ_ID_WIDTH-1:0] redirect_seq_id;
  reg [EPOCH_WIDTH-1:0] redirect_epoch;
  wire [63:0] issue_inst64;
  wire [7:0] issue_opcode8;
  wire [7:0] issue_imm8;
  wire [SEQ_ID_WIDTH-1:0] issue_seq_id;
  wire [EPOCH_WIDTH-1:0] issue_epoch;
  wire issue_n_valid;
  wire [VALUE_WIDTH-1:0] issue_n_value;
  wire issue_base_valid;
  wire [VALUE_WIDTH-1:0] issue_base_value;
  wire issue_rd_valid;
  wire [VALUE_WIDTH-1:0] issue_rd_value;

  wire pipe_ready;
  wire pipe_decode_illegal;
  wire pipe_capture_consume_valid;
  wire pipe_done_valid;
  wire [SEQ_ID_WIDTH-1:0] pipe_done_seq_id;
  wire [EPOCH_WIDTH-1:0] pipe_done_epoch;
  wire dma_start_req;
  wire [VALUE_WIDTH-1:0] dma_start_src;
  wire [VALUE_WIDTH-1:0] dma_start_dst;
  wire [31:0] dma_start_len;
  wire [31:0] dma_start_entry_bytes;
  wire dma_sync_req;
  wire [3:0] cmd_setcsr_dtype;
  wire cmd_setcsr_req;
  wire [3:0] cmd_setcsr_wtype;
  wire [15:0] cmd_setin_ptr;
  wire cmd_setin_req;
  wire cmd_setn_req;
  wire [15:0] cmd_setn_value;
  wire [15:0] cmd_setout_ptr;
  wire cmd_setout_req;
  wire [15:0] cmd_setpsum_ptr;
  wire cmd_setpsum_req;
  wire cmd_start_req;
  wire cmd_start_tile_req;
  wire cmd_sync_req;
  wire [15:0] cmd_wld_ptr;
  wire cmd_wld_req;
  wire cmd_wld_trans_req;
  wire [2:0] queue_count;
  integer setin_req_count;
  integer start_req_count;
  integer dma_start_req_count;

  assign issue_ready = pipe_ready && allow_issue;

  edge_accel_cmd_queue #(
    .SEQ_ID_WIDTH(SEQ_ID_WIDTH),
    .EPOCH_WIDTH(EPOCH_WIDTH),
    .VALUE_WIDTH(VALUE_WIDTH),
    .QUEUE_DEPTH(4),
    .QUEUE_PTR_WIDTH(2),
    .SNAPSHOT_DEPTH(4),
    .SNAPSHOT_PTR_WIDTH(2)
  ) queue (
    .forever_cpuclk(clk),
    .cpurst_b(rst_b),
    .cmd_valid(cmd_valid),
    .cmd_ready(cmd_ready),
    .cmd_inst64(cmd_inst64),
    .cmd_seq_id(cmd_seq_id),
    .cmd_epoch(cmd_epoch),
    .cmd_n_capture_valid(cmd_n_capture_valid),
    .snapshot_valid(snapshot_valid),
    .snapshot_seq_id(snapshot_seq_id),
    .snapshot_epoch(snapshot_epoch),
    .snapshot_target(snapshot_target),
    .snapshot_n_valid(snapshot_n_valid),
    .snapshot_n_value(snapshot_n_value),
    .issue_valid(issue_valid),
    .issue_ready(issue_ready),
    .issue_opcode8(issue_opcode8),
    .issue_imm8(issue_imm8),
    .issue_inst64(issue_inst64),
    .issue_seq_id(issue_seq_id),
    .issue_epoch(issue_epoch),
    .issue_n_valid(issue_n_valid),
    .issue_n_value(issue_n_value),
    .redirect_kill_valid(redirect_valid),
    .redirect_kill_seq_id(redirect_seq_id),
    .redirect_kill_epoch(redirect_epoch),
    .debug_entry_valid(),
    .debug_count(queue_count),
    .debug_head(),
    .debug_tail()
  );

  edge_accel_pipe #(
    .SEQ_ID_WIDTH(SEQ_ID_WIDTH),
    .EPOCH_WIDTH(EPOCH_WIDTH),
    .VALUE_WIDTH(VALUE_WIDTH),
    .ADDR_WIDTH(16),
    .COMPACT_CMD_INPUT(1)
  ) pipe (
    .forever_cpuclk(clk),
    .cpurst_b(rst_b),
    .mem_region_base(40'h0040_0000_00),
    .mem_region_mask(40'hffff_fe00_00),
    .mem_region_enable(1'b1),
    .cmd_valid(issue_valid),
    .cmd_opcode8(issue_opcode8),
    .cmd_imm8(issue_imm8),
    .cmd_inst64(issue_inst64),
    .cmd_seq_id(issue_seq_id),
    .cmd_epoch(issue_epoch),
    .cmd_capture_valid(issue_n_valid),
    .cmd_capture_value(issue_n_value),
    .dma_start_ready(1'b1),
    .dma_sync_done(1'b1),
    .tensor_cmd_ready(1'b1),
    .tensor_start_ready(1'b1),
    .tensor_wld_cmd_ready(1'b1),
    .tensor_sync_stall(1'b0),
    .cmd_ready(pipe_ready),
    .decode_illegal(pipe_decode_illegal),
    .capture_consume_valid(pipe_capture_consume_valid),
    .tensor_done_valid(pipe_done_valid),
    .tensor_done_seq_id(pipe_done_seq_id),
    .tensor_done_epoch(pipe_done_epoch),
    .dma_start_req(dma_start_req),
    .dma_start_src(dma_start_src),
    .dma_start_dst(dma_start_dst),
    .dma_start_len(dma_start_len),
    .dma_start_entry_bytes(dma_start_entry_bytes),
    .dma_sync_req(dma_sync_req),
    .cmd_setcsr_dtype(cmd_setcsr_dtype),
    .cmd_setcsr_req(cmd_setcsr_req),
    .cmd_setcsr_wtype(cmd_setcsr_wtype),
    .cmd_setin_ptr(cmd_setin_ptr),
    .cmd_setin_req(cmd_setin_req),
    .cmd_setn_req(cmd_setn_req),
    .cmd_setn_value(cmd_setn_value),
    .cmd_setout_ptr(cmd_setout_ptr),
    .cmd_setout_req(cmd_setout_req),
    .cmd_setpsum_ptr(cmd_setpsum_ptr),
    .cmd_setpsum_req(cmd_setpsum_req),
    .cmd_start_req(cmd_start_req),
    .cmd_start_tile_req(cmd_start_tile_req),
    .cmd_sync_req(cmd_sync_req),
    .cmd_wld_ptr(cmd_wld_ptr),
    .cmd_wld_req(cmd_wld_req),
    .cmd_wld_trans_req(cmd_wld_trans_req)
  );

  always #5 clk = ~clk;

  always @(posedge clk) begin
    if (!rst_b) begin
      setin_req_count <= 0;
      start_req_count <= 0;
      dma_start_req_count <= 0;
    end else begin
      if (cmd_setin_req && issue_ready)
        setin_req_count <= setin_req_count + 1;
      if (cmd_start_req && issue_ready)
        start_req_count <= start_req_count + 1;
      if (dma_start_req && issue_ready)
        dma_start_req_count <= dma_start_req_count + 1;
    end
  end

  function [63:0] tensor_inst;
    input [6:0] subop;
    reg [31:0] low_word;
    reg [31:0] high_word;
    begin
      low_word = {25'b0, EDGE64_OPCODE};
      high_word = {24'b0, 1'b1, subop};
      tensor_inst = {high_word, low_word};
    end
  endfunction

  function [63:0] dma_start_inst;
    reg [31:0] low_word;
    reg [31:0] high_word;
    begin
      low_word = {20'b0, 5'd14, EDGE64_OPCODE};
      high_word = {24'b0, 1'b1, SUB_DMA_START};
      dma_start_inst = {high_word, low_word};
    end
  endfunction

  task fail;
    input [255:0] msg;
    begin
      $display("FAIL: %0s", msg);
      $finish;
    end
  endtask

  task tick;
    begin
      @(posedge clk);
      #1;
    end
  endtask

  task clear_inputs;
    begin
      snapshot_valid = 1'b0;
      snapshot_seq_id = {SEQ_ID_WIDTH{1'b0}};
      snapshot_epoch = 4'd1;
      snapshot_target = 2'd0;
      snapshot_n_valid = 1'b0;
      snapshot_n_value = {VALUE_WIDTH{1'b0}};
      snapshot_base_valid = 1'b0;
      snapshot_base_value = {VALUE_WIDTH{1'b0}};
      snapshot_rd_valid = 1'b0;
      snapshot_rd_value = {VALUE_WIDTH{1'b0}};
      allow_issue = 1'b1;
      redirect_valid = 1'b0;
      redirect_seq_id = {SEQ_ID_WIDTH{1'b0}};
      redirect_epoch = {EPOCH_WIDTH{1'b0}};
      cmd_valid = 1'b0;
      cmd_pc = 40'h8000;
      cmd_inst64 = 64'b0;
      cmd_seq_id = {SEQ_ID_WIDTH{1'b0}};
      cmd_epoch = 4'd1;
      cmd_capture_count = 3'd0;
      cmd_n_capture_valid = 1'b0;
      cmd_n_capture_id = {CAPTURE_ID_WIDTH{1'b0}};
      cmd_n_capture_bank = 1'b0;
      cmd_n_src_gpr = {REG_INDEX_WIDTH{1'b0}};
      cmd_base_capture_valid = 1'b0;
      cmd_base_capture_id = {CAPTURE_ID_WIDTH{1'b0}};
      cmd_base_capture_bank = 1'b0;
      cmd_base_src_gpr = {REG_INDEX_WIDTH{1'b0}};
    end
  endtask

  task send_snapshot;
    input [SEQ_ID_WIDTH-1:0] seq_id;
    input n_valid;
    input [VALUE_WIDTH-1:0] n_value;
    input base_valid;
    input [VALUE_WIDTH-1:0] base_value;
    input rd_valid;
    input [VALUE_WIDTH-1:0] rd_value;
    begin
      snapshot_valid = 1'b1;
      snapshot_seq_id = seq_id;
      snapshot_epoch = 4'd1;
      snapshot_target = seq_id[1:0];
      snapshot_n_valid = n_valid;
      snapshot_n_value = n_value;
      snapshot_base_valid = base_valid;
      snapshot_base_value = base_value;
      snapshot_rd_valid = rd_valid;
      snapshot_rd_value = rd_value;
      tick();
      snapshot_valid = 1'b0;
      snapshot_n_valid = 1'b0;
      snapshot_base_valid = 1'b0;
      snapshot_rd_valid = 1'b0;
    end
  endtask

  task enqueue_tensor_cmd;
    input [63:0] inst;
    input [SEQ_ID_WIDTH-1:0] seq_id;
    input needs_capture;
    begin
      cmd_valid = 1'b1;
      cmd_inst64 = inst;
      cmd_seq_id = seq_id;
      cmd_epoch = 4'd1;
      cmd_capture_count = needs_capture ? 3'd1 : 3'd0;
      cmd_n_capture_valid = needs_capture;
      cmd_n_capture_id = 3'd0;
      cmd_n_capture_bank = 1'b0;
      cmd_n_src_gpr = 5'd12;
      #1;
      if (!cmd_ready)
        fail("vector command queue should accept tensor command");
      tick();
      cmd_valid = 1'b0;
    end
  endtask

  task enqueue_dma_start_cmd;
    input [SEQ_ID_WIDTH-1:0] seq_id;
    begin
      cmd_valid = 1'b1;
      cmd_inst64 = dma_start_inst();
      cmd_seq_id = seq_id;
      cmd_epoch = 4'd1;
      cmd_capture_count = 3'd1;
      cmd_n_capture_valid = 1'b1;
      cmd_n_capture_id = 3'd1;
      cmd_n_capture_bank = 1'b0;
      cmd_n_src_gpr = 5'd14;
      cmd_base_capture_valid = 1'b0;
      #1;
      if (!cmd_ready)
        fail("vector command queue should accept dma start command");
      tick();
      cmd_valid = 1'b0;
      cmd_n_capture_valid = 1'b0;
      cmd_base_capture_valid = 1'b0;
    end
  endtask

  initial begin
    clk = 1'b0;
    rst_b = 1'b0;
    clear_inputs();
    repeat (3) tick();
    rst_b = 1'b1;
    tick();

    enqueue_tensor_cmd(tensor_inst(SUB_SETIN), 8'd7, 1'b1);
    if (issue_valid) fail("captured tensor command should wait for snapshot payload");
    send_snapshot(8'd7, 1'b1, 64'h0000_0000_0000_2340,
                  1'b0, {VALUE_WIDTH{1'b0}},
                  1'b0, {VALUE_WIDTH{1'b0}});
    #1;
    if (!issue_valid || !issue_ready)
      fail("tensor command should issue after snapshot payload ready");
    if (!cmd_setin_req || cmd_setin_ptr != 16'h2340)
      fail("accelerator pipe did not receive setin payload from command queue");
    if (!pipe_capture_consume_valid)
      fail("tensor issue should mark setup operand consumed");
    if (!pipe_done_valid || pipe_done_seq_id != 8'd7 || pipe_done_epoch != 4'd1)
      fail("accelerator pipe done identity mismatch");
    tick();

    enqueue_tensor_cmd(tensor_inst(SUB_START), 8'd8, 1'b0);
    #1;
    if (!issue_valid || !issue_ready || !cmd_start_req)
      fail("capture-free tensor start should pass through vector queue");
    tick();

    enqueue_tensor_cmd(tensor_inst(SUB_DMA_SETSRC), 8'd6, 1'b1);
    send_snapshot(8'd6, 1'b1, 64'h0000_0000_8000_0100,
                  1'b0, 64'b0, 1'b0, 64'b0);
    enqueue_tensor_cmd(tensor_inst(SUB_DMA_SETTAR), 8'd7, 1'b1);
    send_snapshot(8'd7, 1'b1, 64'h0000_0000_8000_0200,
                  1'b0, 64'b0, 1'b0, 64'b0);

    enqueue_dma_start_cmd(8'd9);
    if (issue_valid) fail("dma start should wait for snapshot payloads");
    send_snapshot(8'd9, 1'b1, 64'h0000_0000_0000_0040,
                  1'b0, 64'b0, 1'b0, 64'b0);
    #1;
    if (!issue_valid || !issue_ready)
      fail("dma start should issue after snapshot payloads are ready");
    if (!dma_start_req ||
        dma_start_src != 64'h0000_0000_8000_0100 ||
        dma_start_dst != 64'h0000_0000_8000_0200 ||
        dma_start_len != 32'h0000_0040) begin
      fail("dma start did not receive snapshot payloads from vector queue");
    end
    if (!pipe_capture_consume_valid) begin
      fail("dma start should consume len operand");
    end
    if (!pipe_done_valid || pipe_done_seq_id != 8'd9 || pipe_done_epoch != 4'd1)
      fail("dma start done identity mismatch");
    tick();

    // seq 11 reuses seq 7's physical snapshot slot (low two bits = 3).
    // It must wait for its own holder payload, not observe the released slot.
    enqueue_tensor_cmd(tensor_inst(SUB_SETIN), 8'd11, 1'b1);
    if (issue_valid) fail("reused snapshot slot must wait for new payload");
    send_snapshot(8'd11, 1'b1, 64'h0000_0000_0000_4560,
                  1'b0, {VALUE_WIDTH{1'b0}},
                  1'b0, {VALUE_WIDTH{1'b0}});
    #1;
    if (!issue_valid || !issue_ready || !cmd_setin_req ||
        cmd_setin_ptr != 16'h4560)
      fail("reused snapshot slot must issue only with its new payload");
    tick();

    // A newer command may alias an occupied seq_id[1:0] pending-snapshot slot.
    // Per-entry operand storage allows both commands to remain queued without
    // replacing the older command's payload.
    allow_issue = 1'b0;
    enqueue_tensor_cmd(tensor_inst(SUB_SETIN), 8'd15, 1'b1);
    send_snapshot(8'd15, 1'b1, 64'h0000_0000_0000_5670,
                  1'b0, {VALUE_WIDTH{1'b0}},
                  1'b0, {VALUE_WIDTH{1'b0}});
    cmd_valid = 1'b1;
    cmd_inst64 = tensor_inst(SUB_SETIN);
    cmd_seq_id = 8'd19;
    cmd_epoch = 4'd1;
    cmd_capture_count = 3'd1;
    cmd_n_capture_valid = 1'b1;
    #1;
    if (!cmd_ready) fail("snapshot alias must not backpressure command enqueue");
    send_snapshot(8'd19, 1'b1, 64'h0000_0000_0000_6780,
                  1'b0, {VALUE_WIDTH{1'b0}},
                  1'b0, {VALUE_WIDTH{1'b0}});
    cmd_valid = 1'b0;
    cmd_n_capture_valid = 1'b0;
    #1;
    if (!issue_valid || issue_n_value != 64'h0000_0000_0000_5670)
      fail("new snapshot write replaced older entry payload");
    allow_issue = 1'b1;
    #1;
    if (!issue_ready)
      fail("older aliased command should remain issuable");
    tick();
    #1;
    if (!issue_valid || !issue_ready || cmd_setin_ptr != 16'h6780)
      fail("new aliased entry did not retain its own snapshot payload");
    tick();

    // Keep an older command blocked on its snapshot and the downstream pipe,
    // then kill two younger entries across ff -> 00 with a one-cycle redirect.
    // Only the older setin may reach the pipe after backpressure is released.
    allow_issue = 1'b0;
    enqueue_tensor_cmd(tensor_inst(SUB_SETIN), 8'hff, 1'b1);
    enqueue_tensor_cmd(tensor_inst(SUB_START), 8'h00, 1'b0);
    enqueue_tensor_cmd(tensor_inst(SUB_START), 8'h01, 1'b0);
    redirect_valid = 1'b1;
    redirect_seq_id = 8'hff;
    redirect_epoch = 4'h1;
    tick();
    redirect_valid = 1'b0;
    send_snapshot(8'hff, 1'b1, 64'h0000_0000_0000_7890,
                  1'b0, {VALUE_WIDTH{1'b0}},
                  1'b0, {VALUE_WIDTH{1'b0}});
    if (!issue_valid || issue_seq_id != 8'hff)
      fail("older wrap-boundary command did not survive redirect");
    allow_issue = 1'b1;
    repeat (5) tick();
    if (setin_req_count != 5)
      fail("older wrap-boundary command did not issue exactly once");
    if (start_req_count != 1)
      fail("younger wraparound command escaped redirect into pipe");
    if (queue_count != 0)
      fail("redirect-killed bridge entries were not drained");

    // Command plus holder arriving in the redirect cycle must both be killed.
    // Reuse the same physical snapshot slot with a new epoch and prove that no
    // ghost payload from the killed command reaches the accelerator pipe.
    allow_issue = 1'b0;
    cmd_valid = 1'b1;
    cmd_inst64 = tensor_inst(SUB_SETIN);
    cmd_seq_id = 8'h21;
    cmd_epoch = 4'h2;
    cmd_n_capture_valid = 1'b1;
    snapshot_valid = 1'b1;
    snapshot_seq_id = 8'h21;
    snapshot_epoch = 4'h2;
    snapshot_target = 2'b01;
    snapshot_n_valid = 1'b1;
    snapshot_n_value = 64'h0000_0000_0000_dead;
    redirect_valid = 1'b1;
    redirect_seq_id = 8'h20;
    redirect_epoch = 4'h2;
    tick();
    cmd_valid = 1'b0;
    cmd_n_capture_valid = 1'b0;
    snapshot_valid = 1'b0;
    snapshot_n_valid = 1'b0;
    redirect_valid = 1'b0;
    allow_issue = 1'b1;
    repeat (3) tick();
    if (setin_req_count != 5 || queue_count != 0)
      fail("redirect-cycle command or ghost snapshot escaped into pipe");

    allow_issue = 1'b0;
    cmd_valid = 1'b1;
    cmd_inst64 = tensor_inst(SUB_SETIN);
    cmd_seq_id = 8'h25;
    cmd_epoch = 4'h3;
    cmd_n_capture_valid = 1'b1;
    tick();
    cmd_valid = 1'b0;
    cmd_n_capture_valid = 1'b0;
    snapshot_valid = 1'b1;
    snapshot_seq_id = 8'h25;
    snapshot_epoch = 4'h3;
    snapshot_target = 2'b01;
    snapshot_n_valid = 1'b1;
    snapshot_n_value = 64'h0000_0000_0000_9ab0;
    tick();
    snapshot_valid = 1'b0;
    snapshot_n_valid = 1'b0;
    if (!issue_valid || issue_n_value != 64'h0000_0000_0000_9ab0)
      fail("new epoch did not safely reuse killed snapshot slot");
    allow_issue = 1'b1;
    tick();
    if (setin_req_count != 6 || queue_count != 0)
      fail("reused snapshot slot did not issue exactly once through pipe");

    // A fully captured DMA command may be visible at the queue head while the
    // accelerator pipe is backpressured.  Redirect must remove it without a
    // single externally visible dma_start_req pulse.
    allow_issue = 1'b0;
    cmd_valid = 1'b1;
    cmd_inst64 = dma_start_inst();
    cmd_seq_id = 8'h40;
    cmd_epoch = 4'h6;
    cmd_n_capture_valid = 1'b1;
    cmd_base_capture_valid = 1'b1;
    tick();
    cmd_valid = 1'b0;
    cmd_n_capture_valid = 1'b0;
    cmd_base_capture_valid = 1'b0;
    snapshot_valid = 1'b1;
    snapshot_seq_id = 8'h40;
    snapshot_epoch = 4'h6;
    snapshot_target = 2'b00;
    snapshot_n_valid = 1'b1;
    snapshot_n_value = 64'h0000_0000_8000_1000;
    snapshot_base_valid = 1'b1;
    snapshot_base_value = 64'h0000_0000_8000_2000;
    snapshot_rd_valid = 1'b1;
    snapshot_rd_value = 64'h0000_0000_0000_0080;
    tick();
    snapshot_valid = 1'b0;
    snapshot_n_valid = 1'b0;
    snapshot_base_valid = 1'b0;
    snapshot_rd_valid = 1'b0;
    if (!issue_valid || issue_seq_id != 8'h40 || issue_ready)
      fail("captured DMA command did not remain parked under backpressure");
    redirect_valid = 1'b1;
    redirect_seq_id = 8'h3f;
    redirect_epoch = 4'h6;
    tick();
    redirect_valid = 1'b0;
    allow_issue = 1'b1;
    repeat (3) tick();
    if (dma_start_req_count != 1 || queue_count != 0)
      fail("redirected DMA command produced a side effect");

    // An early holder can live in the snapshot store before its command is
    // enqueued.  Redirect must clear that parked payload so a later command
    // reusing the low slot under a new epoch cannot consume ghost data.
    allow_issue = 1'b0;
    snapshot_valid = 1'b1;
    snapshot_seq_id = 8'h31;
    snapshot_epoch = 4'h7;
    snapshot_target = 2'b01;
    snapshot_n_valid = 1'b1;
    snapshot_n_value = 64'h0000_0000_0000_bad1;
    tick();
    snapshot_valid = 1'b0;
    snapshot_n_valid = 1'b0;
    redirect_valid = 1'b1;
    redirect_seq_id = 8'h30;
    redirect_epoch = 4'h7;
    tick();
    redirect_valid = 1'b0;

    cmd_valid = 1'b1;
    cmd_inst64 = tensor_inst(SUB_SETIN);
    cmd_seq_id = 8'h35;
    cmd_epoch = 4'h8;
    cmd_n_capture_valid = 1'b1;
    tick();
    cmd_valid = 1'b0;
    cmd_n_capture_valid = 1'b0;
    if (issue_valid)
      fail("new epoch consumed a redirect-killed early snapshot");
    snapshot_valid = 1'b1;
    snapshot_seq_id = 8'h35;
    snapshot_epoch = 4'h8;
    snapshot_target = 2'b01;
    snapshot_n_valid = 1'b1;
    snapshot_n_value = 64'h0000_0000_0000_caf1;
    tick();
    snapshot_valid = 1'b0;
    snapshot_n_valid = 1'b0;
    if (!issue_valid || issue_n_value != 64'h0000_0000_0000_caf1)
      fail("new epoch did not accept fresh early-snapshot replacement");
    allow_issue = 1'b1;
    tick();
    if (setin_req_count != 7 || queue_count != 0)
      fail("fresh snapshot replacement did not issue exactly once");

    $display("EDGE_ACCEL_QUEUE_BRIDGE TEST PASS");
    $finish;
  end
endmodule
