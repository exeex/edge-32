`timescale 1ns/1ps
module edge_32_address_header_tb;
  reg clk=0,reset_n=0; always #5 clk=~clk;
  wire imem_req_valid; wire [31:0] imem_req_addr;
  reg imem_resp_valid=0; reg [31:0] imem_resp_data=0;
  wire [31:0] icache_address_header,dcache_address_header;
  wire halted,illegal;

  edge_32_core #(.ENABLE_FPU(0)) dut(
    .clk(clk),.reset_n(reset_n),.boot_pc(32'd0),
    .core_start(1'b0),.core_force_stop(1'b0),
    .icache_address_header(icache_address_header),
    .dcache_address_header(dcache_address_header),
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
    imem_resp_valid<=imem_req_valid;
    case(imem_req_addr)
      0: imem_resp_data<=32'h7db0_22f3; // csrr x5, 0x7db
      4: imem_resp_data<=32'h7dc0_2373; // csrr x6, 0x7dc
      8: imem_resp_data<=32'h0120_0393; // addi x7, x0, 0x12
      12: imem_resp_data<=32'h7db3_9073; // csrw 0x7db, x7
      16: imem_resp_data<=32'h0340_0413; // addi x8, x0, 0x34
      20: imem_resp_data<=32'h7dc4_1073; // csrw 0x7dc, x8
      24: imem_resp_data<=32'h7db0_24f3; // csrr x9, 0x7db
      28: imem_resp_data<=32'h7dc0_2573; // csrr x10, 0x7dc
      default: imem_resp_data<=32'h0010_0073;
    endcase
  end

  initial begin
    repeat(3) begin
      @(posedge clk); #1;
      if(icache_address_header!==0||dcache_address_header!==0)
        $fatal(1,"I/D address headers not zero in reset");
    end
    reset_n<=1;
    repeat(80) begin @(posedge clk); if(halted) begin
      if(illegal||dut.gpr[5]!=0||dut.gpr[6]!=0||dut.gpr[9]!=32'h12||
         dut.gpr[10]!=32'h34||icache_address_header!=32'h12||
         dcache_address_header!=32'h34)
        $fatal(1,"I/D address header CSR mismatch I=%h/%h D=%h/%h",
               dut.gpr[9],icache_address_header,dut.gpr[10],dcache_address_header);
      $display("EDGE32 ADDRESS HEADER TEST PASS I=%h D=%h",
               icache_address_header,dcache_address_header);
      $finish;
    end end
    $fatal(1,"address header CSR timeout");
  end
endmodule
