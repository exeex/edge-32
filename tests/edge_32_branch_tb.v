`timescale 1ns/1ps

module edge_32_branch_tb;
  localparam BRANCH=4'd8, JAL=4'd6, JALR=4'd7;
  reg [3:0] op;
  reg [31:0] pc;
  reg [31:0] src0, src1, imm, branch_imm, jal_imm;
  reg [2:0] funct3;
  wire taken;
  wire [31:0] target;

  edge_32_branch #(.PC_WIDTH(40)) dut(
    .branch_issue_op(op), .branch_issue_pc(pc),
    .branch_issue_src0_value(src0), .branch_issue_src1_value(src1),
    .branch_issue_imm(imm), .branch_issue_branch_imm(branch_imm),
    .branch_issue_jal_imm(jal_imm), .branch_issue_funct3(funct3),
    .branch_taken(taken), .branch_target(target));

  task check;
    input expected_taken;
    input [31:0] expected_target;
    input [255:0] name;
    begin
      #1;
      if (taken !== expected_taken || target !== expected_target) begin
        $display("TEST FAIL: %0s taken=%b target=%010x", name, taken, target);
        $fatal(1);
      end
    end
  endtask

  initial begin
    op=BRANCH; pc=32'h1_0000_1000; src0=5; src1=5;
    imm=0; branch_imm=32'hffff_fffc; jal_imm=0;
    funct3=3'b000; check(1, 32'h0000_0ffc, "beq negative target");
    funct3=3'b001; check(0, 32'h0000_0ffc, "bne false");
    src0=32'hffff_ffff; src1=1;
    funct3=3'b100; check(1, 32'h0000_0ffc, "blt signed");
    funct3=3'b101; check(0, 32'h0000_0ffc, "bge signed false");
    funct3=3'b110; check(0, 32'h0000_0ffc, "bltu unsigned false");
    funct3=3'b111; check(1, 32'h0000_0ffc, "bgeu unsigned");
    funct3=3'b010; check(0, 32'h0000_0ffc, "reserved funct3");

    pc=32'h0_ffff_fffc; branch_imm=8; funct3=3'b000; src0=src1;
    check(1, 32'h0000_0004, "branch target wraps at XLEN");

    op=JAL; jal_imm=8; check(1, 32'h0000_0004, "jal wrap");
    op=JALR; src0=32'hffff_fffc; imm=7;
    check(1, 32'h0000_0002, "jalr wrap and clear bit zero");
    src0=32'h0000_1000; imm=32'hffff_fffc;
    check(1, 32'h0000_0ffc, "jalr negative immediate");

    $display("TEST PASS: edge_32_branch");
    $finish;
  end
endmodule
