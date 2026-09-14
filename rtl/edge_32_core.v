`timescale 1ns/1ps
// Bootable RV32IM_Zba three-stage core. Variable-latency EX freezes IF/ID.
module edge_32_core #(
  parameter PC_WIDTH = 32,
  parameter DMEM_RESP_FORMATTED = 0,
  parameter ENABLE_FPU = 0,
  parameter MULDIV_ASAP7 = 0,
  parameter AUTO_START = 1,
  parameter [46:0] EDGE_ASIC_ID = 47'd0
) (
  input wire clk, input wire reset_n,
  input wire [PC_WIDTH-1:0] boot_pc,
  input wire core_start,input wire core_force_stop,
  output wire [31:0] icache_address_header,
  output wire [31:0] dcache_address_header,
  output wire imem_req_valid, input wire imem_req_ready,
  output wire [PC_WIDTH-1:0] imem_req_addr,
  input wire imem_resp_valid, input wire [31:0] imem_resp_data,
  input wire imem_resp_error,
  output wire dmem_req_valid, input wire dmem_req_ready,
  output wire dmem_req_write, output wire [63:0] dmem_req_addr,
  output wire [63:0] dmem_req_wdata, output wire [7:0] dmem_req_wstrb,
  output wire [1:0] dmem_req_size, output wire dmem_req_signed,
  input wire dmem_resp_valid, input wire dmem_resp_error,
  input wire [63:0] dmem_resp_rdata,
  output wire cache_op_valid,input wire cache_op_ready,
  output wire cache_op_is_va,output wire [1:0] cache_op_kind,
  output wire [63:0] cache_op_addr,
  input wire cache_op_complete_valid,
  output wire icache_invalidate_valid,input wire icache_invalidate_ready,
  input wire icache_invalidate_complete,
  output wire accel_req_valid, input wire accel_req_ready,
  output wire [31:0] accel_req_inst,
  output wire [63:0] accel_req_src0, output wire [63:0] accel_req_src1,
  input wire accel_resp_valid, input wire accel_resp_error,
  input wire [63:0] accel_resp_value,
  output reg halted, output reg illegal,
  output wire [63:0] debug_x31, output wire [63:0] cycle_count,
  output wire [63:0] instret_count
);
  reg [31:0] gpr [0:31];
  reg [63:0] cycle_q, instret_q;
  reg [4:0] fflags_q;
  reg [2:0] frm_q;
  reg mem_started_q, mul_started_q, fpu_started_q, accel_started_q;
  reg cache_started_q, icache_invalidate_started_q;
  integer ri;
  wire core_start_i = AUTO_START ? 1'b0 : core_start;
  wire core_force_stop_i = AUTO_START ? 1'b0 : core_force_stop;

  wire parcel_valid, parcel_ready, parcel_error;
  wire [PC_WIDTH-1:0] parcel_pc; wire [31:0] parcel_inst;
  wire if_valid, if_ready, if_error, if_is_64b;
  wire [PC_WIDTH-1:0] if_pc; wire [63:0] if_inst;
  wire id_is_64b;
  wire [63:0] id_inst;
  wire ex_valid, ex_error, ex_is_64b;
  wire [PC_WIDTH-1:0] ex_pc; wire [63:0] ex_inst;
  wire [31:0] ex_rs1_value, ex_rs2_value;
  wire id_capture_enable;
  wire [31:0] id_fsrc0, id_fsrc1, id_fsrc2;
  reg [31:0] ex_fsrc0_q, ex_fsrc1_q, ex_fsrc2_q;
  wire [31:0] id_fpu_control;
  reg [31:0] ex_fpu_control_q;
  edge_fpu_id_decode #(.GPR_WIDTH(32)) id_fp_decode(
    .inst(id_inst[31:0]),.frm(frm_q),.control(id_fpu_control));
  // Same ID->EX advance/stall/flush boundary as GPR operands. EX valid owns
  // observability; these numerical payload registers do not need reset.
  always @(posedge clk) begin
    if (id_capture_enable) begin
      ex_fpu_control_q <= id_fpu_control;
      ex_fsrc0_q <= id_fsrc0;
      ex_fsrc1_q <= id_fsrc1;
      ex_fsrc2_q <= id_fsrc2;
    end
  end
  wire [3:0] id_decoded_class;
  wire id_decoded_legal;
  wire id_decoded_writes_gpr;
  wire id_decoded_needs_capture;
  wire [4:0] id_decoded_capture_src_gpr;
  edge_32_decode id_decode(
    .inst(id_inst), .inst_is_64b(id_is_64b), .op_class(id_decoded_class),
    .legal(id_decoded_legal), .rd(), .rs1(), .rs2(),
    .writes_gpr(id_decoded_writes_gpr), .accel_subop(),
    .accel_needs_capture(id_decoded_needs_capture),
    .accel_capture_src_gpr(id_decoded_capture_src_gpr));
  // CSRRW[I] always writes, including x0/uimm=0. CSRRS/CSRRC[I] write
  // only for a nonzero encoded source (not a nonzero register value).
  wire id_csr_write=!id_is_64b && (id_inst[6:0]==7'h73) &&
    (id_inst[13:12]!=2'b00) &&
    ((id_inst[13:12]==2'b01)||(id_inst[19:15]!=5'd0));
  wire [4:0] id_rs1, id_rs2;
  wire [31:0] id_rs1_raw=id_rs1==0 ? 0 : gpr[id_rs1];
  wire [31:0] id_rs2_raw=id_rs2==0 ? 0 : gpr[id_rs2];
  wire decoded_legal;

  wire is_lui;
  wire is_auipc;
  wire is_jal;
  wire is_jalr;
  wire is_branch;
  wire is_load;
  wire is_store;
  wire is_fp_load;
  wire is_fp_store;
  wire is_fp_compute;
  wire is_muldiv;
  wire is_cycle;
  wire is_instret;
  wire is_hardware_id;
  wire is_icache_header_csr;
  wire is_dcache_header_csr;
  wire is_fp_csr;
  wire is_ebreak;
  wire is_edge_break;
  wire is_edge_cache;
  wire is_fast_class;
  wire is_int_mem;
  wire is_fp_mem;
  wire is_fence_i;
  wire is_supported_system;
  wire is_accel;
  wire csr_fflags;
  wire csr_frm;
  wire csr_write;
  wire cache_is_va;
  wire [1:0] cache_kind;
  wire [2:0] f3;
  wire funct7_bit5;
  wire [4:0] shamt;
  wire [4:0] csr_uimm;
  wire [4:0] rd;
  wire [3:0] alu_op;
  wire ex_writes_gpr;
  wire ex_writes_fpr;
  wire [56:0] id_issue_control;
  reg [56:0] ex_issue_control_q;
  wire [31:0] id_alu_imm, id_mem_imm, id_branch_imm, id_jump_imm;
  reg [31:0] ex_alu_imm_q, ex_mem_imm_q, ex_branch_imm_q, ex_jump_imm_q;
  wire id_issue_legal, id_writes_gpr, id_writes_fpr;
  wire [4:0] id_write_rd;
  wire [1:0] id_uses_gpr;
  wire [2:0] id_uses_fpr;
  wire [4:0] id_frs0, id_frs1, id_frs2;
  edge_32_issue_decode #(.ENABLE_FPU(ENABLE_FPU)) id_issue_decode(
    .inst(id_inst),.op_class(id_decoded_class),.decoded_legal(id_decoded_legal),
    .decoded_writes_gpr(id_decoded_writes_gpr),
    .accel_needs_capture(id_decoded_needs_capture),
    .accel_capture_src_gpr(id_decoded_capture_src_gpr),.fpu_control(id_fpu_control),
    .control(id_issue_control),.alu_imm(id_alu_imm),.mem_imm(id_mem_imm),
    .branch_imm(id_branch_imm),.jump_imm(id_jump_imm),
    .read_gpr0(id_rs1),.read_gpr1(id_rs2),
    .read_fpr0(id_frs0),.read_fpr1(id_frs1),.read_fpr2(id_frs2),
    .uses_gpr(id_uses_gpr),.uses_fpr(id_uses_fpr),
    .write_rd(id_write_rd),.writes_gpr(id_writes_gpr),.writes_fpr(id_writes_fpr),
    .issue_legal(id_issue_legal));
  assign {is_lui,is_auipc,is_jal,is_jalr,is_branch,is_load,
    is_store,is_fp_load,is_fp_store,is_fp_compute,is_muldiv,is_cycle,
    is_instret,is_hardware_id,is_icache_header_csr,is_dcache_header_csr,is_fp_csr,is_ebreak,
    is_edge_break,is_edge_cache,is_fast_class,is_int_mem,is_fp_mem,is_fence_i,
    is_supported_system,is_accel,csr_fflags,csr_frm,csr_write,cache_is_va,
    cache_kind,f3,funct7_bit5,shamt,csr_uimm,rd,
    alu_op,ex_writes_gpr,ex_writes_fpr}=ex_issue_control_q;
  always @(posedge clk) begin
    if(id_capture_enable) begin
      ex_issue_control_q<=id_issue_control;
      ex_alu_imm_q<=id_alu_imm; ex_mem_imm_q<=id_mem_imm;
      ex_branch_imm_q<=id_branch_imm; ex_jump_imm_q<=id_jump_imm;
    end
  end
  wire is_address_header_csr=is_icache_header_csr||is_dcache_header_csr;
  wire fpu_legal;
  wire ex_legal=decoded_legal;
  wire ex_issue_ok=ex_valid&&!halted&&!ex_error&&ex_legal&&
                   !core_start_i&&!core_force_stop_i;
  wire [31:0] fast_result;
  edge_32_alu #(.PC_WIDTH(PC_WIDTH)) fast_alu(
    .fast_issue_op(alu_op),.fast_issue_pc(ex_pc),
    .fast_issue_src0_value(ex_rs1_value),
    .fast_issue_src1_value(ex_rs2_value),
    .fast_issue_imm(ex_alu_imm_q),
    .fast_issue_funct3(f3),
    .fast_issue_funct7_bit5(funct7_bit5),.fast_issue_funct7_is_m(1'b0),
    .fast_issue_shamt(shamt),
    .fast_result(fast_result));
  wire branch_taken; wire [PC_WIDTH-1:0] branch_target;
  edge_32_branch #(.PC_WIDTH(PC_WIDTH)) branch(
    .branch_issue_op(alu_op),.branch_issue_pc(ex_pc),
    .branch_issue_src0_value(ex_rs1_value),
    .branch_issue_src1_value(ex_rs2_value),
    .branch_issue_imm(ex_mem_imm_q),.branch_issue_branch_imm(ex_branch_imm_q),
    .branch_issue_jal_imm(ex_jump_imm_q),.branch_issue_funct3(f3),
    .branch_taken(branch_taken),.branch_target(branch_target));

  wire mul_ready,mul_result_valid; wire [31:0] mul_result;
  wire mul_start=ex_issue_ok&&is_muldiv&&!mul_started_q;
  generate if (MULDIV_ASAP7) begin: g_muldiv_asap7
  edge_32_muldiv_asap7 muldiv(.clk(clk),.reset_n(reset_n),
    .op_valid(mul_start),.op_ready(mul_ready),
    .src0(ex_rs1_value),.src1(ex_rs2_value),.funct3(f3),
    .result_valid(mul_result_valid),.result_value(mul_result),.busy(),
    .op_latency());
  end else begin: g_muldiv_portable
  edge_32_muldiv muldiv(.clk(clk),.reset_n(reset_n),
    .op_valid(mul_start),.op_ready(mul_ready),
    .src0(ex_rs1_value),.src1(ex_rs2_value),.funct3(f3),
    .result_valid(mul_result_valid),.result_value(mul_result),.busy(),
    .op_latency());
  end endgenerate

  wire lsu_ready,lsu_done,lsu_error; wire [31:0] lsu_value;
  wire [31:0] lsu_mem_addr;
  wire lsu_start=ex_issue_ok&&(is_int_mem||is_fp_mem)&&!mem_started_q;
  wire [31:0] fpu_store_value;
  wire [31:0] fp_load_value;
  wire [63:0] fp_store_value;
  edge_32_fp_mem_format fp_mem_format(
    .funct3(f3),.load_value({32'd0,lsu_value}),.store_fp32(fpu_store_value),
    .load_fp32(fp_load_value),.store_value(fp_store_value));
  edge_32_lsu #(.MEM_RESP_FORMATTED(DMEM_RESP_FORMATTED)) lsu(
    .clk(clk),.reset_n(reset_n),.op_valid(lsu_start),
    .op_ready(lsu_ready),.op_store(is_store||is_fp_store),
    .op_fp(is_fp_load||is_fp_store),.op_funct3(f3),
    .op_base(ex_rs1_value),
    .op_offset(ex_mem_imm_q),
    .op_store_data(is_fp_store?fp_store_value[31:0]:ex_rs2_value),
    .mem_req_valid(dmem_req_valid),
    .mem_req_ready(dmem_req_ready),.mem_req_write(dmem_req_write),
    .mem_req_addr(lsu_mem_addr),.mem_req_wdata(dmem_req_wdata),
    .mem_req_wstrb(dmem_req_wstrb),.mem_req_size(dmem_req_size),
    .mem_req_signed(dmem_req_signed),.mem_resp_valid(dmem_resp_valid),
    .mem_resp_error(dmem_resp_error),.mem_resp_rdata(dmem_resp_rdata),
    .op_done(lsu_done),.op_error(lsu_error),.op_load_value(lsu_value),.busy());
  assign dmem_req_addr={32'd0,lsu_mem_addr};

  wire fpu_ready, fpu_done, fpu_gpr_write, fpr_load_ready;
  wire [31:0] fpu_value; wire [4:0] fpu_fflags;
  generate if(ENABLE_FPU) begin: g_fpu
    edge_fpu_alu #(.GPR_WIDTH(32),.PREDECODED(1)) fpu_alu(
      .clk(clk),.reset_n(reset_n),
      .cancel(core_start_i||core_force_stop_i),
      .issue_valid(ex_issue_ok&&is_fp_compute&&!fpu_started_q),
      .issue_ready(fpu_ready),.issue_inst(32'b0),.issue_control(ex_fpu_control_q),
      .issue_gpr_src(ex_rs1_value),.issue_frm(3'b0),
      .issue_fsrc0(ex_fsrc0_q),.issue_fsrc1(ex_fsrc1_q),.issue_fsrc2(ex_fsrc2_q),
      .read_frs0(id_frs0),.read_frs1(id_frs1),.read_frs2(id_frs2),
      .read_fsrc0(id_fsrc0),.read_fsrc1(id_fsrc1),.read_fsrc2(id_fsrc2),
      .issue_legal(fpu_legal),
      .complete_valid(fpu_done),.complete_gpr_write(fpu_gpr_write),
      .complete_rd(),.complete_value(fpu_value),
      .complete_fflags(fpu_fflags),
      .load_write_valid(ex_issue_ok&&is_fp_load&&lsu_done&&!lsu_error),
      .load_write_ready(fpr_load_ready),.load_write_rd(rd),.load_write_value(fp_load_value),
      .store_read_rs(5'd0),.store_read_value());
    assign fpu_store_value=ex_fsrc1_q;
  end else begin: g_no_fpu
    assign id_fsrc0=0; assign id_fsrc1=0; assign id_fsrc2=0;
    assign fpr_load_ready=1'b0;
    assign fpu_ready=1'b0; assign fpu_done=1'b0;
    assign fpu_gpr_write=1'b0;
    assign fpu_value=32'b0; assign fpu_fflags=5'b0;
    assign fpu_legal=1'b0; assign fpu_store_value=32'b0;
  end endgenerate
  wire fpu_start=ex_issue_ok&&is_fp_compute&&!fpu_started_q&&fpu_ready;

  assign accel_req_valid=ex_issue_ok&&is_accel&&!accel_started_q;
  assign accel_req_inst=ex_inst[31:0];
  assign accel_req_src0={32'd0,ex_rs1_value};
  assign accel_req_src1={32'd0,ex_rs2_value};
  wire accel_req_fire=accel_req_valid&&accel_req_ready;
  wire accel_done=is_accel&&accel_started_q&&accel_resp_valid;
  assign cache_op_valid=ex_issue_ok&&is_edge_cache&&!cache_started_q;
  assign cache_op_is_va=cache_is_va;
  assign cache_op_kind=cache_kind;
  assign cache_op_addr={32'd0,ex_rs1_value};
  wire cache_req_fire=cache_op_valid&&cache_op_ready;
  wire cache_done=is_edge_cache&&cache_started_q&&cache_op_complete_valid;
  assign icache_invalidate_valid=
    ex_issue_ok&&is_fence_i&&!icache_invalidate_started_q;
  wire icache_invalidate_fire=
    icache_invalidate_valid&&icache_invalidate_ready;
  wire fence_i_done=is_fence_i&&icache_invalidate_started_q&&
    icache_invalidate_complete;
  wire fast_done=ex_issue_ok&&is_fast_class;
  wire sys_done=ex_issue_ok&&is_supported_system&&!is_fence_i;
  wire ex_done=ex_valid&&!halted&&!core_start_i&&!core_force_stop_i&&
    (fast_done||sys_done||(is_muldiv&&mul_started_q&&mul_result_valid)||
     ((is_int_mem||is_fp_mem)&&mem_started_q&&lsu_done)||
     (is_fp_compute&&fpu_started_q&&fpu_done)||
     accel_done||cache_done||fence_i_done||ex_error||!ex_legal);
  wire ex_faulting=ex_error||!ex_legal||
    ((is_int_mem||is_fp_mem)&&lsu_done&&lsu_error)||
    (is_accel&&accel_done&&accel_resp_error);
  wire terminal_complete=ex_done&&
    (ex_faulting||is_ebreak||is_edge_break);
  wire frontend_stop=halted||terminal_complete;
  wire ex_control=is_jal||is_jalr||is_branch;
  wire branch_redirect=fast_done&&ex_control&&branch_taken;
  wire redirect=branch_redirect||fence_i_done;
  wire [PC_WIDTH-1:0] redirect_pc=fence_i_done ?
    ex_pc+{{(PC_WIDTH-3){1'b0}},3'd4}:branch_target;
  reg [31:0] icache_address_header_q,dcache_address_header_q;
  assign icache_address_header=icache_address_header_q;
  assign dcache_address_header=dcache_address_header_q;
  wire [31:0] address_header_old=is_icache_header_csr?
    icache_address_header_q:dcache_address_header_q;
  wire [31:0] address_header_source=f3[2]?{27'd0,csr_uimm}:
                                            ex_rs1_value;
  wire [31:0] address_header_new=(f3[1:0]==2'b01)?address_header_source:
    (f3[1:0]==2'b10)?(address_header_old|address_header_source):
                       (address_header_old&~address_header_source);
  wire address_header_write=csr_write;
  wire [31:0] wb_value=is_edge_break?ex_rs1_value:is_accel?accel_resp_value[31:0]:
    is_fp_compute?fpu_value:is_muldiv?mul_result:
    is_load?lsu_value[31:0]:is_cycle?cycle_q[31:0]:
    is_instret?instret_q[31:0]:is_fp_csr?
    (csr_fflags ? {27'd0,fflags_q} :
     csr_frm ? {29'd0,frm_q} : {24'd0,frm_q,fflags_q}):
    is_hardware_id?EDGE_ASIC_ID[31:0]:
    is_address_header_csr?address_header_old:fast_result;
  wire [31:0] fp_csr_source=f3[2]?{27'd0,csr_uimm}:ex_rs1_value;
  wire [7:0] fp_csr_old=(csr_fflags)?
                        {3'd0,fflags_q}:
                        (csr_frm)?
                        {5'd0,frm_q}:{frm_q,fflags_q};
  wire [7:0] fp_csr_new=(f3[1:0]==2'b01)?fp_csr_source[7:0]:
                         (f3[1:0]==2'b10)?
                         (fp_csr_old|fp_csr_source[7:0]):
                         (fp_csr_old&~fp_csr_source[7:0]);
  wire fp_csr_write=csr_write;
  // One architectural GPR write port. Edge break uses the same port at x31.
  wire wb_valid=ex_valid&&ex_done&&!halted&&!ex_faulting&&ex_writes_gpr&&
                !core_start_i&&!core_force_stop_i;


  edge_32_frontend #(.PC_WIDTH(PC_WIDTH),.AUTO_START(AUTO_START)) frontend(
    .clk(clk),.reset_n(reset_n),.boot_pc(boot_pc),
    .fetch_start(core_start_i),.fetch_stop(core_force_stop_i),
    .imem_req_valid(imem_req_valid),.imem_req_ready(imem_req_ready),
    .imem_req_addr(imem_req_addr),.imem_resp_valid(imem_resp_valid),
    .imem_resp_data(imem_resp_data),.imem_resp_error(imem_resp_error),
    .op_valid(parcel_valid),.op_ready(parcel_ready),.op_pc(parcel_pc),
    .op_inst(parcel_inst), .op_error(parcel_error), .halt(frontend_stop),
    .redirect_valid(redirect),.redirect_pc(redirect_pc));
  edge_32_instruction_assembler assembler(
    .clk(clk), .reset_n(reset_n), .parcel_valid(parcel_valid),
    .parcel_ready(parcel_ready), .parcel_pc(parcel_pc),
    .parcel_data(parcel_inst), .parcel_error(parcel_error),
    .op_valid(if_valid), .op_ready(if_ready), .op_pc(if_pc),
    .op_inst(if_inst), .op_is_64b(if_is_64b), .op_error(if_error),
    .flush(redirect||frontend_stop||core_start_i||core_force_stop_i));
  edge_32_pipeline #(.PC_WIDTH(PC_WIDTH),.VALUE_WIDTH(32)) pipeline(
    .clk(clk),.reset_n(reset_n),
    .fetch_valid(if_valid),.fetch_ready(if_ready),.fetch_pc(if_pc),
    .fetch_inst(if_inst),.fetch_is_64b(if_is_64b),.fetch_error(if_error),
    .id_valid(),.id_capture_enable(id_capture_enable),.id_pc(), .id_inst(id_inst),
    .id_is_64b(id_is_64b),.id_error(),.id_rs1(id_rs1),.id_rs2(id_rs2),
    .id_rs1_raw(id_rs1_raw),.id_rs2_raw(id_rs2_raw),.ex_valid(ex_valid),
    .id_op_class(id_decoded_class),.id_legal(id_issue_legal),
    .id_writes_gpr(id_writes_gpr),.id_csr_write(id_csr_write),
    .ex_pc(ex_pc),.ex_inst(ex_inst),.ex_is_64b(ex_is_64b),.ex_error(ex_error),
    .ex_rs1_value(ex_rs1_value),.ex_rs2_value(ex_rs2_value),.ex_done(ex_done),
    .ex_op_class(),.ex_legal(decoded_legal),
    .ex_writes_gpr(),
    .ex_write_valid(wb_valid),.ex_write_rd(rd),.ex_write_value(wb_value),
    .ex_redirect_valid(redirect||terminal_complete||halted||core_start_i||
                       core_force_stop_i));

  assign debug_x31={32'd0,gpr[31]};
  assign cycle_count=cycle_q; assign instret_count=instret_q;
  always @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
      for(ri=0;ri<32;ri=ri+1) gpr[ri]<=0;
      cycle_q<=0; instret_q<=0; mem_started_q<=0; mul_started_q<=0;
      fflags_q<=0; frm_q<=0;
      icache_address_header_q<=0; dcache_address_header_q<=0;
      fpu_started_q<=0;
      accel_started_q<=0; cache_started_q<=0;
      icache_invalidate_started_q<=0;
      halted<=0; illegal<=0;
    end else begin
      cycle_q<=cycle_q+1;
      if(core_start_i) begin halted<=0; illegal<=0; end
      if(core_start_i||core_force_stop_i) begin
        mem_started_q<=0; mul_started_q<=0; fpu_started_q<=0;
        accel_started_q<=0; cache_started_q<=0;
        icache_invalidate_started_q<=0;
      end
      if(lsu_start&&lsu_ready) mem_started_q<=1;
      if(mul_start&&mul_ready) mul_started_q<=1;
      if(fpu_start) fpu_started_q<=1;
      if(accel_req_fire) accel_started_q<=1;
      if(cache_req_fire) cache_started_q<=1;
      if(icache_invalidate_fire) icache_invalidate_started_q<=1;
      if(ex_done&&!halted&&!core_start_i&&!core_force_stop_i) begin
        mem_started_q<=0; mul_started_q<=0; fpu_started_q<=0; accel_started_q<=0;
        cache_started_q<=0;
        icache_invalidate_started_q<=0;
        if(ex_valid&&!ex_faulting) instret_q<=instret_q+1;
        if(wb_valid) gpr[rd]<=wb_value;
        if(!ex_faulting&&is_fp_csr&&fp_csr_write) begin
          if(csr_fflags)
            fflags_q<=fp_csr_new[4:0];
          else if(csr_frm)
            frm_q<=fp_csr_new[2:0];
          else begin
            fflags_q<=fp_csr_new[4:0];
            frm_q<=fp_csr_new[7:5];
          end
        end
        if(!ex_faulting&&is_icache_header_csr&&address_header_write)
          icache_address_header_q<=address_header_new;
        if(!ex_faulting&&is_dcache_header_csr&&address_header_write)
          dcache_address_header_q<=address_header_new;
        if(!ex_faulting&&is_fp_compute&&fpu_done)
          fflags_q<=fflags_q|fpu_fflags;
        if(!ex_faulting&&(is_ebreak||is_edge_break)) halted<=1;
        if(ex_faulting) begin illegal<=1; halted<=1; end
      end
    end
  end
endmodule
