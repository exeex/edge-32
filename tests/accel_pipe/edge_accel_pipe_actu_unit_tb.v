`timescale 1ns/1ps

module edge_accel_pipe_actu_unit_tb;
  localparam [6:0] EDGE64_OPCODE = 7'h3f;
  localparam [6:0] SUB_ACTU_SETCSR = 7'h20;
  localparam [6:0] SUB_ACTU_SETIN  = 7'h21;
  localparam [6:0] SUB_ACTU_SETOUT = 7'h22;
  localparam [6:0] SUB_ACTU_SETN   = 7'h23;
  localparam [6:0] SUB_ACTU_START  = 7'h25;
  localparam [6:0] SUB_ACTU_SYNC   = 7'h26;

  reg clk;
  reg cpurst_b;
  reg cmd_valid;
  reg [63:0] cmd_inst64;
  reg [7:0] cmd_seq_id;
  reg [3:0] cmd_epoch;
  reg cmd_capture_valid;
  reg [63:0] cmd_capture_value;
  reg cmd_base_capture_valid;
  reg [63:0] cmd_base_capture_value;
  wire cmd_ready;
  wire tensor_done_valid;
  wire [7:0] tensor_done_seq_id;
  wire [3:0] tensor_done_epoch;
  wire [3:0] actu_cmd_setcsr_dtype;
  wire [3:0] actu_cmd_setcsr_mode;
  wire actu_cmd_setcsr_req;
  wire [15:0] actu_cmd_setin_ptr;
  wire actu_cmd_setin_req;
  wire actu_cmd_setn_req;
  wire [15:0] actu_cmd_setn_value;
  wire [15:0] actu_cmd_setout_ptr;
  wire actu_cmd_setout_req;
  wire actu_cmd_setscalar_req;
  wire [63:0] actu_cmd_setscalar_value;
  wire actu_cmd_start_req;
  wire actu_cmd_sync_req;
  wire actu_cmd_ready;
  wire actu_start_ready;
  wire actu_sync_stall;
  wire actu_busy;
  wire actu_done_valid;
  wire dtcm_rd_req;
  reg dtcm_rd_ready;
  wire [15:0] dtcm_rd_addr;
  reg dtcm_rd_rvalid;
  reg [127:0] dtcm_rd_rdata;
  wire dtcm_wr_req;
  reg dtcm_wr_ready;
  wire [15:0] dtcm_wr_addr;
  wire [127:0] dtcm_wr_wdata;
  wire [15:0] dtcm_wr_wstrb;

  reg rd_valid_q;
  integer wr_count;
  reg [15:0] wr_addr [0:7];
  reg [15:0] wr_mask [0:7];
  reg [127:0] wr_data [0:7];
  integer cycle;
  integer i;

  edge_accel_pipe pipe (
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
    .dma_start_ready(1'b1),
    .dma_start_circular_ready(1'b1),
    .dma_sync_done(1'b1),
    .tensor_cmd_ready(1'b1),
    .tensor_start_ready(1'b1),
    .tensor_wld_cmd_ready(1'b1),
    .tensor_wld_circular_ready(1'b1),
    .tensor_sync_stall(1'b0),
    .actu_cmd_ready(actu_cmd_ready),
    .actu_start_ready(actu_start_ready),
    .actu_sync_stall(actu_sync_stall),
    .cmd_ready(cmd_ready),
    .decode_illegal(),
    .capture_consume_valid(),
    .tensor_done_valid(tensor_done_valid),
    .tensor_done_seq_id(tensor_done_seq_id),
    .tensor_done_epoch(tensor_done_epoch),
    .dma_start_req(),
    .dma_start_circular_req(),
    .dma_start_src(),
    .dma_start_dst(),
  .dma_start_len(),
  .dma_start_entry_bytes(),
    .dma_start_circular_tiles(),
    .dma_start_use_xy(),
    .dma_start_circular(),
    .dma_start_x(),
    .dma_start_y(),
    .dma_sync_req(),
    .cmd_setcsr_dtype(),
    .cmd_setcsr_req(),
    .cmd_setcsr_wtype(),
    .cmd_setin_ptr(),
    .cmd_setin_req(),
    .cmd_setn_req(),
    .cmd_setn_value(),
    .cmd_setout_ptr(),
    .cmd_setout_req(),
    .cmd_setpsum_ptr(),
    .cmd_setpsum_req(),
    .cmd_start_req(),
    .cmd_start_tile_req(),
    .cmd_sync_req(),
    .cmd_wld_ptr(),
    .cmd_wld_req(),
    .cmd_wld_circular_req(),
    .cmd_wld_trans_req(),
    .actu_cmd_setcsr_dtype(actu_cmd_setcsr_dtype),
    .actu_cmd_setcsr_mode(actu_cmd_setcsr_mode),
    .actu_cmd_setcsr_req(actu_cmd_setcsr_req),
    .actu_cmd_setin_ptr(actu_cmd_setin_ptr),
    .actu_cmd_setin_req(actu_cmd_setin_req),
    .actu_cmd_setn_req(actu_cmd_setn_req),
    .actu_cmd_setn_value(actu_cmd_setn_value),
    .actu_cmd_setout_ptr(actu_cmd_setout_ptr),
    .actu_cmd_setout_req(actu_cmd_setout_req),
    .actu_cmd_setscalar_req(actu_cmd_setscalar_req),
    .actu_cmd_setscalar_value(actu_cmd_setscalar_value),
    .actu_cmd_start_req(actu_cmd_start_req),
    .actu_cmd_sync_req(actu_cmd_sync_req)
  );

  edge_actu_unit actu (
    .clk(clk),
    .cpurst_b(cpurst_b),
    .cmd_setcsr_dtype(actu_cmd_setcsr_dtype),
    .cmd_setcsr_mode(actu_cmd_setcsr_mode),
    .cmd_setcsr_req(actu_cmd_setcsr_req),
    .cmd_setin_ptr(actu_cmd_setin_ptr),
    .cmd_setin_req(actu_cmd_setin_req),
    .cmd_setout_ptr(actu_cmd_setout_ptr),
    .cmd_setout_req(actu_cmd_setout_req),
    .cmd_setn_req(actu_cmd_setn_req),
    .cmd_setn_value(actu_cmd_setn_value),
    .cmd_setscalar_req(actu_cmd_setscalar_req),
    .cmd_setscalar_value(actu_cmd_setscalar_value),
    .cmd_start_req(actu_cmd_start_req),
    .cmd_sync_req(actu_cmd_sync_req),
    .cmd_ready(actu_cmd_ready),
    .start_ready(actu_start_ready),
    .sync_stall(actu_sync_stall),
    .busy(actu_busy),
    .done_valid(actu_done_valid),
    .dtcm_rd_req(dtcm_rd_req),
    .dtcm_rd_ready(dtcm_rd_ready),
    .dtcm_rd_addr(dtcm_rd_addr),
    .dtcm_rd_rvalid(dtcm_rd_rvalid),
    .dtcm_rd_rdata(dtcm_rd_rdata),
    .dtcm_wr_req(dtcm_wr_req),
    .dtcm_wr_ready(dtcm_wr_ready),
    .dtcm_wr_addr(dtcm_wr_addr),
    .dtcm_wr_wdata(dtcm_wr_wdata),
    .dtcm_wr_wstrb(dtcm_wr_wstrb)
  );

  always #5 clk = ~clk;

  function [63:0] stream_inst;
    input [6:0] subop;
    input [4:0] rs1;
    reg [31:0] low_word;
    reg [31:0] high_word;
    begin
      low_word = {7'b0, 5'b0, rs1, 8'b0, EDGE64_OPCODE};
      high_word = {24'b0, 1'b1, subop};
      stream_inst = {high_word, low_word};
    end
  endfunction

  function [63:0] actu_setcsr_inst;
    input [3:0] dtype;
    input [3:0] mode;
    reg [31:0] low_word;
    reg [31:0] high_word;
    begin
      low_word = {25'b0, EDGE64_OPCODE};
      high_word = {7'b0, 1'b0, mode, 1'b0, dtype, 3'b0, 5'd1,
                   SUB_ACTU_SETCSR};
      actu_setcsr_inst = {high_word, low_word};
    end
  endfunction

  task fail;
    input [1023:0] msg;
    begin
      $display("EDGE_ACCEL_PIPE_ACTU_UNIT TEST FAIL: %0s", msg);
      $finish;
    end
  endtask

  task tick;
    begin
      @(posedge clk);
      #1;
      cycle = cycle + 1;
      if (cycle > 1000)
        fail("timeout");
    end
  endtask

  task clear_inputs;
    begin
      cmd_valid = 1'b0;
      cmd_inst64 = 64'b0;
      cmd_seq_id = 8'b0;
      cmd_epoch = 4'd1;
      cmd_capture_valid = 1'b0;
      cmd_capture_value = 64'b0;
      cmd_base_capture_valid = 1'b0;
      cmd_base_capture_value = 64'b0;
      dtcm_rd_ready = 1'b1;
      dtcm_rd_rvalid = 1'b0;
      dtcm_rd_rdata = 128'b0;
      dtcm_wr_ready = 1'b1;
      rd_valid_q = 1'b0;
      wr_count = 0;
      for (i = 0; i < 8; i = i + 1) begin
        wr_addr[i] = 16'b0;
        wr_mask[i] = 16'b0;
        wr_data[i] = 128'b0;
      end
    end
  endtask

  task send_cmd;
    input [63:0] inst;
    input [7:0] seq;
    input capture_valid;
    input [63:0] capture_value;
    input base_valid;
    input [63:0] base_value;
    begin
      cmd_valid = 1'b1;
      cmd_inst64 = inst;
      cmd_seq_id = seq;
      cmd_epoch = 4'd1;
      cmd_capture_valid = capture_valid;
      cmd_capture_value = capture_value;
      cmd_base_capture_valid = base_valid;
      cmd_base_capture_value = base_value;
      #1;
      if (!cmd_ready)
        fail("command should be ready");
      if (!tensor_done_valid || tensor_done_seq_id != seq ||
          tensor_done_epoch != 4'd1)
        fail("accepted ACTU command should complete through accelerator pipe");
      tick();
      cmd_valid = 1'b0;
      cmd_capture_valid = 1'b0;
      cmd_base_capture_valid = 1'b0;
    end
  endtask

  always @(posedge clk or negedge cpurst_b) begin
    if (!cpurst_b) begin
      rd_valid_q <= 1'b0;
      dtcm_rd_rvalid <= 1'b0;
      dtcm_rd_rdata <= 128'b0;
    end else begin
      dtcm_rd_rvalid <= rd_valid_q;
      dtcm_rd_rdata <= 128'b0;
      rd_valid_q <= dtcm_rd_req && dtcm_rd_ready;
    end
  end

  always @(posedge clk) begin
    if (cpurst_b && dtcm_wr_req && dtcm_wr_ready) begin
      wr_addr[wr_count] <= dtcm_wr_addr;
      wr_mask[wr_count] <= dtcm_wr_wstrb;
      wr_data[wr_count] <= dtcm_wr_wdata;
      wr_count <= wr_count + 1;
    end
  end

  initial begin
    clk = 1'b0;
    cpurst_b = 1'b0;
    cycle = 0;
    clear_inputs();
    repeat (4) tick();
    cpurst_b = 1'b1;
    tick();

    send_cmd(actu_setcsr_inst(4'd0, 4'd0), 8'd1, 1'b1, 64'd0, 1'b1, 64'd0);
    send_cmd(stream_inst(SUB_ACTU_SETIN, 5'd10), 8'd2, 1'b1,
             64'h0000_0000_0000_0020, 1'b0, 64'b0);
    send_cmd(stream_inst(SUB_ACTU_SETOUT, 5'd11), 8'd3, 1'b1,
             64'h0000_0000_0000_0100, 1'b0, 64'b0);
    send_cmd(stream_inst(SUB_ACTU_SETN, 5'd12), 8'd4, 1'b1, 64'd10,
             1'b0, 64'b0);
    send_cmd(stream_inst(SUB_ACTU_START, 5'd0), 8'd5, 1'b0, 64'b0,
             1'b0, 64'b0);

    cmd_valid = 1'b1;
    cmd_inst64 = stream_inst(SUB_ACTU_SYNC, 5'd0);
    cmd_seq_id = 8'd6;
    #1;
    if (cmd_ready)
      fail("ACTU sync should stall while unit is busy");
    while (!cmd_ready)
      tick();
    tick();
    cmd_valid = 1'b0;
    if (!tensor_done_valid || tensor_done_seq_id != 8'd6)
      fail("ACTU sync should complete after unit done");

    if (!actu_done_valid && actu_busy)
      fail("ACTU should be idle after sync completion");
    if (wr_count != 2)
      fail("decoded ACTU exp stream should write two DTCM beats");
    if (wr_addr[0] != 16'h0100 || wr_addr[1] != 16'h0102)
      fail("ACTU output write addresses mismatch");
    if (wr_mask[0] != 16'hffff || wr_mask[1] != 16'h000f)
      fail("ACTU output write masks mismatch");
    for (i = 0; i < 8; i = i + 1) begin
      if (wr_data[0][i*16 +: 16] != 16'h3f80)
        fail("ACTU first output beat should be BF16 exp(0)=1.0");
    end
    if (wr_data[1][15:0] != 16'h3f80 ||
        wr_data[1][31:16] != 16'h3f80)
      fail("ACTU tail output beat should be BF16 exp(0)=1.0");

    $display("EDGE_ACCEL_PIPE_ACTU_UNIT TEST PASS");
    $finish;
  end
endmodule
