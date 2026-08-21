`timescale 1ns/1ps

// RV32 legality boundary layered on the shared Edge instruction classifier.
module edge_32_decode (
  input  wire [63:0] inst,
  input  wire inst_is_64b,
  output wire [3:0] op_class,
  output wire legal,
  output wire [4:0] rd,
  output wire [4:0] rs1,
  output wire [4:0] rs2,
  output wire writes_gpr,
  output wire [6:0] accel_subop,
  output wire accel_needs_capture,
  output wire [4:0] accel_capture_src_gpr
);
  localparam [3:0] CLASS_ILLEGAL = 4'd15;
  wire [3:0] shared_op_class;
  wire shared_legal;
  wire shared_writes_gpr;
  wire shared_is_edge64;
  wire [6:0] opcode = inst[6:0];
  wire [2:0] funct3 = inst[14:12];
  wire [6:0] funct7 = inst[31:25];

  wire rv32_shift_legal =
    (opcode != 7'h13) ||
    ((funct3 != 3'b001) && (funct3 != 3'b101)) ||
    ((funct3 == 3'b001) && (funct7 == 7'b0000000)) ||
    ((funct3 == 3'b101) &&
     ((funct7 == 7'b0000000) || (funct7 == 7'b0100000)));
  wire rv32_load_legal = (opcode != 7'h03) ||
    (funct3 == 3'b000) || (funct3 == 3'b001) || (funct3 == 3'b010) ||
    (funct3 == 3'b100) || (funct3 == 3'b101);
  wire rv32_store_legal = (opcode != 7'h23) || (funct3 <= 3'b010);
  wire rv64_word_opcode = (opcode == 7'h1b) || (opcode == 7'h3b);
  wire rv32_scalar_legal = shared_legal && !rv64_word_opcode &&
                           rv32_shift_legal && rv32_load_legal &&
                           rv32_store_legal;
  wire local_legal = shared_is_edge64 ? shared_legal :
                     (!inst_is_64b && rv32_scalar_legal);

  assign legal = local_legal;
  assign op_class = local_legal ? shared_op_class : CLASS_ILLEGAL;
  assign writes_gpr = local_legal && shared_writes_gpr;

  edge_instruction_classifier classifier (
    .inst(inst), .inst_is_64b(inst_is_64b),
    .op_class(shared_op_class), .legal(shared_legal),
    .rd(rd), .rs1(rs1), .rs2(rs2), .scalar_issue_class(),
    .writes_gpr(shared_writes_gpr), .is_edge64(shared_is_edge64),
    .accel_is_tensor(), .accel_subop(accel_subop),
    .accel_needs_capture(accel_needs_capture),
    .accel_capture_src_gpr(accel_capture_src_gpr),
    .accel_needs_base_gpr(), .accel_base_src_gpr(),
    .accel_is_sync(), .accel_is_getcsr());
endmodule
