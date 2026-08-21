`timescale 1ns/1ps

module edge_32_alu_tb;
  localparam OP_IMM=4'd0, OP=4'd1, OP_IMM32=4'd2, OP32=4'd3;
  localparam LUI=4'd4, AUIPC=4'd5, JAL=4'd6, JALR=4'd7;
  localparam ZBA=4'd9, ZBA_UW=4'd10;
  reg [3:0] op;
  reg [31:0] pc;
  reg [31:0] src0, src1, imm;
  reg [2:0] funct3;
  reg bit5, is_m;
  reg [4:0] shamt;
  wire [31:0] result;

  edge_32_alu #(.PC_WIDTH(40)) dut(
    .fast_issue_op(op), .fast_issue_pc(pc),
    .fast_issue_src0_value(src0), .fast_issue_src1_value(src1),
    .fast_issue_imm(imm), .fast_issue_funct3(funct3),
    .fast_issue_funct7_bit5(bit5), .fast_issue_funct7_is_m(is_m),
    .fast_issue_shamt(shamt), .fast_result(result));

  task check;
    input [31:0] expected;
    input [255:0] name;
    begin
      #1;
      if (result !== expected) begin
        $display("TEST FAIL: %0s expected=%08x actual=%08x", name, expected, result);
        $fatal(1);
      end
    end
  endtask

  initial begin
    op=OP_IMM; pc=32'h1_00001000; src0=0; src1=0; imm=0;
    funct3=0; bit5=0; is_m=0; shamt=0;
    src0=32'hffff_ffff; imm=1; check(0, "addi wrap");
    funct3=3'b010; src0=32'hffff_ffff; imm=0; check(1, "slti signed");
    funct3=3'b011; check(0, "sltiu unsigned");
    funct3=3'b100; src0=32'ha5a5_0f0f; imm=32'hffff_00ff;
    check(32'h5a5a_0ff0, "xori");
    funct3=3'b110; check(32'hffff_0fff, "ori");
    funct3=3'b111; check(32'ha5a5_000f, "andi");
    funct3=3'b001; src0=1; shamt=31; check(32'h8000_0000, "slli 31");
    funct3=3'b101; src0=32'h8000_0000; bit5=0; shamt=31;
    check(1, "srli 31");
    bit5=1; check(32'hffff_ffff, "srai 31");

    op=OP; bit5=0; funct3=0; src0=32'hffff_ffff; src1=2;
    check(1, "add wrap");
    bit5=1; src0=1; src1=2; check(32'hffff_ffff, "sub");
    bit5=0; funct3=3'b001; src0=1; src1=32'hffff_ffff;
    check(32'h8000_0000, "sll masks rs2");
    funct3=3'b010; src0=32'h8000_0000; src1=1; check(1, "slt");
    funct3=3'b011; check(0, "sltu");
    funct3=3'b100; src0=32'h55aa_00ff; src1=32'h0ff0_f00f;
    check(32'h5a5a_f0f0, "xor");
    funct3=3'b101; src0=32'h8000_0000; src1=4; bit5=1;
    check(32'hf800_0000, "sra");
    bit5=0; check(32'h0800_0000, "srl");
    src0=32'h55aa_00ff; src1=32'h0ff0_f00f;
    funct3=3'b110; check(32'h5ffa_f0ff, "or");
    funct3=3'b111; check(32'h05a0_000f, "and");
    is_m=1; funct3=0; check(0, "M bypass"); is_m=0;

    op=LUI; imm=32'h1234_5000; check(32'h1234_5000, "lui");
    op=AUIPC; pc=32'h1_fffffff0; imm=32'h20; check(32'h10, "auipc wrap");
    op=JAL; check(32'hffff_fff4, "jal link");
    op=JALR; check(32'hffff_fff4, "jalr link");

    op=ZBA; src0=32'h4000_0001; src1=3; funct3=3'b010;
    check(32'h8000_0005, "sh1add");
    funct3=3'b100; check(32'h0000_0007, "sh2add wrap");
    funct3=3'b110; check(32'h0000_000b, "sh3add wrap");

    op=OP_IMM32; check(0, "no OP-IMM-32");
    op=OP32; check(0, "no OP-32");
    op=ZBA_UW; check(0, "no Zba UW");
    $display("TEST PASS: edge_32_alu");
    $finish;
  end
endmodule
