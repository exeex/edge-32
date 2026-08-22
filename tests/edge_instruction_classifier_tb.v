`timescale 1ns/1ps
module edge_instruction_classifier_tb;
  reg [63:0] inst; reg inst_is_64b;
  wire [3:0] op_class; wire legal; wire [4:0] rd,rs1,rs2;
  wire [2:0] scalar_issue_class; wire writes_gpr,is_edge64,accel_is_tensor;
  wire [6:0] accel_subop; wire accel_needs_capture;
  wire [4:0] accel_capture_src_gpr; wire accel_needs_base_gpr;
  wire [4:0] accel_base_src_gpr; wire accel_is_sync,accel_is_getcsr;
  edge_instruction_classifier dut(.*);
  task tensor;
    input [6:0] subop; input [4:0] src; input capture,sync,getcsr,valid;
    begin
      inst=0; inst[6:0]=7'h3f; inst[39]=1; inst[38:32]=subop;
      inst[19:15]=src; inst_is_64b=1; #1;
      if(legal!=valid||!accel_is_tensor||accel_needs_capture!=capture||
         accel_is_sync!=sync||accel_is_getcsr!=getcsr)
        $fatal(1,"tensor property mismatch subop=%h",subop);
    end
  endtask
  initial begin
    inst=64'h00000000000000b3; inst_is_64b=0; #1;
    if(!legal||op_class!=0||scalar_issue_class!=3||!writes_gpr)
      $fatal(1,"scalar ALU classification mismatch");
    inst[11:7]=0; #1;
    if(!legal||scalar_issue_class!=3||writes_gpr)
      $fatal(1,"x0 ALU definition mismatch");
    inst=64'h00000000020000b3; #1;
    if(!legal||op_class!=4||scalar_issue_class!=4)
      $fatal(1,"scalar M classification mismatch");
    inst=0; inst[6:0]=7'h03; inst[14:12]=3; inst[11:7]=5; #1;
    if(!legal||op_class!=2||scalar_issue_class!=1||!writes_gpr)
      $fatal(1,"scalar load classification mismatch");
    inst=0; inst[6:0]=7'h23; inst[14:12]=3; #1;
    if(!legal||op_class!=3||scalar_issue_class!=2||writes_gpr)
      $fatal(1,"scalar store classification mismatch");
    inst=0; inst[6:0]=7'h73; inst[14:12]=1; inst[11:7]=6; #1;
    if(!legal||op_class!=6||scalar_issue_class!=0||!writes_gpr)
      $fatal(1,"scalar CSR definition mismatch");
    inst=0; inst[6:0]=7'h33; inst[31:25]=7'h7f; inst[11:7]=1; #1;
    if(legal||op_class!=15||scalar_issue_class!=0||writes_gpr)
      $fatal(1,"illegal scalar classification mismatch");
    tensor(7'h11,5'd7,1,0,0,1);
    if(accel_capture_src_gpr!=5'd7) $fatal(1,"tensor capture source mismatch");
    tensor(7'h25,0,0,0,0,1);
    tensor(7'h2d,0,0,0,0,1);
    tensor(7'h16,0,0,1,0,1);
    tensor(7'h2f,0,0,0,1,1);
    tensor(7'h09,0,0,0,0,1);
    tensor(7'h7f,0,0,0,0,0);
    inst=0; inst[6:0]=7'h3f; inst[38:32]=7'h03; inst[47:43]=5'd9;
    inst[19:15]=5'd4; inst_is_64b=1; #1;
    if(!legal||accel_is_tensor||!accel_needs_capture||
       accel_capture_src_gpr!=5'd9||!accel_needs_base_gpr||
       accel_base_src_gpr!=5'd4) $fatal(1,"vector property mismatch");
    $display("TEST PASS: shared instruction classifier properties");
    $finish;
  end
endmodule
