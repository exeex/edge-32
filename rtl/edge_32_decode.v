`timescale 1ns/1ps




// RV32 legality boundary layered on the shared Edge instruction classifier.
module edge_32_decode (
  input  wire [31:0] inst,
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
  wire [3:0] shared_op_class;
  wire shared_legal;
  wire shared_writes_gpr;
  wire shared_accel_needs_capture;
  wire [4:0] shared_accel_capture_src_gpr;
  wire [6:0] opcode = inst[6:0];
  wire [2:0] funct3 = inst[14:12];
  wire [6:0] funct7 = inst[31:25];
  wire is_asic32 = (opcode == rv32::OPCODE_EDGE_ASIC);

  wire rv32_shift_legal =
    (opcode != rv32::OPCODE_OP_IMM) ||
    ((funct3 != 3'b001) && (funct3 != 3'b101)) ||
    ((funct3 == 3'b001) && (funct7 == 7'b0000000)) ||
    ((funct3 == 3'b101) &&
     ((funct7 == 7'b0000000) || (funct7 == 7'b0100000)));
  wire rv32_load_legal = (opcode != rv32::OPCODE_LOAD) ||
    (funct3 == 3'b000) || (funct3 == 3'b001) || (funct3 == 3'b010) ||
    (funct3 == 3'b100) || (funct3 == 3'b101);
  wire rv32_store_legal = (opcode != rv32::OPCODE_STORE) || (funct3 <= 3'b010);
  wire rv64_word_opcode = (opcode == rv32::OPCODE_OP_IMM_32) || (opcode == rv32::OPCODE_OP_32);
  wire rv32_scalar_legal = shared_legal && !rv64_word_opcode &&
                           rv32_shift_legal && rv32_load_legal &&
                           rv32_store_legal;
  wire local_legal = is_asic32 ? shared_legal :
                     rv32_scalar_legal;

  assign legal = local_legal;
  assign op_class = local_legal ? shared_op_class : rv32::CLASS_ILLEGAL;
  assign writes_gpr = local_legal && !is_asic32 && shared_writes_gpr;
  assign accel_needs_capture = shared_accel_needs_capture;
  assign accel_capture_src_gpr = is_asic32 ? inst[19:15] :
                                shared_accel_capture_src_gpr;

  edge_instruction_classifier classifier (
    .inst(inst),
    .op_class(shared_op_class), .legal(shared_legal),
    .rd(rd), .rs1(rs1), .rs2(rs2), .scalar_issue_class(),
    .writes_gpr(shared_writes_gpr), .is_accel(),
    .accel_is_tensor(), .accel_subop(accel_subop),
    .accel_needs_capture(shared_accel_needs_capture),
    .accel_capture_src_gpr(shared_accel_capture_src_gpr),
    .accel_needs_base_gpr(), .accel_base_src_gpr(),
    .accel_is_sync(), .accel_is_getcsr());
endmodule

// Parallel semantic sideband. It does not drive register read addresses.
// EX consumes the registered packet and legality to authorize issue.
module edge_32_issue_decode #(parameter ENABLE_FPU=0)(
  input wire [31:0] inst, input wire [3:0] op_class,
  input wire decoded_legal,
  input wire [4:0] register_rd, input wire rd_gpr, rd_fpr,
  input wire [31:0] fpu_control,
  output wire [55:0] control,
  output wire terminal_break,
  output wire [31:0] alu_imm, mem_imm, branch_imm, jump_imm,
  output wire writes_gpr, writes_fpr,
  output wire issue_legal
);
  // Common R/I/S/B/U/J fields; parallel family predicates below.
  wire [4:0] rs1 = inst[19:15], rs2 = inst[24:20];
  wire [11:0] csr_addr = inst[31:20];
  wire [6:0] opcode=inst[6:0]; wire [2:0] funct3=inst[14:12];
  wire [6:0] funct7=inst[31:25]; wire [4:0] rd=inst[11:7];
  // Integer OP/OP-IMM, upper-immediate and control-transfer families.
  wire is_opimm=opcode==rv32::OPCODE_OP_IMM, is_op=opcode==rv32::OPCODE_OP;
  wire is_opimm32=opcode==rv32::OPCODE_OP_IMM_32, is_op32=opcode==rv32::OPCODE_OP_32;
  wire is_lui=opcode==rv32::OPCODE_LUI, is_auipc=opcode==rv32::OPCODE_AUIPC;
  wire is_jal=opcode==rv32::OPCODE_JAL, is_jalr=(opcode==rv32::OPCODE_JALR)&&(funct3==0);
  wire is_branch=opcode==rv32::OPCODE_BRANCH;
  wire is_load=opcode==rv32::OPCODE_LOAD, is_store=opcode==rv32::OPCODE_STORE;
  // Floating-point load/store, OP-FP and R4 fused multiply-add families.
  wire is_fp_load=ENABLE_FPU&&(op_class==rv32::CLASS_FPU)&&(opcode==rv32::OPCODE_LOAD_FP);
  wire is_fp_store=ENABLE_FPU&&(op_class==rv32::CLASS_FPU)&&(opcode==rv32::OPCODE_STORE_FP);
  wire is_fp_compute=ENABLE_FPU&&((opcode==rv32::OPCODE_OP_FP)||(opcode==rv32::OPCODE_MADD)||(opcode==rv32::OPCODE_MSUB)||
                     (opcode==rv32::OPCODE_NMSUB)||(opcode==rv32::OPCODE_NMADD));
  wire is_muldiv=op_class==rv32::CLASS_MULDIV;
  // funct7/funct3 refinement: M/Zba and inherited RV64 word selectors.
  // RV32 legality still rejects word encodings; do not change illegal sideband.
  wire is_zba=is_op&&(funct7==7'b0010000)&&
    ((funct3==2)||(funct3==4)||(funct3==6));
  wire is_zba_uw=is_op32&&(((funct7==7'b0000100)&&(funct3==0))||
    ((funct7==7'b0010000)&&((funct3==2)||(funct3==4)||(funct3==6))));
  wire is_slli_uw=is_opimm32&&(funct3==1)&&(inst[31:26]==6'b000010);
  // SYSTEM: CSR address/funct3 refinement and terminal policy.
  wire is_cycle=(opcode==rv32::OPCODE_SYSTEM)&&(funct3==3'b010)&&(csr_addr==rv32::CSR_CYCLE)&&
    (rs1==0);
  wire is_instret=(opcode==rv32::OPCODE_SYSTEM)&&(funct3==3'b010)&&(csr_addr==rv32::CSR_INSTRET)&&
    (rs1==0);
  wire is_hardware_id=(opcode==rv32::OPCODE_SYSTEM)&&(funct3==3'b010)&&
    (csr_addr==rv32::CSR_EDGE_HARDWARE_ID)&&(rs1==0);
  wire is_csr_op=(opcode==rv32::OPCODE_SYSTEM)&&(funct3[1:0]!=2'b00);
  wire is_icache_header_csr=is_csr_op&&(csr_addr==rv32::CSR_EDGE_ICACHE_HEADER);
  wire is_dcache_header_csr=is_csr_op&&(csr_addr==rv32::CSR_EDGE_DCACHE_HEADER);
  wire is_address_header_csr=is_icache_header_csr||is_dcache_header_csr;
  wire is_fp_csr=ENABLE_FPU&&is_csr_op&&
    ((csr_addr==rv32::CSR_FFLAGS)||(csr_addr==rv32::CSR_FRM)||
     (csr_addr==rv32::CSR_FCSR));
  wire is_ebreak=inst==32'h0010_0073;
  wire is_edge_break=(opcode==rv32::OPCODE_SYSTEM)&&(funct3==3'b001)&&(rd==5'd0)&&
    (csr_addr==rv32::CSR_EDGE_BREAK);
  // Merge the terminal instruction policy before the ID->EX capture.
  assign terminal_break=is_ebreak||is_edge_break;
  // Parallel class/legality qualification; no serial opcode dispatch.
  wire is_edge_cache=(op_class==rv32::CLASS_CUSTOM)&&(opcode==rv32::OPCODE_EDGE_CACHE);
  wire is_fast_class=(op_class==rv32::CLASS_ALU)||(op_class==rv32::CLASS_BRANCH);
  wire is_int_mem=(op_class==rv32::CLASS_LOAD)||(op_class==rv32::CLASS_STORE);
  wire is_fp_mem=ENABLE_FPU&&(is_fp_load||is_fp_store);
  wire is_fence=(op_class==rv32::CLASS_SYSTEM)&&(opcode==rv32::OPCODE_MISC_MEM);
  wire is_fence_i=is_fence&&(funct3==3'b001);
  wire is_supported_system=is_cycle||is_instret||is_hardware_id||
    is_address_header_csr||is_ebreak||is_edge_break||is_fp_csr||is_fence;
  wire is_accel=(inst[6:0]==rv32::OPCODE_EDGE_ASIC)&&(op_class==rv32::CLASS_ACCEL);
  wire fpu_legal=|fpu_control[28:25];
  wire ex_supported=is_accel||is_fast_class||is_muldiv||is_int_mem||is_fp_mem||
    is_supported_system||is_edge_cache||
    (ENABLE_FPU&&is_fp_compute&&fpu_legal);
  wire decoded_issue_legal=decoded_legal&&ex_supported;


  // I/S/U/B/J immediate layouts, computed concurrently.
  wire [11:0] i12=inst[31:20];
  wire [11:0] s12={inst[31:25],inst[11:7]};
  wire [31:0] imm_i={{20{i12[11]}},i12};
  wire [31:0] imm_s={{20{s12[11]}},s12};
  wire [31:0] imm_u={inst[31:12],12'b0};
  wire [31:0] imm_b={{19{inst[31]}},inst[31],inst[7],
    inst[30:25],inst[11:8],1'b0};
  wire [31:0] imm_j={{11{inst[31]}},inst[31],inst[19:12],
    inst[20],inst[30:21],1'b0};
  // Existing ALU selector priority only; independent predicates stay parallel.
  rv32::alu_op_t alu_op;
  always_comb begin
    alu_op=rv32::A_OP;
    if(is_opimm) alu_op=rv32::A_IMM;
    else if(is_opimm32) alu_op=is_slli_uw ? rv32::A_ZBA_UW:rv32::A_IMM32;
    else if(is_op32) alu_op=is_zba_uw||is_slli_uw ? rv32::A_ZBA_UW:rv32::A_OP32;
    else if(is_zba) alu_op=rv32::A_ZBA; else if(is_lui) alu_op=rv32::A_LUI;
    else if(is_auipc) alu_op=rv32::A_AUIPC; else if(is_jal) alu_op=rv32::A_JAL;
    else if(is_jalr) alu_op=rv32::A_JALR; else if(is_branch) alu_op=rv32::A_BRANCH;
  end

  wire [4:0] write_rd=register_rd;
  assign issue_legal=decoded_issue_legal;
  assign writes_gpr=issue_legal && rd_gpr;
  assign writes_fpr=ENABLE_FPU && issue_legal && rd_fpr;
  wire csr_fflags=ENABLE_FPU&&(csr_addr==rv32::CSR_FFLAGS);
  wire csr_frm=ENABLE_FPU&&(csr_addr==rv32::CSR_FRM);
  wire csr_write=(funct3[1:0]==2'b01)||(rs1!=5'd0);
  wire cache_is_va=funct3==3'b001;
  wire [1:0] cache_kind=inst[21:20];
  wire funct7_bit5=inst[30];
  wire [4:0] shamt=rs2, csr_uimm=rs1;
  assign alu_imm=(is_lui||is_auipc) ? imm_u:imm_i;
  assign mem_imm=(is_store||is_fp_store) ? imm_s:imm_i;
  assign branch_imm=imm_b;
  assign jump_imm=imm_j;
  rv32::issue_control_t issue_packet;
  assign issue_packet.is_lui = is_lui;
  assign issue_packet.is_auipc = is_auipc;
  assign issue_packet.is_jal = is_jal;
  assign issue_packet.is_jalr = is_jalr;
  assign issue_packet.is_branch = is_branch;
  assign issue_packet.is_load = is_load;
  assign issue_packet.is_store = is_store;
  assign issue_packet.is_fp_load = is_fp_load;
  assign issue_packet.is_fp_store = is_fp_store;
  assign issue_packet.is_fp_compute = is_fp_compute;
  assign issue_packet.is_muldiv = is_muldiv;
  assign issue_packet.is_cycle = is_cycle;
  assign issue_packet.is_instret = is_instret;
  assign issue_packet.is_hardware_id = is_hardware_id;
  assign issue_packet.is_icache_header_csr = is_icache_header_csr;
  assign issue_packet.is_dcache_header_csr = is_dcache_header_csr;
  assign issue_packet.is_fp_csr = is_fp_csr;
  assign issue_packet.is_edge_break = is_edge_break;
  assign issue_packet.is_edge_cache = is_edge_cache;
  assign issue_packet.is_fast_class = is_fast_class;
  assign issue_packet.is_int_mem = is_int_mem;
  assign issue_packet.is_fp_mem = is_fp_mem;
  assign issue_packet.is_fence_i = is_fence_i;
  assign issue_packet.is_supported_system = is_supported_system;
  assign issue_packet.is_accel = is_accel;
  assign issue_packet.csr_fflags = csr_fflags;
  assign issue_packet.csr_frm = csr_frm;
  assign issue_packet.csr_write = csr_write;
  assign issue_packet.cache_is_va = cache_is_va;
  assign issue_packet.cache_kind = cache_kind;
  assign issue_packet.funct3 = funct3;
  assign issue_packet.funct7_bit5 = funct7_bit5;
  assign issue_packet.shamt = shamt;
  assign issue_packet.csr_uimm = csr_uimm;
  assign issue_packet.write_rd = write_rd;
  assign issue_packet.alu_op = alu_op;
  assign issue_packet.writes_gpr = writes_gpr;
  assign issue_packet.writes_fpr = writes_fpr;
  assign control = issue_packet;
endmodule

// Early IF register routing (captured with the admitted ID instruction). Deliberately has no legality, operation-class,
// rounding-mode or semantic FP-control input. Invalid encodings may request
// reads; only the parallel sideband authorizes EX issue and writes.
module edge_32_register_decode #(parameter ENABLE_FPU=0,
  parameter UNMASKED_GPR_READ=0)(
  input wire [31:0] inst,
  output wire [4:0] read_gpr0, read_gpr1, read_fpr0, read_fpr1, read_fpr2,
  output wire [1:0] uses_gpr, output wire [2:0] uses_fpr,
  output wire [4:0] write_rd, output wire rd_gpr, rd_fpr,
  output wire csr_write
);
  wire [4:0] rs1 = inst[19:15], rs2 = inst[24:20], rs3 = inst[31:27];
  wire [11:0] csr_addr = inst[31:20];
  wire [6:0] opcode=inst[6:0];
  wire [2:0] funct3=inst[14:12];
  wire [4:0] fp_family=inst[31:27];
  // Integer register use follows opcode, independently of issue legality.
  wire op_imm=(opcode==rv32::OPCODE_OP_IMM)||(opcode==rv32::OPCODE_OP_IMM_32);
  wire op_reg=(opcode==rv32::OPCODE_OP)||(opcode==rv32::OPCODE_OP_32);
  // F/D register domains follow OP-FP/R4 encoding and conversion family.
  wire fp_op=ENABLE_FPU&&(opcode==rv32::OPCODE_OP_FP);
  wire fp_fma=ENABLE_FPU&&((opcode==rv32::OPCODE_MADD)||(opcode==rv32::OPCODE_MSUB)||
                          (opcode==rv32::OPCODE_NMSUB)||(opcode==rv32::OPCODE_NMADD));
  wire fp_load=ENABLE_FPU&&(opcode==rv32::OPCODE_LOAD_FP);
  wire fp_store=ENABLE_FPU&&(opcode==rv32::OPCODE_STORE_FP);
  // Source/destination domains depend on the operation family, not on format,
  // rounding validity or reserved-field checks performed in the sideband.
  wire fp_from_gpr=fp_op&&((fp_family==5'b11010)||(fp_family==5'b11110));
  wire fp_to_gpr=fp_op&&((fp_family==5'b11000)||(fp_family==5'b11100)||
                        (fp_family==5'b10100));
  wire fp_two=fp_op&&((fp_family==5'b00000)||(fp_family==5'b00001)||
    (fp_family==5'b00010)||(fp_family==5'b00011)||(fp_family==5'b00100)||
    (fp_family==5'b00101)||(fp_family==5'b10100));
  // SYSTEM and local ASIC capture routing.
  wire csr_op=(opcode==rv32::OPCODE_SYSTEM)&&(funct3[1:0]!=0);
  wire edge_break=(opcode==rv32::OPCODE_SYSTEM)&&(funct3==3'b001)&&(inst[11:7]==0)&&
                  (csr_addr==rv32::CSR_EDGE_BREAK);
  wire accel=(opcode==rv32::OPCODE_EDGE_ASIC);
  wire [6:0] subop=inst[31:25];
  reg tensor_capture;
  always_comb begin
    case(subop)
        rv32::ASIC_DMA_START, rv32::ASIC_DMA_SETN,
        rv32::ASIC_DMA_SETX, rv32::ASIC_DMA_SETY,
        rv32::ASIC_DMA_SETSRC, rv32::ASIC_DMA_SETTAR,
        rv32::ASIC_DMA_SETENTRY, rv32::ASIC_TENSOR_WLD,
        rv32::ASIC_TENSOR_SETIN, rv32::ASIC_TENSOR_SETOUT,
        rv32::ASIC_TENSOR_SETPSUM, rv32::ASIC_TENSOR_SETN,
        rv32::ASIC_TENSOR_WLD_T, rv32::ASIC_TENSOR_SLD_STREAM,
        rv32::ASIC_TENSOR_SLD, rv32::ASIC_ACTU_SETIN,
        rv32::ASIC_ACTU_SETOUT, rv32::ASIC_ACTU_SETN,
        rv32::ASIC_ACTU_SETSCALAR, rv32::ASIC_CMPU_SETLHS,
        rv32::ASIC_CMPU_SETRHS, rv32::ASIC_CMPU_SETMASK,
        rv32::ASIC_CMPU_SETOUT, rv32::ASIC_CMPU_SETN:
        tensor_capture=1'b1;
      default: tensor_capture=1'b0;
    endcase
  end
  wire accel_capture=accel&&tensor_capture;
  wire [4:0] capture_src=rs1;
  assign uses_gpr[0]=op_imm||op_reg||(opcode==rv32::OPCODE_JALR)||(opcode==rv32::OPCODE_BRANCH)||
    (opcode==rv32::OPCODE_LOAD)||(opcode==rv32::OPCODE_STORE)||fp_load||fp_store||(opcode==rv32::OPCODE_EDGE_CACHE)||accel||
    (csr_op&&!funct3[2])||fp_from_gpr;
  assign uses_gpr[1]=op_reg||(opcode==rv32::OPCODE_BRANCH)||(opcode==rv32::OPCODE_STORE)||accel_capture;
  assign uses_fpr[0]=fp_fma||(fp_op&&!fp_from_gpr);
  assign uses_fpr[1]=fp_fma||fp_two||fp_store;
  assign uses_fpr[2]=fp_fma;
  assign read_gpr0=(UNMASKED_GPR_READ || uses_gpr[0]) ? rs1:5'd0;
  assign read_gpr1=(UNMASKED_GPR_READ || uses_gpr[1]) ?
    (accel ? capture_src:rs2):5'd0;
  assign read_fpr0=uses_fpr[0] ? rs1:5'd0;
  assign read_fpr1=uses_fpr[1] ? rs2:5'd0;
  assign read_fpr2=uses_fpr[2] ? rs3:5'd0;
  assign write_rd=edge_break ? 5'd31:inst[11:7];
  assign rd_gpr=(write_rd!=0)&&(op_imm||op_reg||(opcode==rv32::OPCODE_LUI)||
    (opcode==rv32::OPCODE_AUIPC)||(opcode==rv32::OPCODE_JAL)||(opcode==rv32::OPCODE_JALR)||
    (opcode==rv32::OPCODE_LOAD)||csr_op||fp_to_gpr);
  assign rd_fpr=fp_load||fp_fma||(fp_op&&!fp_to_gpr);
  // Conservatively interlock a CSR writer without waiting for legality.
  assign csr_write=csr_op&&
    ((funct3[1:0]==2'b01)||(rs1!=0));
endmodule
