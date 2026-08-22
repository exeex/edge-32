`timescale 1ns/1ps
module edge_32_instruction_assembler_tb;
  reg clk=0; always #5 clk=~clk;
  reg reset_n=0, parcel_valid=0, parcel_error=0, op_ready=1, flush=0;
  reg [31:0] parcel_pc=0; reg [31:0] parcel_data=0;
  wire parcel_ready, op_valid, op_is_64b, op_error;
  wire [31:0] op_pc; wire [63:0] op_inst;
  edge_32_instruction_assembler dut(.*);

  task send;
    input [31:0] pc; input [31:0] data;
    begin
      parcel_pc<=pc; parcel_data<=data; parcel_valid<=1;
      do @(posedge clk); while(!parcel_ready);
      parcel_valid<=0;
    end
  endtask

  initial begin
    repeat(2) @(posedge clk); reset_n<=1;
    parcel_pc<=0; parcel_data<=32'h0010_0093; parcel_valid<=1; #1;
    if(!op_valid||op_is_64b||op_inst[31:0]!=32'h0010_0093)
      $fatal(1,"scalar parcel did not pass through");
    @(posedge clk); parcel_valid<=0;

    parcel_pc<=32'h4; parcel_data<=32'h4862_803f; parcel_valid<=1; #1;
    if(!op_valid||op_is_64b||op_pc!=32'h4||op_inst!=64'h4862_803f)
      $fatal(1,"ASIC32 command did not pass through");
    @(posedge clk); parcel_valid<=0;

    flush<=1; @(posedge clk); flush<=0;
    parcel_pc<=32'h80; parcel_data<=32'h0000_0013; parcel_valid<=1; #1;
    if(!op_valid||op_is_64b||op_pc!=32'h80)
      $fatal(1,"flush did not clear pending low parcel");
    $display("TEST PASS: fixed-width scalar/ASIC pass-through and flush");
    $finish;
  end
endmodule
