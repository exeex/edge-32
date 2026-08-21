`timescale 1ns/1ps
module edge_32_lsu_tb;
  reg clk = 0; always #5 clk = ~clk;
  reg reset_n = 0, op_valid = 0, op_store = 0, op_fp = 0;
  reg [2:0] op_funct3 = 0;
  reg [31:0] op_base = 0, op_offset = 0, op_store_data = 0;
  wire op_ready, mem_req_valid, mem_req_write;
  reg mem_req_ready = 0;
  wire [31:0] mem_req_addr;
  wire [63:0] mem_req_wdata; wire [7:0] mem_req_wstrb;
  wire [1:0] mem_req_size; wire mem_req_signed;
  reg mem_resp_valid = 0, mem_resp_error = 0;
  reg [63:0] mem_resp_rdata = 0;
  wire op_done, op_error; wire [31:0] op_load_value; wire busy;
  edge_32_lsu dut(.*);

  task issue_and_ack;
    input store;
    input [2:0] funct3;
    input [31:0] base;
    input [31:0] offset;
    input [31:0] expected_addr;
    input [7:0] expected_strobe;
    begin
      @(negedge clk);
      op_valid=1; op_store=store; op_fp=0; op_funct3=funct3;
      op_base=base; op_offset=offset; op_store_data=32'haabb_ccdd;
      @(posedge clk); #1; op_valid=0;
      if(!mem_req_valid || mem_req_addr!=expected_addr ||
         mem_req_size!=funct3[1:0])
        $fatal(1,"request mismatch addr=%h size=%h",mem_req_addr,mem_req_size);
      if(store && mem_req_wstrb!=expected_strobe)
        $fatal(1,"store strobe mismatch expected=%h got=%h",
               expected_strobe,mem_req_wstrb);
      mem_req_ready=1; @(posedge clk); #1; mem_req_ready=0;
      if(op_done || !busy) $fatal(1,"request completed before response");
      mem_resp_rdata=64'h8877_6655_4433_2211; mem_resp_error=0;
      mem_resp_valid=1; @(posedge clk); #1; mem_resp_valid=0;
      if(!op_done || op_error) $fatal(1,"legal request failed");
    end
  endtask

  task check_local_fault;
    input [2:0] funct3;
    input [31:0] offset;
    begin
      @(negedge clk);
      op_valid=1; op_store=0; op_fp=0; op_funct3=funct3;
      op_base=32'h4000; op_offset=offset;
      @(posedge clk); #1; op_valid=0;
      if(!op_done || !op_error || mem_req_valid || busy)
        $fatal(1,"invalid RV32 access escaped funct3=%h offset=%h",
               funct3,offset);
    end
  endtask

  initial begin
    repeat(2) @(posedge clk); reset_n=1;

    // Backpressure holds the 32-bit effective address and payload.
    @(negedge clk); op_valid=1; op_funct3=3'b000;
    op_base=32'h1000; op_offset=3; op_store=0;
    @(posedge clk); #1; op_valid=0;
    repeat(2) begin
      @(posedge clk); #1;
      if(!mem_req_valid || mem_req_addr!=32'h1003 || op_ready)
        $fatal(1,"load request was not held");
    end
    mem_req_ready=1; @(posedge clk); #1; mem_req_ready=0;
    repeat(2) begin
      @(posedge clk); #1;
      if(!busy || op_ready || op_done) $fatal(1,"load did not wait for response");
    end
    mem_resp_rdata=64'h0000_0000_8000_0000; mem_resp_valid=1;
    @(posedge clk); #1; mem_resp_valid=0;
    if(!op_done || op_load_value!=32'hffff_ff80)
      $fatal(1,"bad RV32 signed load result %h",op_load_value);

    issue_and_ack(1'b1,3'b010,32'h2000,32'd4,32'h2004,8'hf0);
    issue_and_ack(1'b0,3'b000,32'h3000,32'd7,32'h3007,8'h80);
    issue_and_ack(1'b1,3'b001,32'h3000,32'd6,32'h3006,8'hc0);
    issue_and_ack(1'b0,3'b010,32'h3000,32'd4,32'h3004,8'hf0);

    // Effective-address arithmetic wraps at RV32 XLEN.
    issue_and_ack(1'b0,3'b010,32'hffff_fffc,32'd4,32'h0000_0000,8'h0f);

    check_local_fault(3'b001,32'd1);
    check_local_fault(3'b010,32'd2);
    check_local_fault(3'b011,32'd0); // LD is not an RV32 LSU operation.

    $display("TEST PASS: edge_32_lsu RV32 address/format/ownership");
    $finish;
  end
endmodule
