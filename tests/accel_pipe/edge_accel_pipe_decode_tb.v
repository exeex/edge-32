`timescale 1ns/1ps

module edge_accel_pipe_decode_tb;
  localparam [6:0] EDGE64_OPCODE = 7'h3f;
  localparam [6:0] SUB_DMA_START = 7'h01;
  localparam [6:0] SUB_DMA_SYNC  = 7'h02;
  localparam [6:0] SUB_DMA_SETN  = 7'h03;
  localparam [6:0] SUB_DMA_SETX  = 7'h04;
  localparam [6:0] SUB_DMA_SETY  = 7'h05;
  localparam [6:0] SUB_DMA_SETSRC = 7'h06;
  localparam [6:0] SUB_DMA_SETTAR = 7'h07;
  localparam [6:0] SUB_DMA_SETENTRY = 7'h08;
  localparam [6:0] SUB_SETCSR    = 7'h10;
  localparam [6:0] SUB_WLD       = 7'h11;
  localparam [6:0] SUB_SETIN     = 7'h12;
  localparam [6:0] SUB_SETOUT    = 7'h13;
  localparam [6:0] SUB_SETPSUM   = 7'h14;
  localparam [6:0] SUB_START     = 7'h15;
  localparam [6:0] SUB_SYNC      = 7'h16;
  localparam [6:0] SUB_SETN      = 7'h17;
  localparam [6:0] SUB_WLD_T     = 7'h18;
  localparam [6:0] SUB_WLD_CIRCULAR = 7'h1b;
  localparam [6:0] SUB_WLD_T_CIRCULAR = 7'h1c;
  localparam [6:0] SUB_SLD       = 7'h1d;
  localparam [6:0] SUB_WSLD_CIRCULAR = 7'h1e;
  localparam [6:0] SUB_SLD_CIRCULAR = 7'h1f;
  localparam [6:0] SUB_SLD_STREAM = 7'h1a;
  localparam [6:0] SUB_CMPU_SETCSR = 7'h27;
  localparam [6:0] SUB_CMPU_SETLHS = 7'h28;
  localparam [6:0] SUB_CMPU_SYNC = 7'h2e;
  localparam [6:0] SUB_ACCEL_GETCSR = 7'h2f;

  reg         clk;
  reg         cpurst_b;
  reg         cmd_valid;
  reg  [63:0] cmd_inst64;
  reg  [7:0]  cmd_seq_id;
  reg  [3:0]  cmd_epoch;
  reg         cmd_capture_valid;
  reg  [63:0] cmd_capture_value;
  reg         cmd_base_capture_valid;
  reg  [63:0] cmd_base_capture_value;
  reg         cmd_rd_capture_valid;
  reg  [63:0] cmd_rd_capture_value;
  reg         dma_start_ready;
  reg         dma_start_circular_ready;
  reg         dma_sync_done;
  reg         tensor_cmd_ready;
  reg         tensor_start_ready;
  reg         tensor_wld_cmd_ready;
  reg         tensor_sld_cmd_ready;
  reg         tensor_wld_circular_ready;
  reg         tensor_wsld_circular_ready;
  reg         tensor_sld_circular_ready;
  reg         tensor_sync_stall;
  reg         cmpu_sync_stall;
  reg         reverse_snapshot_write_ready;

  wire        cmd_ready;
  wire        decode_illegal;
  wire        capture_consume_valid;
  wire        tensor_done_valid;
  wire [7:0]  tensor_done_seq_id;
  wire [3:0]  tensor_done_epoch;
  wire        dma_start_req;
  wire [63:0] dma_start_src;
  wire [63:0] dma_start_dst;
  wire [31:0] dma_start_len;
  wire [31:0] dma_start_entry_bytes;
  wire [15:0] dma_start_circular_tiles;
  wire        dma_start_use_xy;
  wire        dma_start_circular;
  wire [63:0] dma_start_x;
  wire [63:0] dma_start_y;
  wire        dma_start_circular_req;
  wire        dma_sync_req;
  wire [3:0]  cmd_setcsr_dtype;
  wire        cmd_setcsr_req;
  wire [3:0]  cmd_setcsr_wtype;
  wire [15:0] cmd_setin_ptr;
  wire        cmd_setin_req;
  wire        cmd_setn_req;
  wire [15:0] cmd_setn_value;
  wire [15:0] cmd_setout_ptr;
  wire        cmd_setout_req;
  wire [15:0] cmd_setpsum_ptr;
  wire        cmd_setpsum_req;
  wire        cmd_start_req;
  wire        cmd_start_tile_req;
  wire [7:0]  cmd_start_mode;
  wire        cmd_sync_req;
  wire [15:0] cmd_wld_ptr;
  wire        cmd_wld_req;
  wire        cmd_wld_circular_req;
  wire        cmd_wld_trans_req;
  wire        cmd_wld_reuse;
  wire [15:0] cmd_sld_ptr;
  wire        cmd_sld_req;
  wire        cmd_sld_reuse;
  wire [15:0] cmd_sld_stream_ptr;
  wire        cmd_sld_stream_req;
  wire        cmd_wsld_circular_req;
  wire        cmd_wsld_circular_transpose;
  wire        cmd_sld_circular_req;
  wire [3:0]  cmpu_cmd_setcsr_mode;
  wire        cmpu_cmd_setcsr_req;
  wire [15:0] cmpu_cmd_setlhs_ptr;
  wire        cmpu_cmd_setlhs_req;
  wire        cmpu_cmd_sync_req;
  wire        reverse_snapshot_write_valid;
  wire        reverse_snapshot_write_id;
  wire [63:0] reverse_snapshot_write_value;

  edge_accel_pipe dut(
    .forever_cpuclk(clk),
    .cpurst_b(cpurst_b),
    .mem_region_base(40'h0040_0000_00),
    .mem_region_mask(40'hffff_fe00_00),
    .mem_region_enable(1'b1),
    .cmd_valid(cmd_valid),
    .cmd_opcode8(8'b0),
    .cmd_imm8(8'b0),
    .cmd_inst64(cmd_inst64),
    .cmd_seq_id(cmd_seq_id),
    .cmd_epoch(cmd_epoch),
    .cmd_capture_valid(cmd_capture_valid),
    .cmd_capture_value(cmd_capture_value),
    .dma_start_ready(dma_start_ready),
    .dma_start_circular_ready(dma_start_circular_ready),
    .dma_sync_done(dma_sync_done),
    .tensor_cmd_ready(tensor_cmd_ready),
    .tensor_start_ready(tensor_start_ready),
    .tensor_wld_cmd_ready(tensor_wld_cmd_ready),
    .tensor_sld_cmd_ready(tensor_sld_cmd_ready),
    .tensor_wld_circular_ready(tensor_wld_circular_ready),
    .tensor_wsld_circular_ready(tensor_wsld_circular_ready),
    .tensor_sld_circular_ready(tensor_sld_circular_ready),
    .tensor_sync_stall(tensor_sync_stall),
    .actu_cmd_ready(1'b1),.actu_start_ready(1'b1),.actu_sync_stall(1'b0),
    .cmpu_cmd_ready(1'b1),.cmpu_start_ready(1'b1),.cmpu_sync_stall(cmpu_sync_stall),
    .actu_last_sum_bits(32'h3f80_0000),
    .cmpu_max_value(16'h40e0),
    .cmpu_argmax_idx(16'd6),
    .cmpu_min_value(16'hc100),
    .cmpu_argmin_idx(16'd7),
    .reverse_snapshot_write_ready(reverse_snapshot_write_ready),
    .cmd_ready(cmd_ready),
    .decode_illegal(decode_illegal),
    .capture_consume_valid(capture_consume_valid),
    .tensor_done_valid(tensor_done_valid),
    .tensor_done_seq_id(tensor_done_seq_id),
    .tensor_done_epoch(tensor_done_epoch),
    .dma_start_req(dma_start_req),
    .dma_start_circular_req(dma_start_circular_req),
    .dma_start_src(dma_start_src),
    .dma_start_dst(dma_start_dst),
    .dma_start_len(dma_start_len),
    .dma_start_entry_bytes(dma_start_entry_bytes),
    .dma_start_circular_tiles(dma_start_circular_tiles),
    .dma_start_use_xy(dma_start_use_xy),
    .dma_start_circular(dma_start_circular),
    .dma_start_x(dma_start_x),
    .dma_start_y(dma_start_y),
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
    .cmd_start_mode(cmd_start_mode),
    .cmd_sync_req(cmd_sync_req),
    .cmd_wld_ptr(cmd_wld_ptr),
    .cmd_wld_req(cmd_wld_req),
    .cmd_wld_circular_req(cmd_wld_circular_req),
    .cmd_wld_trans_req(cmd_wld_trans_req),
    .cmd_wld_reuse(cmd_wld_reuse),
    .cmd_sld_ptr(cmd_sld_ptr),
    .cmd_sld_req(cmd_sld_req),
    .cmd_sld_reuse(cmd_sld_reuse),
    .cmd_sld_stream_ptr(cmd_sld_stream_ptr),
    .cmd_sld_stream_req(cmd_sld_stream_req),
    .cmd_wsld_circular_req(cmd_wsld_circular_req),
    .cmd_wsld_circular_transpose(cmd_wsld_circular_transpose),
    .cmd_sld_circular_req(cmd_sld_circular_req),
    .cmpu_cmd_setcsr_mode(cmpu_cmd_setcsr_mode),
    .cmpu_cmd_setcsr_req(cmpu_cmd_setcsr_req),
    .cmpu_cmd_setlhs_ptr(cmpu_cmd_setlhs_ptr),
    .cmpu_cmd_setlhs_req(cmpu_cmd_setlhs_req),
    .cmpu_cmd_setrhs_ptr(),.cmpu_cmd_setrhs_req(),
    .cmpu_cmd_setmask_ptr(),.cmpu_cmd_setmask_req(),
    .cmpu_cmd_setout_ptr(),.cmpu_cmd_setout_req(),
    .cmpu_cmd_setn_req(),.cmpu_cmd_setn_value(),
    .cmpu_cmd_start_req(),.cmpu_cmd_sync_req(cmpu_cmd_sync_req),
    .reverse_snapshot_write_valid(reverse_snapshot_write_valid),
    .reverse_snapshot_write_id(reverse_snapshot_write_id),
    .reverse_snapshot_write_value(reverse_snapshot_write_value)
  );

  always #5 clk = ~clk;

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

  function [63:0] tensor_reg_inst;
    input [6:0] subop;
    input [4:0] rs1;
    reg [31:0] low_word;
    reg [31:0] high_word;
    begin
      low_word = {7'b0, 5'b0, rs1, 8'b0, EDGE64_OPCODE};
      high_word = {24'b0, 1'b1, subop};
      tensor_reg_inst = {high_word, low_word};
    end
  endfunction

  function [63:0] tensor_setcsr_inst;
    input [3:0] dtype;
    input [3:0] wtype;
    reg [31:0] low_word;
    reg [31:0] high_word;
    begin
      low_word = {25'b0, EDGE64_OPCODE};
      high_word = {7'b0, 1'b0, wtype, 1'b0, dtype, 3'b0, 5'd1, SUB_SETCSR};
      tensor_setcsr_inst = {high_word, low_word};
    end
  endfunction

  function [63:0] cmpu_setcsr_inst;
    input [3:0] mode;
    reg [31:0] low_word;
    reg [31:0] high_word;
    begin
      low_word = {25'b0, EDGE64_OPCODE};
      high_word = {7'b0, 5'b0, 1'b0, mode, 3'b0, 5'd1, SUB_CMPU_SETCSR};
      cmpu_setcsr_inst = {high_word, low_word};
    end
  endfunction

  function [63:0] accel_getcsr_inst;
    input snapshot_id;
    input [3:0] csr_id;
    reg [31:0] low_word;
    reg [31:0] high_word;
    begin
      low_word = {25'b0, EDGE64_OPCODE};
      high_word = 32'd0;
      high_word[7:0] = {1'b1, SUB_ACCEL_GETCSR};
      high_word[20:15] = {snapshot_id, 1'b0, csr_id};
      accel_getcsr_inst = {high_word, low_word};
    end
  endfunction

  function [63:0] dma_start_inst;
    input [1:0] mode;
    reg [31:0] low_word;
    reg [31:0] high_word;
    begin
      low_word = {20'b0, 5'd14, EDGE64_OPCODE};
      high_word = {6'b0, mode, 16'b0, 1'b1, SUB_DMA_START};
      dma_start_inst = {high_word, low_word};
    end
  endfunction

  task fail;
    input [1023:0] msg;
    begin
      $display("FAIL: %0s", msg);
      $finish;
    end
  endtask

  task expect_idle;
    begin
      if (cmd_setcsr_req || cmd_wld_req || cmd_wld_trans_req ||
          cmd_sld_req || cmd_sld_stream_req || cmd_wsld_circular_req ||
          cmd_sld_circular_req ||
          cmd_setin_req || cmd_setout_req || cmd_setpsum_req ||
          cmd_setn_req || cmd_start_req || cmd_start_tile_req || cmd_sync_req ||
          dma_start_req || dma_sync_req ||
          tensor_done_valid || capture_consume_valid) begin
        fail("unexpected command pulse");
      end
    end
  endtask

  initial begin
    clk = 1'b0;
    cpurst_b = 1'b0;
    cmd_valid = 1'b0;
    cmd_inst64 = 64'b0;
    cmd_seq_id = 8'h00;
    cmd_epoch = 4'h0;
    cmd_capture_valid = 1'b0;
    cmd_capture_value = 64'b0;
    cmd_base_capture_valid = 1'b0;
    cmd_base_capture_value = 64'b0;
    cmd_rd_capture_valid = 1'b0;
    cmd_rd_capture_value = 64'b0;
    dma_start_ready = 1'b1;
    dma_start_circular_ready = 1'b1;
    dma_sync_done = 1'b1;
    tensor_cmd_ready = 1'b1;
    tensor_start_ready = 1'b1;
    tensor_wld_cmd_ready = 1'b1;
    tensor_sld_cmd_ready = 1'b1;
    tensor_wld_circular_ready = 1'b1;
    tensor_wsld_circular_ready = 1'b1;
    tensor_sld_circular_ready = 1'b1;
    tensor_sync_stall = 1'b0;
    cmpu_sync_stall = 1'b0;
    reverse_snapshot_write_ready = 1'b1;

    repeat (2) @(posedge clk);
    cpurst_b = 1'b1;
    @(posedge clk);

    cmd_valid = 1'b1;
    cmd_inst64 = tensor_inst(SUB_SETIN);
    cmd_seq_id = 8'h21;
    cmd_epoch = 4'h3;
    cmd_capture_valid = 1'b1;
    cmd_capture_value = 64'h0000_0000_0000_a5c0;
    #1;
    if (!cmd_ready || !cmd_setin_req || cmd_setin_ptr != 16'ha5c0) fail("setin decode");
    if (!capture_consume_valid || !tensor_done_valid) fail("setin completion");
    if (tensor_done_seq_id != 8'h21 || tensor_done_epoch != 4'h3) fail("done identity");

    tensor_cmd_ready = 1'b0;
    cmd_inst64 = tensor_inst(SUB_SETOUT);
    cmd_capture_value = 64'h0000_0000_0000_4410;
    #1;
    if (cmd_ready) fail("setout ready while tensor command not ready");
    expect_idle();

    tensor_cmd_ready = 1'b1;
    cmd_capture_valid = 1'b0;
    #1;
    if (cmd_ready) fail("pointer command ready without capture payload");
    expect_idle();

    cmd_capture_valid = 1'b1;
    #1;
    if (!cmd_ready || !cmd_setout_req || cmd_setout_ptr != 16'h4410) fail("setout decode");

    cmd_capture_value = 64'h0000_0000_4001_0000;
    #1;
    if (!cmd_setout_req || cmd_setout_ptr != 16'h2000)
      fail("upper 64KiB DTCM pointer decode");

    cmd_inst64 = tensor_inst(SUB_SETPSUM);
    cmd_capture_value = 64'h0000_0000_0000_5520;
    #1;
    if (!cmd_setpsum_req || cmd_setpsum_ptr != 16'h5520) fail("setpsum decode");

    cmd_inst64 = tensor_reg_inst(SUB_SETN, 5'd1);
    cmd_capture_value = 64'h0000_0000_0000_0042;
    #1;
    if (!cmd_setn_req || cmd_setn_value != 16'h0042) fail("setn GPR decode");
    if (!capture_consume_valid) fail("setn GPR capture consume");

    cmd_inst64 = tensor_inst(SUB_WLD);
    cmd_capture_value = 64'h0000_0000_0000_6640;
    #1;
    if (!cmd_wld_req || cmd_wld_trans_req || cmd_wld_reuse
        || cmd_wld_ptr != 16'h6640 || !capture_consume_valid)
      fail("wld decode");

    cmd_capture_valid = 1'b0;
    cmd_inst64[57] = 1'b1;
    #1;
    if (!cmd_ready || !cmd_wld_req || !cmd_wld_reuse
        || capture_consume_valid)
      fail("wld reuse immediate decode");

    cmd_capture_valid = 1'b1;
    cmd_inst64 = tensor_inst(SUB_WLD_T);
    cmd_capture_value = 64'h0000_0000_0000_7780;
    #1;
    if (!cmd_wld_trans_req || cmd_wld_req || cmd_wld_reuse
        || cmd_wld_ptr != 16'h7780) fail("wld_t decode");

    cmd_capture_valid = 1'b0;
    cmd_inst64[57] = 1'b1;
    #1;
    if (!cmd_ready || !cmd_wld_trans_req || !cmd_wld_reuse
        || capture_consume_valid)
      fail("wld_t reuse immediate decode");

    cmd_capture_valid = 1'b0;
    cmd_inst64 = tensor_inst(SUB_WLD_CIRCULAR);
    #1;
    if (!cmd_wld_circular_req || cmd_wld_trans_req || !cmd_ready)
      fail("wld_circular decode");

    cmd_inst64 = tensor_inst(SUB_WLD_T_CIRCULAR);
    #1;
    if (!cmd_wld_circular_req || !cmd_wld_trans_req || !cmd_ready)
      fail("wld_t_circular decode");

    cmd_capture_valid = 1'b1;
    cmd_capture_value = 64'h0000_0000_0000_4320;
    cmd_inst64 = tensor_inst(SUB_SLD);
    #1;
    if (!cmd_sld_req || cmd_sld_ptr != 16'h4320 || !capture_consume_valid)
      fail("sld decode");

    cmd_capture_valid = 1'b0;
    cmd_inst64[57] = 1'b1;
    #1;
    if (!cmd_ready || !cmd_sld_req || !cmd_sld_reuse
        || capture_consume_valid)
      fail("sld reuse immediate decode");

    cmd_capture_valid = 1'b1;
    cmd_capture_value = 64'h0000_0000_0000_4560;
    cmd_inst64 = tensor_inst(SUB_SLD_STREAM);
    #1;
    if (!cmd_ready || !cmd_sld_stream_req ||
        cmd_sld_stream_ptr != 16'h4560 || !capture_consume_valid)
      fail("sld_stream decode");

    cmd_capture_valid = 1'b0;
    cmd_inst64 = tensor_inst(SUB_WSLD_CIRCULAR);
    cmd_inst64[56] = 1'b1;
    #1;
    if (!cmd_wsld_circular_req || !cmd_wsld_circular_transpose || !cmd_ready)
      fail("wsld_circular decode");

    cmd_inst64 = tensor_inst(SUB_SLD_CIRCULAR);
    #1;
    if (!cmd_sld_circular_req || !cmd_ready)
      fail("sld_circular decode");

    cmd_inst64 = tensor_setcsr_inst(4'h6, 4'h9);
    #1;
    if (!cmd_ready || !cmd_setcsr_req) fail("setcsr ready");
    if (cmd_setcsr_dtype != 4'h6 || cmd_setcsr_wtype != 4'h9) fail("setcsr fields");
    if (capture_consume_valid) fail("setcsr consumed capture");

    cmd_inst64 = tensor_inst(SUB_START);
    cmd_inst64[63:56] = 8'ha5;
    tensor_cmd_ready = 1'b1;
    #1;
    if (!cmd_ready || !cmd_start_req || cmd_start_mode != 8'ha5)
      fail("start imm8 mode decode");

    cmd_inst64 = tensor_inst(SUB_SYNC);
    tensor_cmd_ready = 1'b0;
    tensor_sync_stall = 1'b1;
    #1;
    if (cmd_ready || cmd_sync_req || tensor_done_valid) fail("sync ready while stalled");

    tensor_sync_stall = 1'b0;
    #1;
    if (!cmd_ready || !cmd_sync_req || !tensor_done_valid) fail("sync release");

    cmd_inst64 = tensor_reg_inst(SUB_DMA_SETSRC, 5'd1);
    cmd_capture_valid = 1'b1;
    cmd_capture_value = 64'h0000_0000_8000_0100;
    tensor_cmd_ready = 1'b1;
    #1;
    if (!cmd_ready || !capture_consume_valid) fail("dma setsrc decode");
    @(posedge clk);
    #1;
    cmd_inst64 = tensor_reg_inst(SUB_DMA_SETTAR, 5'd1);
    cmd_capture_value = 64'h0000_0000_8000_0200;
    if (!cmd_ready || !capture_consume_valid) fail("dma settar decode");
    @(posedge clk);
    #1;

    cmd_inst64 = dma_start_inst(2'b00);
    cmd_capture_value = 64'h0000_0000_0000_0040;
    dma_start_ready = 1'b1;
    #1;
    if (!cmd_ready || !dma_start_req || !tensor_done_valid) fail("dma start decode");
    if (!capture_consume_valid) fail("dma start capture");
    if (dma_start_src != 64'h0000_0000_8000_0100 ||
        dma_start_dst != 64'h0000_0000_8000_0200 ||
        dma_start_len != 32'h0000_0040) begin
      fail("dma start fields");
    end

    dma_start_ready = 1'b0;
    #1;
    if (cmd_ready || dma_start_req || tensor_done_valid) fail("dma start ready while busy");

    dma_start_ready = 1'b1;
    cmd_capture_valid = 1'b0;
    #1;
    if (cmd_ready || dma_start_req || tensor_done_valid) fail("dma start ready without len capture");

    cmd_capture_valid = 1'b1;
    tensor_cmd_ready = 1'b1;
    cmd_inst64 = tensor_reg_inst(SUB_DMA_SETN, 5'd1);
    cmd_capture_value = 64'd64;
    #1;
    if (!cmd_ready || !capture_consume_valid) fail("dma setn decode");
    @(posedge clk);
    #1;
    cmd_inst64 = tensor_reg_inst(SUB_DMA_SETENTRY, 5'd1);
    cmd_capture_value = 64'd128;
    if (!cmd_ready || !capture_consume_valid) fail("dma setentry decode");
    @(posedge clk);
    #1;
    cmd_inst64 = tensor_reg_inst(SUB_DMA_SETX, 5'd1);
    cmd_capture_value = {32'd64, 32'd4096};
    @(posedge clk);
    #1;
    cmd_inst64 = tensor_reg_inst(SUB_DMA_SETY, 5'd1);
    cmd_capture_value = {32'd1, 32'd0};
    @(posedge clk);
    #1;

    cmd_inst64 = dma_start_inst(2'b01);
    cmd_capture_value = 64'hffff_ffff_dead_beef;
    #1;
    if (!cmd_ready || !dma_start_req || dma_start_circular_req)
      fail("strided dma start decode");
    if (!dma_start_use_xy || dma_start_circular ||
        dma_start_len != 32'd64 ||
        dma_start_x != {32'd64, 32'd4096} ||
        dma_start_y != {32'd1, 32'd0})
      fail("strided dma descriptor fields");

    cmd_inst64 = dma_start_inst(2'b10);
    cmd_capture_value = 64'd17;
    #1;
    if (!cmd_ready || !dma_start_req || !dma_start_circular_req ||
        dma_start_use_xy || !dma_start_circular ||
        dma_start_entry_bytes != 32'd128 ||
        dma_start_circular_tiles != 16'd17)
      fail("circular dma mode immediate");

    cmd_capture_valid = 1'b0;
    cmd_base_capture_valid = 1'b0;
    cmd_inst64 = tensor_inst(SUB_DMA_SYNC);
    dma_sync_done = 1'b0;
    #1;
    if (cmd_ready || dma_sync_req || tensor_done_valid) fail("dma sync ready while busy");

    dma_sync_done = 1'b1;
    #1;
    if (!cmd_ready || !dma_sync_req || !tensor_done_valid) fail("dma sync release");

    cmd_capture_valid = 1'b0;
    cmd_inst64 = cmpu_setcsr_inst(4'd8);
    #1;
    if (!cmd_ready || !cmpu_cmd_setcsr_req || cmpu_cmd_setcsr_mode != 4'd8)
      fail("cmpu setcsr decode");
    if (capture_consume_valid) fail("cmpu setcsr consumed capture");

    cmd_inst64 = tensor_reg_inst(SUB_CMPU_SETLHS, 5'd4);
    cmd_capture_valid = 1'b1;
    cmd_capture_value = 64'h0000_0000_0000_3450;
    #1;
    if (!cmd_ready || !cmpu_cmd_setlhs_req || cmpu_cmd_setlhs_ptr != 16'h3450 ||
        !capture_consume_valid)
      fail("cmpu setlhs decode");

    cmd_capture_valid = 1'b0;
    cmd_inst64 = tensor_inst(SUB_CMPU_SYNC);
    cmpu_sync_stall = 1'b1;
    #1;
    if (cmd_ready || cmpu_cmd_sync_req || tensor_done_valid)
      fail("cmpu sync ready while busy");
    cmpu_sync_stall = 1'b0;
    #1;
    if (!cmd_ready || !cmpu_cmd_sync_req || !tensor_done_valid)
      fail("cmpu sync release");

    cmd_inst64 = accel_getcsr_inst(1'b1, 4'd0);
    reverse_snapshot_write_ready = 1'b0;
    #1;
    if (cmd_ready || reverse_snapshot_write_valid)
      fail("getcsr ignored reverse snapshot backpressure");
    reverse_snapshot_write_ready = 1'b1;
    cmpu_sync_stall = 1'b1;
    #1;
    if (cmd_ready || reverse_snapshot_write_valid)
      fail("cmpu getcsr sampled a busy owner");
    cmpu_sync_stall = 1'b0;
    #1;
    if (!cmd_ready || !reverse_snapshot_write_valid ||
        reverse_snapshot_write_id != 1'b1 ||
        reverse_snapshot_write_value != 64'h0000_0000_0000_40e0)
      fail("cmpu getcsr snapshot value");

    cmd_inst64 = accel_getcsr_inst(1'b0, 4'd4);
    #1;
    if (!cmd_ready || !reverse_snapshot_write_valid ||
        reverse_snapshot_write_id != 1'b0 ||
        reverse_snapshot_write_value != 64'h0000_0000_3f80_0000)
      fail("actu exp-sum getcsr snapshot value");

    cmd_inst64 = accel_getcsr_inst(1'b0, 4'd5);
    #1;
    if (!decode_illegal || !cmd_ready || reverse_snapshot_write_valid)
      fail("unknown getcsr id must be illegal without snapshot write");

    cmd_inst64 = 64'h0;
    tensor_cmd_ready = 1'b1;
    #1;
    if (!decode_illegal || !cmd_ready) fail("illegal command sink");

    $display("EDGE_ACCEL_PIPE_DECODE TEST PASS");
    $finish;
  end
endmodule
