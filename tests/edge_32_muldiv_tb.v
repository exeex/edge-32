`timescale 1ns/1ps

module edge_32_muldiv_tb;
  reg clk=0; always #5 clk=~clk;
  reg reset_n=0;
  reg op_valid=0;
  reg [31:0] src0=0, src1=0;
  reg [2:0] funct3=0;
  wire op_ready, result_valid, busy;
  wire [31:0] result_value;
  wire [6:0] op_latency;
  integer cycles;

  edge_32_muldiv dut(.*);

  task run_op;
    input [2:0] selected_funct3;
    input [31:0] lhs;
    input [31:0] rhs;
    input [31:0] expected;
    input integer max_cycles;
    begin
      while(!op_ready) @(posedge clk);
      @(negedge clk);
      funct3=selected_funct3; src0=lhs; src1=rhs; op_valid=1;
      @(posedge clk); #1; op_valid=0; cycles=0;
      while(!result_valid && cycles<max_cycles) begin
        if(selected_funct3[2] && cycles<31 && op_ready)
          $fatal(1,"divider released ready before completion");
        @(posedge clk); #1; cycles=cycles+1;
      end
      if(!result_valid || result_value!==expected)
        $fatal(1,"funct3=%0d lhs=%h rhs=%h expected=%h got=%h cycles=%0d",
               selected_funct3,lhs,rhs,expected,result_value,cycles);
      @(posedge clk); #1;
      if(result_valid) $fatal(1,"result_valid was not a pulse");
    end
  endtask

  initial begin
    repeat(3) @(posedge clk); reset_n=1;
    run_op(3'b000,32'hffff_fffe,32'd2,32'hffff_fffc,2);
    run_op(3'b001,32'hffff_fffe,32'd3,32'hffff_ffff,2);
    run_op(3'b010,32'hffff_fffe,32'h8000_0000,32'hffff_ffff,2);
    run_op(3'b011,32'hffff_ffff,32'd2,32'd1,2);
    run_op(3'b100,-32'd7,32'd3,-32'd2,40);
    run_op(3'b101,32'hffff_fff9,32'd3,32'h5555_5553,40);
    run_op(3'b110,-32'd7,32'd3,32'hffff_ffff,40);
    run_op(3'b111,32'hffff_fff9,32'd3,32'd0,40);
    run_op(3'b100,32'd9,32'd0,32'hffff_ffff,2);
    run_op(3'b110,32'hffff_fff7,32'd0,32'hffff_fff7,2);
    run_op(3'b100,32'h8000_0000,32'hffff_ffff,32'h8000_0000,2);
    run_op(3'b110,32'h8000_0000,32'hffff_ffff,32'd0,2);

    @(negedge clk); funct3=3'b101; src0=32'hffff_ffff; src1=7; op_valid=1;
    @(posedge clk); #1; op_valid=0;
    repeat(4) @(posedge clk);
    reset_n=0; @(posedge clk); #1;
    if(busy||result_valid) $fatal(1,"reset did not cancel divide");
    reset_n=1;
    $display("TEST PASS: edge_32_muldiv RV32M and ownership");
    $finish;
  end
endmodule
