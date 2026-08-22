`timescale 1ns/1ps

module edge_32_muldiv_core_tb;
  reg clk=0; always #5 clk=~clk;
  reg reset_n=0;
  reg imem_resp_valid=0;
  reg [31:0] imem_resp_data=0;
  wire imem_req_valid;
  wire [31:0] imem_req_addr;
  wire halted, illegal;
  integer timeout;

  edge_32_core dut(
    .clk(clk),.reset_n(reset_n),
    .imem_req_valid(imem_req_valid),.imem_req_ready(1'b1),
    .imem_req_addr(imem_req_addr),.imem_resp_valid(imem_resp_valid),
    .imem_resp_data(imem_resp_data),.imem_resp_error(1'b0),
    .dmem_req_valid(),.dmem_req_ready(1'b1),.dmem_req_write(),
    .dmem_req_addr(),.dmem_req_wdata(),.dmem_req_wstrb(),.dmem_req_size(),
    .dmem_req_signed(),.dmem_resp_valid(1'b0),.dmem_resp_error(1'b0),
    .dmem_resp_rdata(64'd0),.cache_op_valid(),.cache_op_ready(1'b1),
    .cache_op_is_va(),.cache_op_kind(),.cache_op_addr(),
    .cache_op_complete_valid(1'b0),.icache_invalidate_valid(),
    .icache_invalidate_ready(1'b1),.icache_invalidate_complete(1'b1),
    .accel_req_valid(),.accel_req_ready(1'b1),.accel_req_inst(),
    .accel_req_src0(),.accel_req_src1(),.accel_resp_valid(1'b0),
    .accel_resp_error(1'b0),.accel_resp_value(64'd0),
    .halted(halted),.illegal(illegal),.debug_x31(),.cycle_count(),
    .instret_count());

  always @(posedge clk) begin
    imem_resp_valid <= imem_req_valid;
    case(imem_req_addr)
      32'h00: imem_resp_data <= 32'hff90_0293; // addi x5,x0,-7
      32'h04: imem_resp_data <= 32'h0030_0313; // addi x6,x0,3
      32'h08: imem_resp_data <= 32'h0262_c3b3; // div x7,x5,x6
      32'h0c: imem_resp_data <= 32'h0262_9433; // mulh x8,x5,x6
      default: imem_resp_data <= 32'h0010_0073; // ebreak
    endcase
  end

  initial begin
    repeat(3) @(posedge clk); reset_n=1; timeout=0;
    while(!halted && timeout<150) begin @(posedge clk); timeout=timeout+1; end
    if(!halted||illegal) $fatal(1,"RV32M core did not halt normally");
    if(dut.gpr[7]!==32'hffff_fffe)
      $fatal(1,"DIV writeback mismatch: %h",dut.gpr[7]);
    if(dut.gpr[8]!==32'hffff_ffff)
      $fatal(1,"MULH writeback mismatch: %h",dut.gpr[8]);
    $display("TEST PASS: edge_32 core RV32M execute/stall/writeback");
    $finish;
  end
endmodule
