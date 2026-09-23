`ifndef EDGE_INSTRUCTION_CLASSIFIER_V
`define EDGE_INSTRUCTION_CLASSIFIER_V
`timescale 1ns/1ps

// Shared semantic types; file path retained for existing mixed .v/SV builds.
// Opcode groups follow the RISC-V major opcode map. EDGE_* are local ISA slots.
package rv32;
  localparam logic [6:0] OPCODE_EDGE_DMA = 7'h2b;
  localparam logic [6:0] OPCODE_LOAD = 7'h03;
  localparam logic [6:0] OPCODE_LOAD_FP = 7'h07;
  localparam logic [6:0] OPCODE_EDGE_CACHE = 7'h0b;
  localparam logic [6:0] OPCODE_MISC_MEM = 7'h0f;
  localparam logic [6:0] OPCODE_OP_IMM = 7'h13;
  localparam logic [6:0] OPCODE_AUIPC = 7'h17;
  localparam logic [6:0] OPCODE_OP_IMM_32 = 7'h1b;
  localparam logic [6:0] OPCODE_STORE = 7'h23;
  localparam logic [6:0] OPCODE_STORE_FP = 7'h27;
  localparam logic [6:0] OPCODE_OP = 7'h33;
  localparam logic [6:0] OPCODE_LUI = 7'h37;
  localparam logic [6:0] OPCODE_OP_32 = 7'h3b;
  localparam logic [6:0] OPCODE_EDGE_ASIC = 7'h3f;
  localparam logic [6:0] OPCODE_MADD = 7'h43;
  localparam logic [6:0] OPCODE_MSUB = 7'h47;
  localparam logic [6:0] OPCODE_NMSUB = 7'h4b;
  localparam logic [6:0] OPCODE_NMADD = 7'h4f;
  localparam logic [6:0] OPCODE_OP_FP = 7'h53;
  localparam logic [6:0] OPCODE_BRANCH = 7'h63;
  localparam logic [6:0] OPCODE_JALR = 7'h67;
  localparam logic [6:0] OPCODE_JAL = 7'h6f;
  localparam logic [6:0] OPCODE_SYSTEM = 7'h73;


  // Standard CSRs and explicitly named Edge implementation CSRs.
  localparam logic [11:0] CSR_FFLAGS = 12'h001;
  localparam logic [11:0] CSR_FRM = 12'h002;
  localparam logic [11:0] CSR_FCSR = 12'h003;
  localparam logic [11:0] CSR_CYCLE = 12'hc00;
  localparam logic [11:0] CSR_INSTRET = 12'hc02;
  localparam logic [11:0] CSR_EDGE_HARDWARE_ID = 12'hfc0;
  localparam logic [11:0] CSR_EDGE_ICACHE_HEADER = 12'h7db;
  localparam logic [11:0] CSR_EDGE_DCACHE_HEADER = 12'h7dc;
  localparam logic [11:0] CSR_EDGE_BREAK = 12'h7e0;
  localparam logic [11:0] CSR_EDGE_PUTCHAR = 12'h7e1;

  // Edge ASIC sub-operations (not standard RISC-V encodings).
  localparam logic [6:0] ASIC_DMA_START = 7'h01;
  localparam logic [6:0] ASIC_DMA_SYNC = 7'h02;
  localparam logic [6:0] ASIC_DMA_SETN = 7'h03;
  localparam logic [6:0] ASIC_DMA_SETX = 7'h04;
  localparam logic [6:0] ASIC_DMA_SETY = 7'h05;
  localparam logic [6:0] ASIC_DMA_SETSRC = 7'h06;
  localparam logic [6:0] ASIC_DMA_SETTAR = 7'h07;
  localparam logic [6:0] ASIC_DMA_SETENTRY = 7'h08;
  localparam logic [6:0] ASIC_POWER = 7'h09;
  localparam logic [6:0] ASIC_DMA_SETCSR = 7'h0a;
  localparam logic [6:0] ASIC_TENSOR_SETCSR = 7'h10;
  localparam logic [6:0] ASIC_TENSOR_WLD = 7'h11;
  localparam logic [6:0] ASIC_TENSOR_SETIN = 7'h12;
  localparam logic [6:0] ASIC_TENSOR_SETOUT = 7'h13;
  localparam logic [6:0] ASIC_TENSOR_SETPSUM = 7'h14;
  localparam logic [6:0] ASIC_TENSOR_START = 7'h15;
  localparam logic [6:0] ASIC_TENSOR_SYNC = 7'h16;
  localparam logic [6:0] ASIC_TENSOR_SETN = 7'h17;
  localparam logic [6:0] ASIC_TENSOR_WLD_T = 7'h18;
  localparam logic [6:0] ASIC_TENSOR_START_TILE = 7'h19;
  localparam logic [6:0] ASIC_TENSOR_SLD_STREAM = 7'h1a;
  localparam logic [6:0] ASIC_TENSOR_WLD_CIRCULAR = 7'h1b;
  localparam logic [6:0] ASIC_TENSOR_WLD_T_CIRCULAR = 7'h1c;
  localparam logic [6:0] ASIC_TENSOR_SLD = 7'h1d;
  localparam logic [6:0] ASIC_TENSOR_WSLD_CIRCULAR = 7'h1e;
  localparam logic [6:0] ASIC_TENSOR_SLD_CIRCULAR = 7'h1f;
  localparam logic [6:0] ASIC_ACTU_SETCSR = 7'h20;
  localparam logic [6:0] ASIC_ACTU_SETIN = 7'h21;
  localparam logic [6:0] ASIC_ACTU_SETOUT = 7'h22;
  localparam logic [6:0] ASIC_ACTU_SETN = 7'h23;
  localparam logic [6:0] ASIC_ACTU_SETSCALAR = 7'h24;
  localparam logic [6:0] ASIC_ACTU_START = 7'h25;
  localparam logic [6:0] ASIC_ACTU_SYNC = 7'h26;
  localparam logic [6:0] ASIC_CMPU_SETCSR = 7'h27;
  localparam logic [6:0] ASIC_CMPU_SETLHS = 7'h28;
  localparam logic [6:0] ASIC_CMPU_SETRHS = 7'h29;
  localparam logic [6:0] ASIC_CMPU_SETMASK = 7'h2a;
  localparam logic [6:0] ASIC_CMPU_SETOUT = 7'h2b;
  localparam logic [6:0] ASIC_CMPU_SETN = 7'h2c;
  localparam logic [6:0] ASIC_CMPU_START = 7'h2d;
  localparam logic [6:0] ASIC_CMPU_SYNC = 7'h2e;
  localparam logic [6:0] ASIC_GETCSR = 7'h2f;

  typedef enum logic [3:0] {
    CLASS_ALU = 4'd0,
    CLASS_BRANCH = 4'd1,
    CLASS_LOAD = 4'd2,
    CLASS_STORE = 4'd3,
    CLASS_MULDIV = 4'd4,
    CLASS_FPU = 4'd5,
    CLASS_SYSTEM = 4'd6,
    CLASS_CUSTOM = 4'd7,
    CLASS_ACCEL = 4'd8,
    CLASS_ILLEGAL = 4'd15
  } instruction_class_t;

  typedef enum logic [3:0] {
    A_IMM = 4'd0,
    A_OP = 4'd1,
    A_IMM32 = 4'd2,
    A_OP32 = 4'd3,
    A_LUI = 4'd4,
    A_AUIPC = 4'd5,
    A_JAL = 4'd6,
    A_JALR = 4'd7,
    A_BRANCH = 4'd8,
    A_ZBA = 4'd9,
    A_ZBA_UW = 4'd10
  } alu_op_t;

  // Keep the packet typed end-to-end so adding a control bit cannot silently
  // truncate a fixed-width decode port. EX valid owns observability; this
  // packet has no reset or validity field.
  typedef struct packed {
    logic is_lui;
    logic is_auipc;
    logic is_jal;
    logic is_jalr;
    logic is_branch;
    logic is_load;
    logic is_store;
    logic is_fp_load;
    logic is_fp_store;
    logic is_fp_compute;
    logic is_muldiv;
    logic is_cycle;
    logic is_instret;
    logic is_hardware_id;
    logic is_icache_header_csr;
    logic is_dcache_header_csr;
    logic is_fp_csr;
    logic is_edge_break;
    logic is_edge_putchar;
    logic is_edge_cache;
    logic is_fast_class;
    logic is_int_mem;
    logic is_fp_mem;
    logic is_fence_i;
    logic is_supported_system;
    logic is_accel;
    logic csr_fflags;
    logic csr_frm;
    logic csr_write;
    logic cache_is_va;
    logic [1:0] cache_kind;
    logic [2:0] funct3;
    logic funct7_bit5;
    logic [4:0] shamt;
    logic [4:0] csr_uimm;
    logic [4:0] write_rd;
    alu_op_t alu_op;
    logic writes_gpr;
    logic writes_fpr;
  } issue_control_t;
endpackage

// Fixed 32-bit instruction-family and ASIC command property classifier.
module edge_instruction_classifier (
  input  wire [31:0] inst,
  output wire [3:0]  op_class,
  output reg         legal,
  output wire [4:0]  rd,
  output wire [4:0]  rs1,
  output wire [4:0]  rs2,
  output reg  [2:0]  scalar_issue_class,
  output reg         writes_gpr,
  output wire        is_accel,
  output wire        accel_is_tensor,
  output wire [6:0]  accel_subop,
  output reg         accel_needs_capture,
  output reg  [4:0]  accel_capture_src_gpr,
  output reg         accel_needs_base_gpr,
  output reg  [4:0]  accel_base_src_gpr,
  output reg         accel_is_sync,
  output reg         accel_is_getcsr
);
  rv32::instruction_class_t instruction_class;
  assign op_class = instruction_class;
  localparam [2:0] SCALAR_OTHER=0, SCALAR_LOAD=1, SCALAR_STORE=2,
    SCALAR_ALU=3, SCALAR_M=4;

  wire [6:0] opcode=inst[6:0];
  wire [2:0] funct3=inst[14:12];
  wire [6:0] funct7=inst[31:25];
  assign rd=inst[11:7]; assign rs1=inst[19:15]; assign rs2=inst[24:20];
  assign is_accel=(opcode==rv32::OPCODE_EDGE_ASIC);
  assign accel_is_tensor=is_accel;
  assign accel_subop=inst[31:25];

  wire zba_op=(opcode==rv32::OPCODE_OP)&&(funct7==7'b0010000)&&
    ((funct3==2)||(funct3==4)||(funct3==6));
  wire zba_uw=(opcode==rv32::OPCODE_OP_32)&&
    (((funct7==7'b0000100)&&(funct3==0))||
     ((funct7==7'b0010000)&&((funct3==2)||(funct3==4)||(funct3==6))));
  wire slli_uw=(opcode==rv32::OPCODE_OP_IMM_32)&&(funct3==1)&&(inst[31:26]==6'b000010);
  wire legal_op_imm=(opcode==rv32::OPCODE_OP_IMM)&&
    (((funct3!=1)&&(funct3!=5))||
     ((funct3==1)&&(inst[31:26]==0))||
     ((funct3==5)&&((inst[31:26]==0)||(inst[31:26]==6'b010000))));
  wire legal_op=(opcode==rv32::OPCODE_OP)&&(zba_op||(funct7==0)||(funct7==1)||
    ((funct7==7'b0100000)&&((funct3==0)||(funct3==5))));
  wire legal_op_imm32=(opcode==rv32::OPCODE_OP_IMM_32)&&((funct3==0)||slli_uw||
    ((funct3==1)&&(funct7==0))||
    ((funct3==5)&&((funct7==0)||(funct7==7'b0100000))));
  wire legal_op32=(opcode==rv32::OPCODE_OP_32)&&(zba_uw||
    ((funct3==0)&&((funct7==0)||(funct7==1)||(funct7==7'b0100000)))||
    ((funct7==1)&&(funct3>=4))||((funct3==1)&&(funct7==0))||
    ((funct3==5)&&((funct7==0)||(funct7==7'b0100000))));
  wire legal_branch=(opcode==rv32::OPCODE_BRANCH)&&(funct3!=2)&&(funct3!=3);
  wire legal_load=(opcode==rv32::OPCODE_LOAD)&&(funct3!=7);
  wire legal_store=(opcode==rv32::OPCODE_STORE)&&(funct3<=3);
  wire legal_fp_mem=((opcode==rv32::OPCODE_LOAD_FP)||(opcode==rv32::OPCODE_STORE_FP))&&
    ((funct3==1)||(funct3==2)||(funct3==3)||(funct3>=5));
  wire fp_opcode=(opcode==rv32::OPCODE_MADD)||(opcode==rv32::OPCODE_MSUB)||(opcode==rv32::OPCODE_NMSUB)||
    (opcode==rv32::OPCODE_NMADD)||(opcode==rv32::OPCODE_OP_FP);
  wire legal_cache=(opcode==rv32::OPCODE_EDGE_CACHE)&&(funct7==0)&&(rd==0)&&
    (((funct3==0)&&(rs1==0)&&((rs2==1)||(rs2==2)||(rs2==3)))||
     ((funct3==1)&&((rs2==5)||(rs2==6)||(rs2==7))));
  wire legal_dma32=(opcode==rv32::OPCODE_EDGE_DMA)&&(funct3==0)&&
    ((funct7==0)||((funct7==1)&&(rd==0)&&(rs1==0)&&(rs2==0)));
  wire scalar_m=((opcode==rv32::OPCODE_OP)||(opcode==rv32::OPCODE_OP_32))&&(funct7==1);

  function tensor_subop_allocated;
    input [6:0] subop;
    begin
      case(subop)
        rv32::ASIC_DMA_START, rv32::ASIC_DMA_SYNC,
        rv32::ASIC_DMA_SETN, rv32::ASIC_DMA_SETX,
        rv32::ASIC_DMA_SETY, rv32::ASIC_DMA_SETSRC,
        rv32::ASIC_DMA_SETTAR, rv32::ASIC_DMA_SETENTRY,
        rv32::ASIC_DMA_SETCSR,
        rv32::ASIC_POWER, rv32::ASIC_TENSOR_SETCSR,
        rv32::ASIC_TENSOR_WLD, rv32::ASIC_TENSOR_SETIN,
        rv32::ASIC_TENSOR_SETOUT, rv32::ASIC_TENSOR_SETPSUM,
        rv32::ASIC_TENSOR_START, rv32::ASIC_TENSOR_SYNC,
        rv32::ASIC_TENSOR_SETN, rv32::ASIC_TENSOR_WLD_T,
        rv32::ASIC_TENSOR_START_TILE, rv32::ASIC_TENSOR_SLD_STREAM,
        rv32::ASIC_TENSOR_WLD_CIRCULAR, rv32::ASIC_TENSOR_WLD_T_CIRCULAR,
        rv32::ASIC_TENSOR_SLD, rv32::ASIC_TENSOR_WSLD_CIRCULAR,
        rv32::ASIC_TENSOR_SLD_CIRCULAR, rv32::ASIC_ACTU_SETCSR,
        rv32::ASIC_ACTU_SETIN, rv32::ASIC_ACTU_SETOUT,
        rv32::ASIC_ACTU_SETN, rv32::ASIC_ACTU_SETSCALAR,
        rv32::ASIC_ACTU_START, rv32::ASIC_ACTU_SYNC,
        rv32::ASIC_CMPU_SETCSR, rv32::ASIC_CMPU_SETLHS,
        rv32::ASIC_CMPU_SETRHS, rv32::ASIC_CMPU_SETMASK,
        rv32::ASIC_CMPU_SETOUT, rv32::ASIC_CMPU_SETN,
        rv32::ASIC_CMPU_START, rv32::ASIC_CMPU_SYNC,
        rv32::ASIC_GETCSR:
          tensor_subop_allocated=1'b1;
        default: tensor_subop_allocated=1'b0;
      endcase
    end
  endfunction

  function tensor_subop_needs_capture;
    input [6:0] subop;
    begin
      case(subop)
        rv32::ASIC_DMA_START, rv32::ASIC_DMA_SETN,
        rv32::ASIC_DMA_SETX, rv32::ASIC_DMA_SETY,
        rv32::ASIC_DMA_SETSRC, rv32::ASIC_DMA_SETTAR,
        rv32::ASIC_DMA_SETENTRY, rv32::ASIC_DMA_SETCSR,
        rv32::ASIC_TENSOR_WLD,
        rv32::ASIC_TENSOR_SETIN, rv32::ASIC_TENSOR_SETOUT,
        rv32::ASIC_TENSOR_SETPSUM, rv32::ASIC_TENSOR_SETN,
        rv32::ASIC_TENSOR_WLD_T, rv32::ASIC_TENSOR_SLD_STREAM,
        rv32::ASIC_TENSOR_SLD, rv32::ASIC_ACTU_SETIN,
        rv32::ASIC_ACTU_SETOUT, rv32::ASIC_ACTU_SETN,
        rv32::ASIC_ACTU_SETSCALAR, rv32::ASIC_CMPU_SETLHS,
        rv32::ASIC_CMPU_SETRHS, rv32::ASIC_CMPU_SETMASK,
        rv32::ASIC_CMPU_SETOUT, rv32::ASIC_CMPU_SETN:
          tensor_subop_needs_capture=1'b1;
        default: tensor_subop_needs_capture=1'b0;
      endcase
    end
  endfunction

  always_comb begin
    instruction_class=rv32::CLASS_ILLEGAL; legal=1'b1; scalar_issue_class=SCALAR_OTHER;
    writes_gpr=1'b0;
    accel_needs_capture=1'b0; accel_capture_src_gpr=5'd0;
    accel_needs_base_gpr=1'b0; accel_base_src_gpr=rs1;
    accel_is_sync=1'b0; accel_is_getcsr=1'b0;
    if(is_accel) begin
      instruction_class=rv32::CLASS_ACCEL;
      legal=tensor_subop_allocated(accel_subop);
      accel_needs_capture=tensor_subop_needs_capture(accel_subop);
      accel_capture_src_gpr=rs1;
      accel_needs_base_gpr=1'b0;
      accel_base_src_gpr=rs1;
      accel_is_sync=
        ((accel_subop==rv32::ASIC_DMA_SYNC)||(accel_subop==rv32::ASIC_TENSOR_SYNC)||
         (accel_subop==rv32::ASIC_ACTU_SYNC)||(accel_subop==rv32::ASIC_CMPU_SYNC));
      accel_is_getcsr=(accel_subop==rv32::ASIC_GETCSR);
      // GETCSR returns through the accelerator response path and writes rd.
      writes_gpr=accel_is_getcsr && (rd!=0);
    end else if(legal_op||legal_op_imm||legal_op32||legal_op_imm32||
            (opcode==rv32::OPCODE_LUI)||(opcode==rv32::OPCODE_AUIPC)) begin
      instruction_class=scalar_m?rv32::CLASS_MULDIV:rv32::CLASS_ALU;
      scalar_issue_class=scalar_m?SCALAR_M:SCALAR_ALU;
      writes_gpr=rd!=0;
    end else if((opcode==rv32::OPCODE_JAL)||((opcode==rv32::OPCODE_JALR)&&(funct3==0))||
                legal_branch) begin
      instruction_class=rv32::CLASS_BRANCH;
      writes_gpr=((opcode==rv32::OPCODE_JAL)||(opcode==rv32::OPCODE_JALR))&&(rd!=0);
    end else if(legal_load) begin
      instruction_class=rv32::CLASS_LOAD; scalar_issue_class=SCALAR_LOAD; writes_gpr=rd!=0;
    end else if(legal_store) begin
      instruction_class=rv32::CLASS_STORE; scalar_issue_class=SCALAR_STORE;
    end else if(legal_fp_mem||fp_opcode) instruction_class=rv32::CLASS_FPU;
    else if((opcode==rv32::OPCODE_SYSTEM)||((opcode==rv32::OPCODE_MISC_MEM)&&(funct3<=1))) begin
      instruction_class=rv32::CLASS_SYSTEM;
      writes_gpr=(opcode==rv32::OPCODE_SYSTEM)&&(funct3!=0)&&(rd!=0);
    end else if(legal_cache||legal_dma32) instruction_class=rv32::CLASS_CUSTOM;
    else legal=1'b0;
  end
endmodule

`endif
