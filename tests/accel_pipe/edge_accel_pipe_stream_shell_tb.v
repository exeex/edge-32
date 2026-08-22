`timescale 1ns/1ps

module edge_accel_pipe_stream_shell_tb;

localparam ADDR_WIDTH = 16;
localparam BANK_NUM = 16;
localparam SETN = 32;
localparam [6:0] EDGE64_OPCODE = 7'h3f;
localparam [6:0] SUB_SETCSR    = 7'h10;
localparam [6:0] SUB_WLD       = 7'h11;
localparam [6:0] SUB_SETIN     = 7'h12;
localparam [6:0] SUB_SETOUT    = 7'h13;
localparam [6:0] SUB_SETPSUM   = 7'h14;
localparam [6:0] SUB_START     = 7'h15;
localparam [6:0] SUB_SETN      = 7'h17;
localparam [ADDR_WIDTH-1:0] IN_BASE = 16'h0100;
localparam [ADDR_WIDTH-1:0] PSUM_BASE = 16'h0200;
localparam [ADDR_WIDTH-1:0] OUT_BASE = 16'h0300;
localparam [ADDR_WIDTH-1:0] WGT_BASE = 16'h0400;

reg clk;
reg cpurst_b;

reg         pipe_cmd_valid;
reg  [63:0] pipe_cmd_inst64;
reg  [7:0]  pipe_cmd_seq_id;
reg  [3:0]  pipe_cmd_epoch;
reg         pipe_cmd_capture_valid;
reg  [63:0] pipe_cmd_capture_value;
reg         pipe_cmd_base_capture_valid;
reg  [63:0] pipe_cmd_base_capture_value;
wire        pipe_cmd_ready;
wire        pipe_decode_illegal;
wire        pipe_capture_consume_valid;
wire        pipe_done_valid;
wire [7:0]  pipe_done_seq_id;
wire [3:0]  pipe_done_epoch;

wire        cmd_setcsr_req;
wire [3:0]  cmd_setcsr_dtype;
wire [3:0]  cmd_setcsr_wtype;
wire        cmd_wld_req;
wire        cmd_wld_trans_req;
wire [ADDR_WIDTH-1:0] cmd_wld_ptr;
wire        cmd_setin_req;
wire [ADDR_WIDTH-1:0] cmd_setin_ptr;
wire        cmd_setout_req;
wire [ADDR_WIDTH-1:0] cmd_setout_ptr;
wire        cmd_setpsum_req;
wire [ADDR_WIDTH-1:0] cmd_setpsum_ptr;
wire        cmd_setn_req;
wire [15:0] cmd_setn_value;
wire        cmd_start_req;
wire        cmd_start_tile_req;
wire        cmd_sync_req;

wire tensor_busy;
wire tensor_cmd_ready;
wire tensor_start_ready;
wire tensor_wld_cmd_ready;
wire tensor_sync_stall;
wire [ADDR_WIDTH-1:0] tensor_addr;
wire tensor_req;
wire tensor_we;
wire [63:0] tensor_wdata;
wire [7:0] tensor_wstrb;
wire [ADDR_WIDTH-1:0] tensor_lane1_addr;
wire tensor_lane1_req;
wire tensor_lane1_we;
wire [63:0] tensor_lane1_wdata;
wire [7:0] tensor_lane1_wstrb;
wire [ADDR_WIDTH-1:0] tensor_lane2_addr;
wire tensor_lane2_req;
wire tensor_lane2_we;
wire [127:0] tensor_lane2_pair_wdata;
wire [15:0] tensor_lane2_pair_wstrb;
wire [63:0] tensor_lane2_wdata;
wire [7:0] tensor_lane2_wstrb;
wire [BANK_NUM-1:0] cur_tensor_in_req_mask;
wire [BANK_NUM-1:0] cur_tensor_out_req_mask;
wire [BANK_NUM-1:0] cur_tensor_prefetch_req_mask;
wire [BANK_NUM-1:0] tensor_resv_plus2_mask;
wire tensor_resv_plus2_req;
wire dma_delay_req;
wire [7:0] tensor_io_lease_channel_mask;
wire [8:0] tensor_io_lease_cycles;
wire [3:0] tensor_io_lease_delay;
wire [7:0] tensor_io_lease1_channel_mask;
wire [8:0] tensor_io_lease1_cycles;
wire [3:0] tensor_io_lease1_delay;
wire tensor_io_lease1_valid;
wire [7:0] tensor_io_lease2_channel_mask;
wire [8:0] tensor_io_lease2_cycles;
wire [3:0] tensor_io_lease2_delay;
wire tensor_io_lease2_valid;
wire tensor_io_lease_valid;
wire [7:0] tensor_wld_lease_channel_mask;
wire [8:0] tensor_wld_lease_cycles;
wire [3:0] tensor_wld_lease_delay;
wire tensor_wld_lease_valid;
wire [3:0] dbg_dtype;
wire [3:0] dbg_wtype;
wire [1:0] dbg_i_comp_delay;
wire [2:0] dbg_i_lease_channel;
wire [8:0] dbg_i_lease_cycles;
wire [3:0] dbg_i_lease_delay;
wire dbg_iopsum_plan_valid;
wire [1:0] dbg_o_comp_delay;
wire [2:0] dbg_o_lease_channel;
wire [8:0] dbg_o_lease_cycles;
wire [3:0] dbg_o_lease_delay;
wire [2:0] dbg_phase;
wire [1:0] dbg_psum_comp_delay;
wire [2:0] dbg_psum_lease_channel;
wire [8:0] dbg_psum_lease_cycles;
wire [3:0] dbg_psum_lease_delay;
wire [2:0] dbg_step;
wire [2:0] dbg_start_phase;

reg [63:0] tensor_rdata;
reg tensor_rvalid;
wire [63:0] tensor_lane1_data;
wire tensor_lane1_hi;
reg [127:0] tensor_lane1_pair_rdata;
reg tensor_lane1_pair_rvalid;
reg tensor_lane1_ready;
wire [1:0] tensor_lane1_role;
wire tensor_lane1_valid;
wire [63:0] tensor_lane2_data;
wire tensor_lane2_hi;
reg tensor_lane2_ready;
wire [1:0] tensor_lane2_role;
wire tensor_lane2_valid;
reg [127:0] tensor_pair_rdata;
reg tensor_pair_rvalid;
reg tensor_pair_rsp_high;
reg tensor_ready;
wire [ADDR_WIDTH-1:0] tensor_wld_addr;
reg [127:0] tensor_wld_rdata;
reg tensor_wld_ready;
wire tensor_wld_req;
reg tensor_wld_rvalid;

reg [127:0] expected [0:SETN-1];
integer errors;
integer cycle;
integer case_id;
reg [127:0] case_name;
integer writes;
integer last_write_cycle;
integer first_compute_cycle;
integer last_compute_cycle;
integer compute_count;
integer output_count;
integer last_output_cycle;
integer lane0_accepts;
integer lane1_accepts;
integer lane2_accepts;
integer idx;

reg lane0_rsp_pending;
reg [ADDR_WIDTH-1:0] lane0_rsp_addr;
reg lane1_rsp_pending;
reg [ADDR_WIDTH-1:0] lane1_rsp_addr;

always #5 clk = ~clk;

edge_accel_pipe pipe (
  .forever_cpuclk(clk),
  .cpurst_b(cpurst_b),
  .mem_region_base(40'h0040_0000_00),
  .mem_region_mask(40'hffff_fe00_00),
  .mem_region_enable(1'b1),
  .cmd_valid(pipe_cmd_valid),
  .cmd_opcode8(8'b0),
  .cmd_imm8(8'b0),
  .cmd_inst64(pipe_cmd_inst64),
  .cmd_seq_id(pipe_cmd_seq_id),
  .cmd_epoch(pipe_cmd_epoch),
  .cmd_capture_valid(pipe_cmd_capture_valid),
  .cmd_capture_value(pipe_cmd_capture_value),
  .dma_start_ready(1'b1),
  .dma_start_circular_ready(1'b1),
  .dma_sync_done(1'b1),
  .tensor_cmd_ready(tensor_cmd_ready),
  .tensor_start_ready(tensor_start_ready),
  .tensor_wld_cmd_ready(tensor_wld_cmd_ready),
  .tensor_wld_circular_ready(1'b1),
  .tensor_sync_stall(tensor_sync_stall),
  .actu_cmd_ready(1'b1),
  .actu_start_ready(1'b1),
  .actu_sync_stall(1'b0),
  .cmd_ready(pipe_cmd_ready),
  .decode_illegal(pipe_decode_illegal),
  .capture_consume_valid(pipe_capture_consume_valid),
  .tensor_done_valid(pipe_done_valid),
  .tensor_done_seq_id(pipe_done_seq_id),
  .tensor_done_epoch(pipe_done_epoch),
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
  .cmd_wld_circular_req(),
  .cmd_wld_trans_req(cmd_wld_trans_req),
  .actu_cmd_setcsr_dtype(),
  .actu_cmd_setcsr_mode(),
  .actu_cmd_setcsr_req(),
  .actu_cmd_setin_ptr(),
  .actu_cmd_setin_req(),
  .actu_cmd_setn_req(),
  .actu_cmd_setn_value(),
  .actu_cmd_setout_ptr(),
  .actu_cmd_setout_req(),
  .actu_cmd_setscalar_req(),
  .actu_cmd_setscalar_value(),
  .actu_cmd_start_req(),
  .actu_cmd_sync_req()
);

edge_tensor_unit dut (
  .clk(clk),
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
  .cmd_wld_trans_req(cmd_wld_trans_req),
  .cpurst_b(cpurst_b),
  .cur_tensor_in_req_mask(cur_tensor_in_req_mask),
  .cur_tensor_out_req_mask(cur_tensor_out_req_mask),
  .cur_tensor_prefetch_req_mask(cur_tensor_prefetch_req_mask),
  .dbg_dtype(dbg_dtype),
  .dbg_i_comp_delay(dbg_i_comp_delay),
  .dbg_i_lease_channel(dbg_i_lease_channel),
  .dbg_i_lease_cycles(dbg_i_lease_cycles),
  .dbg_i_lease_delay(dbg_i_lease_delay),
  .dbg_iopsum_plan_valid(dbg_iopsum_plan_valid),
  .dbg_o_comp_delay(dbg_o_comp_delay),
  .dbg_o_lease_channel(dbg_o_lease_channel),
  .dbg_o_lease_cycles(dbg_o_lease_cycles),
  .dbg_o_lease_delay(dbg_o_lease_delay),
  .dbg_phase(dbg_phase),
  .dbg_psum_comp_delay(dbg_psum_comp_delay),
  .dbg_psum_lease_channel(dbg_psum_lease_channel),
  .dbg_psum_lease_cycles(dbg_psum_lease_cycles),
  .dbg_psum_lease_delay(dbg_psum_lease_delay),
  .dbg_step(dbg_step),
  .dbg_start_phase(dbg_start_phase),
  .dbg_wtype(dbg_wtype),
  .dma_delay_req(dma_delay_req),
  .lsu_resv_plus1({BANK_NUM{1'b0}}),
  .tensor_busy(tensor_busy),
  .tensor_addr(tensor_addr),
  .tensor_cmd_ready(tensor_cmd_ready),
  .tensor_start_ready(tensor_start_ready),
  .tensor_wld_cmd_ready(tensor_wld_cmd_ready),
  .tensor_io_lease_channel_mask(tensor_io_lease_channel_mask),
  .tensor_io_lease_cycles(tensor_io_lease_cycles),
  .tensor_io_lease_delay(tensor_io_lease_delay),
  .tensor_io_lease1_channel_mask(tensor_io_lease1_channel_mask),
  .tensor_io_lease1_cycles(tensor_io_lease1_cycles),
  .tensor_io_lease1_delay(tensor_io_lease1_delay),
  .tensor_io_lease1_valid(tensor_io_lease1_valid),
  .tensor_io_lease2_channel_mask(tensor_io_lease2_channel_mask),
  .tensor_io_lease2_cycles(tensor_io_lease2_cycles),
  .tensor_io_lease2_delay(tensor_io_lease2_delay),
  .tensor_io_lease2_valid(tensor_io_lease2_valid),
  .tensor_io_lease_valid(tensor_io_lease_valid),
  .tensor_lane1_addr(tensor_lane1_addr),
  .tensor_lane1_data(tensor_lane1_data),
  .tensor_lane1_hi(tensor_lane1_hi),
  .tensor_lane1_pair_rdata(tensor_lane1_pair_rdata),
  .tensor_lane1_pair_rvalid(tensor_lane1_pair_rvalid),
  .tensor_lane1_ready(tensor_lane1_ready),
  .tensor_lane1_req(tensor_lane1_req),
  .tensor_lane1_role(tensor_lane1_role),
  .tensor_lane1_valid(tensor_lane1_valid),
  .tensor_lane1_wdata(tensor_lane1_wdata),
  .tensor_lane1_we(tensor_lane1_we),
  .tensor_lane1_wstrb(tensor_lane1_wstrb),
  .tensor_lane2_addr(tensor_lane2_addr),
  .tensor_lane2_data(tensor_lane2_data),
  .tensor_lane2_hi(tensor_lane2_hi),
  .tensor_lane2_ready(tensor_lane2_ready),
  .tensor_lane2_req(tensor_lane2_req),
  .tensor_lane2_role(tensor_lane2_role),
  .tensor_lane2_valid(tensor_lane2_valid),
  .tensor_lane2_pair_wdata(tensor_lane2_pair_wdata),
  .tensor_lane2_pair_wstrb(tensor_lane2_pair_wstrb),
  .tensor_lane2_wdata(tensor_lane2_wdata),
  .tensor_lane2_we(tensor_lane2_we),
  .tensor_lane2_wstrb(tensor_lane2_wstrb),
  .tensor_pair_rdata(tensor_pair_rdata),
  .tensor_pair_rvalid(tensor_pair_rvalid),
  .tensor_pair_rsp_high(tensor_pair_rsp_high),
  .tensor_rdata(tensor_rdata),
  .tensor_ready(tensor_ready),
  .tensor_req(tensor_req),
  .tensor_resv_plus2_mask(tensor_resv_plus2_mask),
  .tensor_resv_plus2_req(tensor_resv_plus2_req),
  .tensor_rvalid(tensor_rvalid),
  .tensor_sync_stall(tensor_sync_stall),
  .tensor_wdata(tensor_wdata),
  .tensor_we(tensor_we),
  .tensor_wstrb(tensor_wstrb),
  .tensor_wld_addr(tensor_wld_addr),
  .tensor_wld_lease_channel_mask(tensor_wld_lease_channel_mask),
  .tensor_wld_lease_cycles(tensor_wld_lease_cycles),
  .tensor_wld_lease_delay(tensor_wld_lease_delay),
  .tensor_wld_lease_valid(tensor_wld_lease_valid),
  .tensor_wld_rdata(tensor_wld_rdata),
  .tensor_wld_ready(tensor_wld_ready),
  .tensor_wld_req(tensor_wld_req),
  .tensor_wld_rvalid(tensor_wld_rvalid)
);

function [15:0] bf16_from_u8;
  input integer value;
  integer msb;
  integer bit_i;
  integer shifted;
begin
  if (value == 0) begin
    bf16_from_u8 = 16'h0000;
  end else begin
    msb = 0;
    for (bit_i = 0; bit_i < 31; bit_i = bit_i + 1)
      if (value[bit_i])
        msb = bit_i;
    shifted = value << (7 - msb);
    bf16_from_u8 = {1'b0, (8'd127 + msb[7:0]), shifted[6:0]};
  end
end
endfunction

function [127:0] vec8_bf16;
  input integer base;
  integer lane;
begin
  vec8_bf16 = 128'b0;
  for (lane = 0; lane < 8; lane = lane + 1)
    vec8_bf16[lane*16 +: 16] = bf16_from_u8(base + lane);
end
endfunction

function [127:0] expected_vec;
  input integer vec_idx;
  integer lane;
begin
  expected_vec = 128'b0;
  for (lane = 0; lane < 8; lane = lane + 1)
    expected_vec[lane*16 +: 16] =
      bf16_from_u8(51 + (vec_idx * 2) + (lane * 2));
end
endfunction

function [127:0] input_pair_for_addr;
  input [ADDR_WIDTH-1:0] addr;
  integer vec_idx;
begin
  vec_idx = (addr - IN_BASE) >> 1;
  input_pair_for_addr = vec8_bf16(1 + vec_idx);
end
endfunction

function [127:0] psum_pair_for_addr;
  input [ADDR_WIDTH-1:0] addr;
  integer vec_idx;
begin
  vec_idx = (addr - PSUM_BASE) >> 1;
  psum_pair_for_addr = vec8_bf16(50 + vec_idx);
end
endfunction

function [63:0] identity_weight_row;
  input integer row;
  integer col;
begin
  identity_weight_row = 64'b0;
  for (col = 0; col < 8; col = col + 1)
    identity_weight_row[col*8 +: 8] = (row == col) ? 8'd1 : 8'd0;
end
endfunction

function [127:0] identity_weight_pair;
  input integer row;
begin
  identity_weight_pair = {identity_weight_row(row + 1),
                          identity_weight_row(row)};
end
endfunction

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

function lane0_ready_for_case;
  input integer cid;
  input integer cyc;
begin
  case (cid)
    1: lane0_ready_for_case = (cyc % 3) != 1;
    default: lane0_ready_for_case = 1'b1;
  endcase
end
endfunction

function lane1_ready_for_case;
  input integer cid;
  input integer cyc;
begin
  case (cid)
    2: lane1_ready_for_case = (cyc % 5) != 2;
    default: lane1_ready_for_case = 1'b1;
  endcase
end
endfunction

function lane2_ready_for_case;
  input integer cid;
  input integer cyc;
begin
  case (cid)
    3: lane2_ready_for_case = (cyc % 5) != 3;
    default: lane2_ready_for_case = 1'b1;
  endcase
end
endfunction

task reset_dut;
begin
  cpurst_b = 1'b0;
  pipe_cmd_valid = 1'b0;
  pipe_cmd_inst64 = 64'b0;
  pipe_cmd_seq_id = 8'b0;
  pipe_cmd_epoch = 4'h1;
  pipe_cmd_capture_valid = 1'b0;
  pipe_cmd_capture_value = 64'b0;
  pipe_cmd_base_capture_valid = 1'b0;
  pipe_cmd_base_capture_value = 64'b0;
  tensor_ready = 1'b0;
  tensor_lane1_ready = 1'b0;
  tensor_lane2_ready = 1'b0;
  tensor_rdata = 64'b0;
  tensor_rvalid = 1'b0;
  tensor_pair_rdata = 128'b0;
  tensor_pair_rvalid = 1'b0;
  tensor_pair_rsp_high = 1'b0;
  tensor_wld_rdata = 128'b0;
  tensor_wld_ready = 1'b0;
  tensor_wld_rvalid = 1'b0;
  tensor_lane1_pair_rdata = 128'b0;
  tensor_lane1_pair_rvalid = 1'b0;
  lane0_rsp_pending = 1'b0;
  lane0_rsp_addr = {ADDR_WIDTH{1'b0}};
  lane1_rsp_pending = 1'b0;
  lane1_rsp_addr = {ADDR_WIDTH{1'b0}};
  cycle = 0;
  writes = 0;
  last_write_cycle = -1;
  first_compute_cycle = -1;
  last_compute_cycle = -1;
  compute_count = 0;
  output_count = 0;
  last_output_cycle = -1;
  lane0_accepts = 0;
  lane1_accepts = 0;
  lane2_accepts = 0;
  repeat (5) @(posedge clk);
  cpurst_b = 1'b1;
  repeat (2) @(posedge clk);
end
endtask

task issue_tensor_cmd(
  input [6:0] subop,
  input [63:0] payload,
  input capture_valid
);
integer wait_count;
integer wait_limit;
begin
  @(negedge clk);
  pipe_cmd_valid = 1'b1;
  pipe_cmd_inst64 = (subop == SUB_SETN) ? tensor_reg_inst(subop, 5'd1)
                                        : tensor_inst(subop);
  pipe_cmd_capture_valid = capture_valid;
  pipe_cmd_capture_value = payload;
  pipe_cmd_base_capture_valid = 1'b0;
  pipe_cmd_base_capture_value = 64'b0;
  pipe_cmd_seq_id = pipe_cmd_seq_id + 8'd1;
  wait_count = 0;
  if (subop == SUB_START) begin
    wait_limit = 10000;
    while (!(tensor_busy || dut.queued_start_valid || compute_count != 0 ||
             writes != 0 || output_count != 0) &&
           wait_count < wait_limit) begin
      wait_count = wait_count + 1;
      @(negedge clk);
    end
    if (!(tensor_busy || dut.queued_start_valid || compute_count != 0 ||
          writes != 0 || output_count != 0)) begin
      $display("FAIL pipe start timeout cmd_ready=%0d start_ready=%0d busy=%0d queued=%0d wld_ready=%0d loaded=%0d load_idx=%0d read_idx=%0d",
               pipe_cmd_ready, tensor_start_ready, tensor_busy,
               dut.queued_start_valid, dut.wld_ready, dut.weight_loaded_valid,
               dut.wld_load_idx, dut.wld_read_idx);
      errors = errors + 1;
    end
  end else begin
    wait_limit = (subop == SUB_WLD) ? 2000 : 200;
    while (!pipe_cmd_ready && wait_count < wait_limit) begin
      wait_count = wait_count + 1;
      @(negedge clk);
    end
    if (!pipe_cmd_ready) begin
      $display("FAIL pipe command timeout subop=%h ready=%0d cmd_ready=%0d start_ready=%0d wld_cmd_ready=%0d busy=%0d wld_active=%0d wld_wait=%0d wld_ready=%0d loaded=%0d load_idx=%0d read_idx=%0d",
               subop, pipe_cmd_ready, tensor_cmd_ready, tensor_start_ready,
               tensor_wld_cmd_ready, tensor_busy, dut.wld_fetch_active,
               dut.wld_fetch_wait, dut.wld_ready, dut.weight_loaded_valid,
               dut.wld_load_idx, dut.wld_read_idx);
      errors = errors + 1;
    end
  end
  @(posedge clk);
  #1;
  if (pipe_decode_illegal) begin
    $display("FAIL pipe decoded legal tensor command as illegal subop=%h", subop);
    errors = errors + 1;
  end
  @(negedge clk);
  pipe_cmd_valid = 1'b0;
  pipe_cmd_capture_valid = 1'b0;
  pipe_cmd_capture_value = 64'b0;
  pipe_cmd_base_capture_valid = 1'b0;
  pipe_cmd_base_capture_value = 64'b0;
end
endtask

task issue_setcsr;
begin
  @(negedge clk);
  pipe_cmd_valid = 1'b1;
  pipe_cmd_inst64 = tensor_setcsr_inst(4'd1, 4'd2);
  pipe_cmd_capture_valid = 1'b1;
  pipe_cmd_capture_value = 64'd1;
  pipe_cmd_base_capture_valid = 1'b1;
  pipe_cmd_base_capture_value = 64'd2;
  pipe_cmd_seq_id = pipe_cmd_seq_id + 8'd1;
  while (!pipe_cmd_ready)
    @(negedge clk);
  @(posedge clk);
  #1;
  if (!pipe_done_valid || !cmd_setcsr_req ||
      cmd_setcsr_dtype != 4'd1 || cmd_setcsr_wtype != 4'd2) begin
    $display("FAIL pipe setcsr command");
    errors = errors + 1;
  end
  @(negedge clk);
  pipe_cmd_valid = 1'b0;
  pipe_cmd_capture_valid = 1'b0;
  pipe_cmd_base_capture_valid = 1'b0;
end
endtask

task setup_commands;
begin
  issue_setcsr();
  issue_tensor_cmd(SUB_WLD, {48'b0, WGT_BASE}, 1'b1);
  issue_tensor_cmd(SUB_SETIN, {48'b0, IN_BASE}, 1'b1);
  issue_tensor_cmd(SUB_SETOUT, {48'b0, OUT_BASE}, 1'b1);
  issue_tensor_cmd(SUB_SETPSUM, {48'b0, PSUM_BASE}, 1'b1);
  issue_tensor_cmd(SUB_SETN, {48'b0, SETN[15:0]}, 1'b1);
end
endtask

task run_case;
integer timed_out;
begin
  timed_out = 0;
  reset_dut();
  setup_commands();
  issue_tensor_cmd(SUB_START, 64'b0, 1'b0);
  begin : wait_for_completion
    while (tensor_busy || writes < SETN) begin
      @(posedge clk);
      if (cycle > 1000) begin
        $display("FAIL %0s timeout writes=%0d compute=%0d output=%0d",
                 case_name, writes, compute_count, output_count);
        errors = errors + 1;
        timed_out = 1;
        disable wait_for_completion;
      end
    end
  end
  if (!timed_out) begin
    if (writes !== SETN) begin
      $display("FAIL %0s write count got=%0d expected=%0d", case_name, writes, SETN);
      errors = errors + 1;
    end
    if (compute_count !== SETN) begin
      $display("FAIL %0s compute count got=%0d expected=%0d",
               case_name, compute_count, SETN);
      errors = errors + 1;
    end
    if (output_count !== SETN) begin
      $display("FAIL %0s output count got=%0d expected=%0d",
               case_name, output_count, SETN);
      errors = errors + 1;
    end
    if (case_id == 0 && last_compute_cycle - first_compute_cycle + 1 !== SETN) begin
      $display("FAIL %0s compute cadence first=%0d last=%0d count=%0d",
               case_name, first_compute_cycle, last_compute_cycle, compute_count);
      errors = errors + 1;
    end
    $display("CASE %0s writes=%0d compute=%0d output=%0d lane_accepts=%0d/%0d/%0d",
             case_name, writes, compute_count, output_count,
             lane0_accepts, lane1_accepts, lane2_accepts);
  end
end
endtask

always @(posedge clk or negedge cpurst_b) begin
  if (!cpurst_b) begin
    tensor_rvalid <= 1'b0;
    tensor_pair_rvalid <= 1'b0;
    tensor_wld_rvalid <= 1'b0;
    tensor_lane1_pair_rvalid <= 1'b0;
    lane0_rsp_pending <= 1'b0;
    lane1_rsp_pending <= 1'b0;
  end else begin
    cycle <= cycle + 1;
    tensor_ready <= lane0_ready_for_case(case_id, cycle);
    tensor_wld_ready <= 1'b1;
    tensor_lane1_ready <= lane1_ready_for_case(case_id, cycle);
    tensor_lane2_ready <= lane2_ready_for_case(case_id, cycle);

    tensor_rvalid <= lane0_rsp_pending;
    tensor_pair_rvalid <= lane0_rsp_pending;
    tensor_wld_rvalid <= tensor_wld_req && tensor_wld_ready;
    tensor_lane1_pair_rvalid <= lane1_rsp_pending;
    tensor_pair_rsp_high <= 1'b0;
    if (lane0_rsp_pending) begin
      if (lane0_rsp_addr >= WGT_BASE) begin
        tensor_rdata <= identity_weight_row(lane0_rsp_addr - WGT_BASE);
        tensor_pair_rdata <= identity_weight_pair(lane0_rsp_addr - WGT_BASE);
      end else begin
        tensor_pair_rdata <= input_pair_for_addr(lane0_rsp_addr);
      end
    end
    if (lane1_rsp_pending)
      tensor_lane1_pair_rdata <= psum_pair_for_addr(lane1_rsp_addr);
    if (tensor_wld_req && tensor_wld_ready)
      tensor_wld_rdata <= identity_weight_pair(tensor_wld_addr - WGT_BASE);

    lane0_rsp_pending <= 1'b0;
    if (tensor_req && tensor_ready && !tensor_we) begin
      lane0_rsp_pending <= 1'b1;
      lane0_rsp_addr <= tensor_addr;
      lane0_accepts <= lane0_accepts + 1;
    end

    lane1_rsp_pending <= 1'b0;
    if (tensor_lane1_req && tensor_lane1_ready && !tensor_lane1_we) begin
      lane1_rsp_pending <= 1'b1;
      lane1_rsp_addr <= tensor_lane1_addr;
      lane1_accepts <= lane1_accepts + 1;
    end

    if (tensor_lane2_req && tensor_lane2_ready && tensor_lane2_we) begin
      lane2_accepts <= lane2_accepts + 1;
      if (tensor_lane2_pair_wstrb == 16'hffff) begin
        if (last_write_cycle >= 0 && case_id == 0
            && cycle != last_write_cycle + 1) begin
          $display("FAIL perfect write bubble idx=%0d last=%0d cycle=%0d",
                   writes, last_write_cycle, cycle);
          errors = errors + 1;
        end
        last_write_cycle <= cycle;
        if (writes >= SETN) begin
          $display("FAIL extra write idx=%0d data=%h", writes,
                   tensor_lane2_pair_wdata);
          errors = errors + 1;
        end else if (tensor_lane2_pair_wdata !== expected[writes]) begin
          $display("FAIL write mismatch case=%0d idx=%0d got=%h expected=%h",
                   case_id, writes, tensor_lane2_pair_wdata, expected[writes]);
          errors = errors + 1;
        end
        writes <= writes + 1;
      end
    end

    if (dut.compute_valid_q) begin
      if (first_compute_cycle < 0)
        first_compute_cycle <= cycle;
      if (case_id == 0 && last_compute_cycle >= 0
          && cycle != last_compute_cycle + 1) begin
        $display("FAIL perfect compute bubble count=%0d last=%0d cycle=%0d",
                 compute_count, last_compute_cycle, cycle);
        errors = errors + 1;
      end
      last_compute_cycle <= cycle;
      compute_count <= compute_count + 1;
    end

    if (dut.tensor_core_output_valid) begin
      if (case_id == 0 && last_output_cycle >= 0
          && cycle != last_output_cycle + 1) begin
        $display("FAIL perfect output bubble count=%0d last=%0d cycle=%0d",
                 output_count, last_output_cycle, cycle);
        errors = errors + 1;
      end
      last_output_cycle <= cycle;
      output_count <= output_count + 1;
    end
  end
end

initial begin
  clk = 1'b0;
  errors = 0;
  case_id = 0;
  for (idx = 0; idx < SETN; idx = idx + 1)
    expected[idx] = expected_vec(idx);

  case_name = "perfect";
  run_case();
  case_id = 1;
  case_name = "lane0_bubble";
  run_case();
  case_id = 2;
  case_name = "lane1_bubble";
  run_case();
  case_id = 3;
  case_name = "lane2_bubble";
  run_case();

  if (errors != 0) begin
    $display("FAIL tensor stream shell errors=%0d", errors);
    $fatal(1, "tensor stream shell errors=%0d", errors);
  end

  $display("EDGE_ACCEL_PIPE_STREAM_SHELL TEST PASS");
  $finish;
end

endmodule
