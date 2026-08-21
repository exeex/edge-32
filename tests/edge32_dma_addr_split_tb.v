`timescale 1ns/1ps
module edge32_dma_addr_split_tb;
  reg clk=0; always #5 clk=~clk;
  reg reset_n=0, cmd_valid=0, capture_valid=0;
  reg [7:0] opcode8=0, imm8=0;
  reg [63:0] capture_value=0;
  wire cmd_ready, dma_start_req;
  wire [63:0] dma_start_src, dma_start_dst;

  edge_accel_pipe #(.COMPACT_CMD_INPUT(1)) dut (
    .forever_cpuclk(clk),.cpurst_b(reset_n),
    .mem_region_base(40'b0),.mem_region_mask(40'b0),.mem_region_enable(1'b0),
    .cmd_valid(cmd_valid),.cmd_opcode8(opcode8),.cmd_imm8(imm8),
    .cmd_inst64(64'b0),.cmd_seq_id(8'b0),.cmd_epoch(4'b0),
    .cmd_capture_valid(capture_valid),.cmd_capture_value(capture_value),
    .dma_start_ready(1'b1),.dma_start_circular_ready(1'b1),.dma_sync_done(1'b1),
    .tensor_cmd_ready(1'b1),.tensor_start_ready(1'b1),
    .tensor_wld_cmd_ready(1'b1),.tensor_sld_cmd_ready(1'b1),
    .tensor_wld_circular_ready(1'b1),.tensor_wsld_circular_ready(1'b1),
    .tensor_sld_circular_ready(1'b1),.tensor_sync_stall(1'b0),
    .actu_cmd_ready(1'b1),.actu_start_ready(1'b1),.actu_sync_stall(1'b0),
    .cmpu_cmd_ready(1'b1),.cmpu_start_ready(1'b1),.cmpu_sync_stall(1'b0),
    .actu_last_sum_bits(32'b0),.cmpu_max_value(16'b0),.cmpu_argmax_idx(16'b0),
    .cmpu_min_value(16'b0),.cmpu_argmin_idx(16'b0),
    .reverse_snapshot_write_ready(1'b1),.cmd_ready(cmd_ready),
    .dma_start_req(dma_start_req),.dma_start_src(dma_start_src),
    .dma_start_dst(dma_start_dst)
  );

  task command;
    input [6:0] subop; input [7:0] immediate; input [31:0] value;
    begin
      opcode8={1'b1,subop}; imm8=immediate; capture_value={32'b0,value};
      capture_valid=1; cmd_valid=1;
      do @(posedge clk); while(!cmd_ready);
      cmd_valid=0; capture_valid=0; @(posedge clk);
    end
  endtask

  initial begin
    repeat(2) @(posedge clk); reset_n=1;
    command(7'h06,8'd0,32'h8000_2000);
    command(7'h06,8'd1,32'h1234_5678);
    command(7'h07,8'd0,32'h8000_3000);
    command(7'h07,8'd1,32'habcd_ef01);
    if(dma_start_src!=64'h1234_5678_8000_2000 ||
       dma_start_dst!=64'habcd_ef01_8000_3000)
      $fatal(1,"split DMA address assembly mismatch");
    command(7'h06,8'd0,32'h0000_4000);
    if(dma_start_src!=64'h0000_0000_0000_4000)
      $fatal(1,"low DMA source write did not clear stale high half");
    command(7'h01,8'd0,32'd64);
    if(dma_start_src!=64'h4000)
      $fatal(1,"DMA start without high address did not use high=0");
    $display("TEST PASS: edge32 DMA low/high address commands");
    $finish;
  end
endmodule
