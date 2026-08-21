`timescale 1ns/1ps

module edge_32_decode_tb;
  reg [63:0] inst;
  reg inst_is_64b;
  wire [3:0] op_class;
  wire legal, writes_gpr;
  wire [4:0] rd, rs1, rs2;
  wire [6:0] accel_subop;
  wire accel_needs_capture;
  wire [4:0] accel_capture_src_gpr;
  integer funct3_i, funct7_i;

  edge_32_decode dut(.*);

  task check_decode;
    input expected_legal;
    input [3:0] expected_class;
    input [255:0] name;
    begin
      #1;
      if (legal !== expected_legal || op_class !== expected_class)
        $fatal(1, "TEST FAIL: %0s legal/class=%0d/%0d", name, legal, op_class);
      if (!expected_legal && writes_gpr)
        $fatal(1, "TEST FAIL: %0s illegal instruction writes GPR", name);
    end
  endtask

  initial begin
    inst_is_64b=0; inst=0;
    inst=64'h0000_0000_0020_00b3; check_decode(1,4'd0,"RV32 add");
    inst=64'h0000_0000_0220_00b3; check_decode(1,4'd4,"RV32 mul");
    inst=64'h0000_0000_2020_20b3; check_decode(1,4'd0,"RV32 sh1add");

    inst=0; inst[6:0]=7'h13; inst[14:12]=3'b001;
    inst[31:25]=7'b0000000; check_decode(1,4'd0,"RV32 slli shamt31 space");
    inst[25]=1'b1; check_decode(0,4'd15,"RV64 slli shamt32");
    inst[14:12]=3'b101; inst[31:25]=7'b0100000;
    check_decode(1,4'd0,"RV32 srai");
    inst[25]=1'b1; check_decode(0,4'd15,"RV64 srai shamt32");

    for(funct3_i=0;funct3_i<8;funct3_i=funct3_i+1) begin
      inst=0; inst[6:0]=7'h03; inst[14:12]=funct3_i[2:0];
      if(funct3_i==0||funct3_i==1||funct3_i==2||
         funct3_i==4||funct3_i==5)
        check_decode(1,4'd2,"RV32 load width");
      else check_decode(0,4'd15,"non-RV32 load width");
      inst[6:0]=7'h23;
      if(funct3_i<=2) check_decode(1,4'd3,"RV32 store width");
      else check_decode(0,4'd15,"non-RV32 store width");
    end

    for(funct3_i=0;funct3_i<8;funct3_i=funct3_i+1)
      for(funct7_i=0;funct7_i<128;funct7_i=funct7_i+1) begin
        inst=0; inst[6:0]=7'h1b; inst[14:12]=funct3_i[2:0];
        inst[31:25]=funct7_i[6:0]; check_decode(0,4'd15,"OP-IMM-32 rejected");
        inst[6:0]=7'h3b; check_decode(0,4'd15,"OP-32 rejected");
      end

    inst=0; inst[6:0]=7'h3f; inst[31:25]=7'h11; inst[19:15]=5'd6;
    check_decode(1,4'd8,"ASIC32 command");
    if(accel_subop!=7'h11||accel_capture_src_gpr!=5'd6||writes_gpr)
      $fatal(1,"TEST FAIL: ASIC32 field decode");
    inst[31:25]=7'h7f; check_decode(0,4'd15,"unallocated ASIC32 command");

    $display("TEST PASS: edge_32_decode RV32 legality boundary");
    $finish;
  end
endmodule
