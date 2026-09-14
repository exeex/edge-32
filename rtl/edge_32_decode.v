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
  wire shared_accel_needs_capture;
  wire [4:0] shared_accel_capture_src_gpr;
  wire [6:0] opcode = inst[6:0];
  wire [2:0] funct3 = inst[14:12];
  wire [6:0] funct7 = inst[31:25];
  wire is_asic32 = !inst_is_64b && (opcode == 7'h3f);
  wire [63:0] classifier_inst = is_asic32 ?
    {24'b0, 1'b1, funct7, inst[31:0]} : inst;

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
  wire local_legal = is_asic32 ? shared_legal :
                     shared_is_edge64 ? shared_legal :
                     (!inst_is_64b && rv32_scalar_legal);

  assign legal = local_legal;
  assign op_class = local_legal ? shared_op_class : CLASS_ILLEGAL;
  assign writes_gpr = local_legal && !is_asic32 && shared_writes_gpr;
  assign accel_needs_capture = shared_accel_needs_capture;
  assign accel_capture_src_gpr = is_asic32 ? inst[19:15] :
                                shared_accel_capture_src_gpr;

  edge_instruction_classifier classifier (
    .inst(classifier_inst), .inst_is_64b(is_asic32 || inst_is_64b),
    .op_class(shared_op_class), .legal(shared_legal),
    .rd(rd), .rs1(rs1), .rs2(rs2), .scalar_issue_class(),
    .writes_gpr(shared_writes_gpr), .is_edge64(shared_is_edge64),
    .accel_is_tensor(), .accel_subop(accel_subop),
    .accel_needs_capture(shared_accel_needs_capture),
    .accel_capture_src_gpr(shared_accel_capture_src_gpr),
    .accel_needs_base_gpr(), .accel_base_src_gpr(),
    .accel_is_sync(), .accel_is_getcsr());
endmodule

// ID resolves register domains and the complete scalar execution packet.
// The core captures this packet with operands; EX performs no opcode decode.
module edge_32_issue_decode #(parameter ENABLE_FPU=0)(
  input wire [63:0] inst, input wire [3:0] op_class,
  input wire decoded_legal, input wire decoded_writes_gpr,
  input wire accel_needs_capture, input wire [4:0] accel_capture_src_gpr,
  input wire [31:0] fpu_control,
  output wire [56:0] control,
  output wire [31:0] alu_imm, mem_imm, branch_imm, jump_imm,
  output wire [4:0] read_gpr0, read_gpr1, read_fpr0, read_fpr1, read_fpr2,
  output wire [1:0] uses_gpr, output wire [2:0] uses_fpr,
  output wire [4:0] write_rd, output wire writes_gpr, writes_fpr,
  output wire issue_legal
);
  localparam [3:0] A_IMM=0, A_OP=1, A_IMM32=2, A_OP32=3,
    A_LUI=4, A_AUIPC=5, A_JAL=6, A_JALR=7, A_BRANCH=8,
    A_ZBA=9, A_ZBA_UW=10;
  wire [6:0] opc=inst[6:0]; wire [2:0] f3=inst[14:12];
  wire [6:0] f7=inst[31:25]; wire [4:0] rd=inst[11:7];
  wire is_opimm=opc==7'h13, is_op=opc==7'h33;
  wire is_opimm32=opc==7'h1b, is_op32=opc==7'h3b;
  wire is_lui=opc==7'h37, is_auipc=opc==7'h17;
  wire is_jal=opc==7'h6f, is_jalr=(opc==7'h67)&&(f3==0);
  wire is_branch=opc==7'h63;
  wire is_load=opc==7'h03, is_store=opc==7'h23;
  wire is_fp_load=(op_class==4'd5)&&(opc==7'h07);
  wire is_fp_store=(op_class==4'd5)&&(opc==7'h27);
  wire is_fp_compute=(opc==7'h53)||(opc==7'h43)||(opc==7'h47)||
                     (opc==7'h4b)||(opc==7'h4f);
  wire is_muldiv=op_class==4'd4;
  wire is_zba=is_op&&(f7==7'b0010000)&&
    ((f3==2)||(f3==4)||(f3==6));
  wire is_zba_uw=is_op32&&(((f7==7'b0000100)&&(f3==0))||
    ((f7==7'b0010000)&&((f3==2)||(f3==4)||(f3==6))));
  wire is_slli_uw=is_opimm32&&(f3==1)&&(inst[31:26]==6'b000010);
  wire is_cycle=(opc==7'h73)&&(f3==3'b010)&&(inst[31:20]==12'hc00)&&
    (inst[19:15]==0);
  wire is_instret=(opc==7'h73)&&(f3==3'b010)&&(inst[31:20]==12'hc02)&&
    (inst[19:15]==0);
  wire is_hardware_id=(opc==7'h73)&&(f3==3'b010)&&
    (inst[31:20]==12'hfc0)&&(inst[19:15]==0);
  wire is_csr_op=(opc==7'h73)&&(f3[1:0]!=2'b00);
  wire is_icache_header_csr=is_csr_op&&(inst[31:20]==12'h7db);
  wire is_dcache_header_csr=is_csr_op&&(inst[31:20]==12'h7dc);
  wire is_address_header_csr=is_icache_header_csr||is_dcache_header_csr;
  wire is_fp_csr=ENABLE_FPU&&is_csr_op&&
    ((inst[31:20]==12'h001)||(inst[31:20]==12'h002)||
     (inst[31:20]==12'h003));
  wire is_ebreak=inst==64'h0000_0000_0010_0073;
  wire is_edge_break=(opc==7'h73)&&(f3==3'b001)&&(rd==5'd0)&&
    (inst[31:20]==12'h7e0);
  wire is_edge_cache=(op_class==4'd7)&&(opc==7'h0b);
  wire is_fast_class=(op_class==4'd0)||(op_class==4'd1);
  wire is_int_mem=(op_class==4'd2)||(op_class==4'd3);
  wire is_fp_mem=ENABLE_FPU&&(is_fp_load||is_fp_store);
  wire is_fence=(op_class==4'd6)&&(opc==7'h0f);
  wire is_fence_i=is_fence&&(f3==3'b001);
  wire is_supported_system=is_cycle||is_instret||is_hardware_id||
    is_address_header_csr||is_ebreak||is_edge_break||is_fp_csr||is_fence;
  wire is_accel=(inst[6:0]==7'h3f)&&(op_class==4'd8);
  wire fpu_legal=|fpu_control[28:25];
  wire ex_supported=is_accel||is_fast_class||is_muldiv||is_int_mem||is_fp_mem||
    is_supported_system||is_edge_cache||
    (ENABLE_FPU&&is_fp_compute&&fpu_legal);
  wire decoded_issue_legal=decoded_legal&&ex_supported;


  wire [11:0] i12=inst[31:20];
  wire [11:0] s12={inst[31:25],inst[11:7]};
  wire [31:0] imm_i={{20{i12[11]}},i12};
  wire [31:0] imm_s={{20{s12[11]}},s12};
  wire [31:0] imm_u={inst[31:12],12'b0};
  wire [31:0] imm_b={{19{inst[31]}},inst[31],inst[7],
    inst[30:25],inst[11:8],1'b0};
  wire [31:0] imm_j={{11{inst[31]}},inst[31],inst[19:12],
    inst[20],inst[30:21],1'b0};
  reg [3:0] alu_op;
  always @* begin
    alu_op=A_OP;
    if(is_opimm) alu_op=A_IMM;
    else if(is_opimm32) alu_op=is_slli_uw ? A_ZBA_UW:A_IMM32;
    else if(is_op32) alu_op=is_zba_uw||is_slli_uw ? A_ZBA_UW:A_OP32;
    else if(is_zba) alu_op=A_ZBA; else if(is_lui) alu_op=A_LUI;
    else if(is_auipc) alu_op=A_AUIPC; else if(is_jal) alu_op=A_JAL;
    else if(is_jalr) alu_op=A_JALR; else if(is_branch) alu_op=A_BRANCH;
  end

  wire fp_gpr_source=(fpu_control[26] && fpu_control[14:13]==2'd2) ||
    (fpu_control[25] && (fpu_control[18:15]==4'd5 || fpu_control[18:15]==4'd7));
  wire fp_gpr_dest=(fpu_control[26] && fpu_control[14:13]==2'd1) ||
    (fpu_control[25] && (fpu_control[18:15]==4'd2 || fpu_control[18:15]==4'd3 ||
                        fpu_control[18:15]==4'd4 || fpu_control[18:15]==4'd6));
  wire fp_second=fpu_control[28] || (fpu_control[27] && !fpu_control[12]) ||
    (fpu_control[25] && fpu_control[18:15]<=4'd2);
  assign issue_legal=decoded_issue_legal;
  assign uses_gpr[0]=issue_legal && (is_opimm||is_op||is_opimm32||is_op32||
    is_jalr||is_branch||is_int_mem||is_fp_mem||is_edge_cache||is_accel||
    is_edge_break||(is_csr_op&&!f3[2])||(is_fp_compute&&fp_gpr_source));
  assign uses_gpr[1]=issue_legal && (is_op||is_op32||is_branch||is_store||
    (is_accel&&accel_needs_capture));
  assign uses_fpr[0]=issue_legal && ENABLE_FPU && is_fp_compute && !fp_gpr_source;
  assign uses_fpr[1]=issue_legal && ENABLE_FPU &&
    (is_fp_store||(is_fp_compute&&fp_second));
  assign uses_fpr[2]=issue_legal && ENABLE_FPU && is_fp_compute &&
    fpu_control[28] && fpu_control[21];
  assign read_gpr0=uses_gpr[0] ? inst[19:15]:5'd0;
  assign read_gpr1=uses_gpr[1] ?
    (is_accel ? accel_capture_src_gpr:inst[24:20]):5'd0;
  assign read_fpr0=uses_fpr[0] ? inst[19:15]:5'd0;
  assign read_fpr1=uses_fpr[1] ? inst[24:20]:5'd0;
  assign read_fpr2=uses_fpr[2] ? inst[31:27]:5'd0;
  assign write_rd=is_edge_break ? 5'd31:rd;
  assign writes_gpr=issue_legal && (write_rd!=0) &&
    (is_edge_break||(is_fp_compute ? fp_gpr_dest:decoded_writes_gpr));
  assign writes_fpr=issue_legal && ENABLE_FPU &&
    (is_fp_load||(is_fp_compute&&!fp_gpr_dest));
  wire csr_fflags=inst[31:20]==12'h001;
  wire csr_frm=inst[31:20]==12'h002;
  wire csr_write=(f3[1:0]==2'b01)||(inst[19:15]!=5'd0);
  wire cache_is_va=f3==3'b001;
  wire [1:0] cache_kind=inst[21:20];
  wire funct7_bit5=inst[30];
  wire [4:0] shamt=inst[24:20], csr_uimm=inst[19:15];
  assign alu_imm=(is_lui||is_auipc) ? imm_u:imm_i;
  assign mem_imm=(is_store||is_fp_store) ? imm_s:imm_i;
  assign branch_imm=imm_b;
  assign jump_imm=imm_j;
  assign control={is_lui,is_auipc,is_jal,is_jalr,is_branch,is_load,
    is_store,is_fp_load,is_fp_store,is_fp_compute,is_muldiv,is_cycle,
    is_instret,is_hardware_id,is_icache_header_csr,is_dcache_header_csr,is_fp_csr,is_ebreak,
    is_edge_break,is_edge_cache,is_fast_class,is_int_mem,is_fp_mem,is_fence_i,
    is_supported_system,is_accel,csr_fflags,csr_frm,csr_write,cache_is_va,
    cache_kind,f3,funct7_bit5,shamt,csr_uimm,write_rd,
    alu_op,writes_gpr,writes_fpr};
endmodule
