`timescale 1ns/1ps

module edge_32_branch_core_tb;
  reg clk=0, reset_n=0;
  always #5 clk=~clk;

  wire imem_req_valid; reg imem_req_ready=1;
  wire [39:0] imem_req_addr;
  reg imem_resp_valid=0;
  reg [31:0] imem_resp_data;
  wire dmem_req_valid, dmem_req_write; wire [63:0] dmem_req_addr;
  wire [63:0] dmem_req_wdata; wire [7:0] dmem_req_wstrb;
  wire [1:0] dmem_req_size; wire dmem_req_signed; reg dmem_req_ready=1;
  reg dmem_resp_valid=0; reg [63:0] dmem_resp_rdata=0;
  wire halted, illegal; wire [63:0] debug_x31, cycle_count, instret_count;

  edge_rv_lite_core dut(
    .clk(clk),.reset_n(reset_n),
    .imem_req_valid(imem_req_valid),.imem_req_ready(imem_req_ready),
    .imem_req_addr(imem_req_addr),.imem_resp_valid(imem_resp_valid),
    .imem_resp_data(imem_resp_data),
    .imem_resp_error(1'b0),.dmem_req_valid(dmem_req_valid),
    .dmem_req_ready(dmem_req_ready),.dmem_req_write(dmem_req_write),
    .dmem_req_addr(dmem_req_addr),.dmem_req_wdata(dmem_req_wdata),
    .dmem_req_wstrb(dmem_req_wstrb),.dmem_req_size(dmem_req_size),
    .dmem_req_signed(dmem_req_signed),.dmem_resp_valid(dmem_resp_valid),
    .dmem_resp_rdata(dmem_resp_rdata),.dmem_resp_error(1'b0),
    .accel_req_valid(),.accel_req_ready(1'b1),.accel_req_inst(),
    .accel_req_src0(),.accel_req_src1(),.accel_resp_valid(1'b0),
    .accel_resp_value(64'd0),.accel_resp_error(1'b0),
    .cache_op_valid(),.cache_op_ready(1'b1),.cache_op_is_va(),
    .cache_op_kind(),.cache_op_addr(),.cache_op_complete_valid(1'b0),
    .icache_invalidate_valid(),.icache_invalidate_ready(1'b1),
    .icache_invalidate_complete(1'b1),
    .halted(halted),.illegal(illegal),.debug_x31(debug_x31),
    .cycle_count(cycle_count),.instret_count(instret_count));

  always @(posedge clk) begin
    imem_resp_valid <= imem_req_valid && imem_req_ready;
    case (imem_req_addr[7:0])
      8'h00: imem_resp_data <= 32'hfff00093; // addi x1,x0,-1
      8'h04: imem_resp_data <= 32'h00100113; // addi x2,x0,1
      8'h08: imem_resp_data <= 32'h0020c463; // blt x1,x2,+8
      8'h0c: imem_resp_data <= 32'h06300f93; // flushed: addi x31,x0,99
      8'h10: imem_resp_data <= 32'h008001ef; // jal x3,+8
      8'h14: imem_resp_data <= 32'h05800f93; // flushed: addi x31,x0,88
      8'h18: imem_resp_data <= 32'h02000267; // jalr x4,x0,32
      8'h1c: imem_resp_data <= 32'h04d00f93; // flushed: addi x31,x0,77
      8'h20: imem_resp_data <= 32'h00700f93; // addi x31,x0,7
      default: imem_resp_data <= 32'h00100073; // ebreak
    endcase
  end

  integer timeout;
  initial begin
    repeat(3) @(posedge clk); reset_n=1; timeout=0;
    while(!halted && timeout<120) begin @(posedge clk); timeout=timeout+1; end
    if(!halted || illegal) $fatal(1,"branch program did not halt normally");
    if(dut.gpr[3]!==32'd20 || dut.gpr[4]!==32'd28)
      $fatal(1,"JAL/JALR link mismatch x3=%h x4=%h",dut.gpr[3],dut.gpr[4]);
    if(debug_x31!==64'd7)
      $fatal(1,"redirect did not flush wrong-path writes: %h",debug_x31);
    $display("TEST PASS: edge_32 core branch/jump redirect");
    $finish;
  end
endmodule
