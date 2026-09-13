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
  localparam [3:0] A_IMM=0, A_OP=1, A_IMM32=2, A_OP32=3,
    A_LUI=4, A_AUIPC=5, A_JAL=6, A_JALR=7, A_BRANCH=8,
    A_ZBA=9, A_ZBA_UW=10;
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
  wire [4:0] id_scalar_rs1=id_inst[19:15], id_scalar_rs2=id_inst[24:20];
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
  wire id_is_accel=(id_inst[6:0]==7'h3f)&&(id_decoded_class==4'd8);
  wire [4:0] id_rs1=id_scalar_rs1;
  wire [4:0] id_rs2=id_is_accel ?
    (id_decoded_needs_capture ? id_decoded_capture_src_gpr:5'd0):id_scalar_rs2;
  wire [31:0] id_rs1_raw=id_rs1==0 ? 0 : gpr[id_rs1];
  wire [31:0] id_rs2_raw=id_rs2==0 ? 0 : gpr[id_rs2];
  wire [3:0] decoded_class;
  wire decoded_legal, decoded_writes_gpr;

  wire [6:0] opc=ex_inst[6:0]; wire [2:0] f3=ex_inst[14:12];
  wire [6:0] f7=ex_inst[31:25]; wire [4:0] rd=ex_inst[11:7];
  wire is_opimm=opc==7'h13, is_op=opc==7'h33;
  wire is_opimm32=opc==7'h1b, is_op32=opc==7'h3b;
  wire is_lui=opc==7'h37, is_auipc=opc==7'h17;
  wire is_jal=opc==7'h6f, is_jalr=(opc==7'h67)&&(f3==0);
  wire is_branch=opc==7'h63;
  wire is_load=opc==7'h03, is_store=opc==7'h23;
  wire is_fp_load=(decoded_class==4'd5)&&(opc==7'h07);
  wire is_fp_store=(decoded_class==4'd5)&&(opc==7'h27);
  wire is_fp_compute=(opc==7'h53)||(opc==7'h43)||(opc==7'h47)||
                     (opc==7'h4b)||(opc==7'h4f);
  wire is_muldiv=decoded_class==4'd4;
  wire is_zba=is_op&&(f7==7'b0010000)&&
    ((f3==2)||(f3==4)||(f3==6));
  wire is_zba_uw=is_op32&&(((f7==7'b0000100)&&(f3==0))||
    ((f7==7'b0010000)&&((f3==2)||(f3==4)||(f3==6))));
  wire is_slli_uw=is_opimm32&&(f3==1)&&(ex_inst[31:26]==6'b000010);
  wire is_cycle=(opc==7'h73)&&(f3==3'b010)&&(ex_inst[31:20]==12'hc00)&&
    (ex_inst[19:15]==0);
  wire is_instret=(opc==7'h73)&&(f3==3'b010)&&(ex_inst[31:20]==12'hc02)&&
    (ex_inst[19:15]==0);
  wire is_hardware_id=(opc==7'h73)&&(f3==3'b010)&&
    (ex_inst[31:20]==12'hfc0)&&(ex_inst[19:15]==0);
  wire is_csr_op=(opc==7'h73)&&(f3[1:0]!=2'b00);
  wire is_icache_header_csr=is_csr_op&&(ex_inst[31:20]==12'h7db);
  wire is_dcache_header_csr=is_csr_op&&(ex_inst[31:20]==12'h7dc);
  wire is_address_header_csr=is_icache_header_csr||is_dcache_header_csr;
  wire is_fp_csr=ENABLE_FPU&&is_csr_op&&
    ((ex_inst[31:20]==12'h001)||(ex_inst[31:20]==12'h002)||
     (ex_inst[31:20]==12'h003));
  wire is_ebreak=ex_inst==64'h0000_0000_0010_0073;
  wire is_edge_break=(opc==7'h73)&&(f3==3'b001)&&(rd==5'd0)&&
    (ex_inst[31:20]==12'h7e0);
  wire is_edge_cache=(decoded_class==4'd7)&&(opc==7'h0b);
  wire is_fast_class=(decoded_class==4'd0)||(decoded_class==4'd1);
  wire is_int_mem=(decoded_class==4'd2)||(decoded_class==4'd3);
  wire is_fp_mem=ENABLE_FPU&&(is_fp_load||is_fp_store);
  wire is_fence=(decoded_class==4'd6)&&(opc==7'h0f);
  wire is_fence_i=is_fence&&(f3==3'b001);
  wire is_supported_system=is_cycle||is_instret||is_hardware_id||
    is_address_header_csr||is_ebreak||is_edge_break||is_fp_csr||is_fence;
  wire is_accel=(ex_inst[6:0]==7'h3f)&&(decoded_class==4'd8);
  wire fpu_legal;
  wire ex_supported=is_accel||is_fast_class||is_muldiv||is_int_mem||is_fp_mem||
    is_supported_system||is_edge_cache||
    (ENABLE_FPU&&is_fp_compute&&fpu_legal);
  wire ex_legal=decoded_legal&&ex_supported;
  wire ex_issue_ok=ex_valid&&!halted&&!ex_error&&ex_legal;

  wire [11:0] i12=ex_inst[31:20];
  wire [11:0] s12={ex_inst[31:25],ex_inst[11:7]};
  wire [31:0] imm_i={{20{i12[11]}},i12};
  wire [31:0] imm_s={{20{s12[11]}},s12};
  wire [31:0] imm_u={ex_inst[31:12],12'b0};
  wire [31:0] imm_b={{19{ex_inst[31]}},ex_inst[31],ex_inst[7],
    ex_inst[30:25],ex_inst[11:8],1'b0};
  wire [31:0] imm_j={{11{ex_inst[31]}},ex_inst[31],ex_inst[19:12],
    ex_inst[20],ex_inst[30:21],1'b0};
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
  wire [31:0] fast_result;
  edge_32_alu #(.PC_WIDTH(PC_WIDTH)) fast_alu(
    .fast_issue_op(alu_op),.fast_issue_pc(ex_pc),
    .fast_issue_src0_value(ex_rs1_value),
    .fast_issue_src1_value(ex_rs2_value),
    .fast_issue_imm((is_lui||is_auipc)?imm_u:imm_i),
    .fast_issue_funct3(f3),
    .fast_issue_funct7_bit5(ex_inst[30]),.fast_issue_funct7_is_m(1'b0),
    .fast_issue_shamt(ex_inst[24:20]),
    .fast_result(fast_result));
  wire branch_taken; wire [PC_WIDTH-1:0] branch_target;
  edge_32_branch #(.PC_WIDTH(PC_WIDTH)) branch(
    .branch_issue_op(alu_op),.branch_issue_pc(ex_pc),
    .branch_issue_src0_value(ex_rs1_value),
    .branch_issue_src1_value(ex_rs2_value),
    .branch_issue_imm(imm_i),.branch_issue_branch_imm(imm_b),
    .branch_issue_jal_imm(imm_j),.branch_issue_funct3(f3),
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
    .op_offset((is_store||is_fp_store)?imm_s:imm_i),
    .op_store_data(is_fp_store?fp_store_value[31:0]:ex_rs2_value),
    .mem_req_valid(dmem_req_valid),
    .mem_req_ready(dmem_req_ready),.mem_req_write(dmem_req_write),
    .mem_req_addr(lsu_mem_addr),.mem_req_wdata(dmem_req_wdata),
    .mem_req_wstrb(dmem_req_wstrb),.mem_req_size(dmem_req_size),
    .mem_req_signed(dmem_req_signed),.mem_resp_valid(dmem_resp_valid),
    .mem_resp_error(dmem_resp_error),.mem_resp_rdata(dmem_resp_rdata),
    .op_done(lsu_done),.op_error(lsu_error),.op_load_value(lsu_value),.busy());
  assign dmem_req_addr={32'd0,lsu_mem_addr};

  wire fpu_ready, fpu_done, fpu_gpr_write;
  wire [63:0] fpu_value; wire [4:0] fpu_fflags;
  generate if(ENABLE_FPU) begin: g_fpu
    edge_fpu_alu #(.GPR_WIDTH(32)) fpu_alu(
      .clk(clk),.reset_n(reset_n),
      .issue_valid(ex_issue_ok&&is_fp_compute&&!fpu_started_q),
      .issue_ready(fpu_ready),.issue_inst(ex_inst[31:0]),
      .issue_gpr_src({32'd0,ex_rs1_value}),.issue_frm(frm_q),
      .issue_legal(fpu_legal),
      .complete_valid(fpu_done),.complete_gpr_write(fpu_gpr_write),
      .complete_rd(),.complete_value(fpu_value),
      .complete_fflags(fpu_fflags),
      .load_write_valid(ex_issue_ok&&is_fp_load&&lsu_done&&!lsu_error),
      .load_write_rd(rd),.load_write_value(fp_load_value),
      .store_read_rs(ex_inst[24:20]),.store_read_value(fpu_store_value));
  end else begin: g_no_fpu
    assign fpu_ready=1'b0; assign fpu_done=1'b0;
    assign fpu_gpr_write=1'b0;
    assign fpu_value=64'b0; assign fpu_fflags=5'b0;
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
  assign cache_op_is_va=f3==3'b001;
  assign cache_op_kind=ex_inst[21:20];
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
  wire ex_done=fast_done||sys_done||(is_muldiv&&mul_result_valid)||
    ((is_int_mem||is_fp_mem)&&lsu_done)||(is_fp_compute&&fpu_done)||
    accel_done||cache_done||fence_i_done||
    (ex_valid&&(ex_error||!ex_legal));
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
  wire [31:0] address_header_source=f3[2]?{27'd0,ex_inst[19:15]}:
                                            ex_rs1_value;
  wire [31:0] address_header_new=(f3[1:0]==2'b01)?address_header_source:
    (f3[1:0]==2'b10)?(address_header_old|address_header_source):
                       (address_header_old&~address_header_source);
  wire address_header_write=(f3[1:0]==2'b01)||(ex_inst[19:15]!=5'd0);
  wire [31:0] wb_value=is_accel?accel_resp_value[31:0]:
    is_fp_compute?fpu_value[31:0]:is_muldiv?mul_result:
    is_load?lsu_value[31:0]:is_cycle?cycle_q[31:0]:
    is_instret?instret_q[31:0]:is_fp_csr?
    (ex_inst[31:20]==12'h001 ? {27'd0,fflags_q} :
     ex_inst[31:20]==12'h002 ? {29'd0,frm_q} : {24'd0,frm_q,fflags_q}):
    is_hardware_id?EDGE_ASIC_ID[31:0]:
    is_address_header_csr?address_header_old:fast_result;
  wire [31:0] fp_csr_source=f3[2]?{27'd0,ex_inst[19:15]}:ex_rs1_value;
  wire [7:0] fp_csr_old=(ex_inst[31:20]==12'h001)?
                        {3'd0,fflags_q}:
                        (ex_inst[31:20]==12'h002)?
                        {5'd0,frm_q}:{frm_q,fflags_q};
  wire [7:0] fp_csr_new=(f3[1:0]==2'b01)?fp_csr_source[7:0]:
                         (f3[1:0]==2'b10)?
                         (fp_csr_old|fp_csr_source[7:0]):
                         (fp_csr_old&~fp_csr_source[7:0]);
  wire fp_csr_write=(f3[1:0]==2'b01)||(ex_inst[19:15]!=5'd0);
  wire wb_valid=ex_done&&!halted&&!ex_faulting&&(rd!=0)&&!is_store&&!is_fp_store&&
                !is_fp_load&&!is_branch&&!is_ebreak&&
                (!is_accel||decoded_writes_gpr)&&
                (!is_fp_compute||fpu_gpr_write);

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
    .id_valid(),.id_pc(), .id_inst(id_inst),
    .id_is_64b(id_is_64b),.id_error(),.id_rs1(id_rs1),.id_rs2(id_rs2),
    .id_rs1_raw(id_rs1_raw),.id_rs2_raw(id_rs2_raw),.ex_valid(ex_valid),
    .id_op_class(id_decoded_class),.id_legal(id_decoded_legal),
    .id_writes_gpr(id_decoded_writes_gpr),
    .ex_pc(ex_pc),.ex_inst(ex_inst),.ex_is_64b(ex_is_64b),.ex_error(ex_error),
    .ex_rs1_value(ex_rs1_value),.ex_rs2_value(ex_rs2_value),.ex_done(ex_done),
    .ex_op_class(decoded_class),.ex_legal(decoded_legal),
    .ex_writes_gpr(decoded_writes_gpr),
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
      cycle_q<=cycle_q+1; gpr[0]<=0;
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
          if(ex_inst[31:20]==12'h001)
            fflags_q<=fp_csr_new[4:0];
          else if(ex_inst[31:20]==12'h002)
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
        if(!ex_faulting&&is_edge_break) gpr[31]<=ex_rs1_value;
        if(ex_faulting) begin illegal<=1; halted<=1; end
      end
    end
  end
endmodule
