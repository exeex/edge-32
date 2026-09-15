`timescale 1ns/1ps
// RV32IM_Zba IF/predecode -> ID/read -> EX/execute -> WB/retire core.
module edge_32_core #(
  parameter PC_WIDTH = 32,
  parameter DMEM_RESP_FORMATTED = 0,
  parameter ENABLE_FPU = 0,
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
  wire [63:0] cycle_q, instret_q;
  reg mem_started_q, mul_started_q, accel_started_q;
  reg cache_started_q, icache_invalidate_started_q;
  wire core_start_i = AUTO_START ? 1'b0 : core_start;
  wire core_force_stop_i = AUTO_START ? 1'b0 : core_force_stop;

  wire parcel_valid, parcel_ready, parcel_error;
  wire [PC_WIDTH-1:0] parcel_pc; wire [31:0] parcel_inst;
  wire if_valid, if_ready, if_capacity_ready, if_error, if_is_64b;
  wire [PC_WIDTH-1:0] if_pc; wire [63:0] if_inst;
  wire id_is_64b, id_error;
  wire ex_decode_fault_q;
  wire id_terminal_break;
  wire [63:0] id_inst;
  wire ex_valid, ex_error;
  wire [PC_WIDTH-1:0] ex_pc; wire [63:0] ex_inst;
  wire [31:0] ex_rs1_value, ex_rs2_value;
  wire id_capture_enable;
  wire [31:0] id_fpu_control;
  reg [3:0] id_decoded_class;
  reg id_decoded_legal;
  wire [3:0] if_decoded_class;
  wire if_decoded_legal;
  edge_32_decode if_decode(
    .inst(if_inst), .inst_is_64b(if_is_64b), .op_class(if_decoded_class),
    .legal(if_decoded_legal), .rd(), .rs1(), .rs2(),
    .writes_gpr(), .accel_subop(),
    .accel_needs_capture(), .accel_capture_src_gpr());
  reg id_csr_write;
  reg [4:0] id_rs1, id_rs2;
  wire [31:0] id_rs1_value, id_rs2_value, gpr_debug_x31;
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
  wire is_terminal_break;
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
  wire [55:0] id_issue_control;
  reg [55:0] ex_issue_control_q;
  wire [31:0] id_alu_imm, id_mem_imm, id_branch_imm, id_jump_imm;
  reg [31:0] ex_alu_imm_q, ex_mem_imm_q, ex_branch_imm_q, ex_jump_imm_q;
  wire id_issue_legal;
  reg [4:0] id_write_rd;
  reg id_rd_gpr, id_rd_fpr;
  reg [4:0] id_frs0, id_frs1, id_frs2;
  wire [1:0] id_uses_gpr;
  reg [2:0] id_uses_fpr;
  wire [4:0] if_rs1, if_rs2, if_frs0, if_frs1, if_frs2, if_write_rd;
  wire [2:0] if_uses_fpr;
  wire if_rd_gpr, if_rd_fpr, if_csr_write;
  edge_32_register_decode #(.ENABLE_FPU(ENABLE_FPU),
    .UNMASKED_GPR_READ(1)) if_register_decode(
    .inst(if_inst),.inst_is_64b(if_is_64b),
    .read_gpr0(if_rs1),.read_gpr1(if_rs2),
    .read_fpr0(if_frs0),.read_fpr1(if_frs1),.read_fpr2(if_frs2),
    .uses_gpr(),.uses_fpr(if_uses_fpr),
    .write_rd(if_write_rd),.rd_gpr(if_rd_gpr),.rd_fpr(if_rd_fpr),
    .csr_write(if_csr_write));
  always @(posedge clk) begin
    if(if_valid && if_ready) begin
      {id_rs1,id_rs2,id_frs0,id_frs1,id_frs2,id_write_rd} <=
        {if_rs1,if_rs2,if_frs0,if_frs1,if_frs2,if_write_rd};
      {id_uses_fpr,id_rd_gpr,id_rd_fpr,id_csr_write} <=
        {if_uses_fpr,if_rd_gpr,if_rd_fpr,if_csr_write};
      id_decoded_class<=if_decoded_class; id_decoded_legal<=if_decoded_legal;
    end
  end
  // IF captures candidate indices without source-use decoding. ID decides
  // whether operands participate in hazards and the EX issue packet.
  edge_32_register_decode #(.ENABLE_FPU(ENABLE_FPU)) id_gpr_use_decode(
    .inst(id_inst),.inst_is_64b(id_is_64b),.uses_gpr(id_uses_gpr),
    .read_gpr0(),.read_gpr1(),.read_fpr0(),.read_fpr1(),.read_fpr2(),
    .uses_fpr(),.write_rd(),.rd_gpr(),.rd_fpr(),.csr_write());
  edge_32_issue_decode #(.ENABLE_FPU(ENABLE_FPU)) id_issue_decode(
    .inst(id_inst),.op_class(id_decoded_class),.decoded_legal(id_decoded_legal),
    .register_rd(id_write_rd),.rd_gpr(id_rd_gpr),.rd_fpr(id_rd_fpr),
    .fpu_control(id_fpu_control),
    .control(id_issue_control),.terminal_break(id_terminal_break),.alu_imm(id_alu_imm),.mem_imm(id_mem_imm),
    .branch_imm(id_branch_imm),.jump_imm(id_jump_imm),
    .writes_gpr(),.writes_fpr(),
    .issue_legal(id_issue_legal));
  assign {is_lui,is_auipc,is_jal,is_jalr,is_branch,is_load,
    is_store,is_fp_load,is_fp_store,is_fp_compute,is_muldiv,is_cycle,
    is_instret,is_hardware_id,is_icache_header_csr,is_dcache_header_csr,is_fp_csr,
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
  // One registered completion slot. EX can complete while old WB retires.
  reg wb_pending_q;
  reg [31:0] wb_fast_value_q, wb_other_value_q;
  reg wb_fast_q;
  wire [31:0] wb_value_q=wb_fast_q ? wb_fast_value_q:wb_other_value_q;
  reg [4:0] wb_rd_q;
  reg [31:1] wb_gpr_select_q;
  genvar gpr_destination;
  generate for (gpr_destination=1; gpr_destination<32;
                gpr_destination=gpr_destination+1) begin : g_wb_gpr_decode
    // EX decodes the destination; WB only gates the registered word select.
    always @(posedge clk)
      if (ex_done) wb_gpr_select_q[gpr_destination] <=
        (rd == gpr_destination[4:0]);
  end endgenerate
  reg wb_gpr_q, wb_fault_q, wb_halt_q;
  wire wb_fp_csr_q;
  reg wb_icache_header_q, wb_dcache_header_q;
  reg [31:0] wb_header_value_q;
  wire wb_commit=wb_pending_q&&!halted&&!core_start_i&&!core_force_stop_i;
  edge_32_counter64 cycle_counter(.clk(clk),.reset_n(reset_n),
    .enable(1'b1),.value(cycle_q));
  edge_32_counter64 retire_counter(.clk(clk),.reset_n(reset_n),
    .enable(wb_commit&&!wb_fault_q),.value(instret_q));
  wire wb_terminal=wb_pending_q&&(wb_fault_q||wb_halt_q);
  wire wb_valid=wb_commit&&!wb_fault_q&&wb_gpr_q;
  // A result still in EX cannot bypass the new WB register boundary.
  wire id_gpr_hazard=ex_valid&&ex_writes_gpr&&(rd!=0)&&
    ((id_uses_gpr[0]&&id_rs1==rd)||(id_uses_gpr[1]&&id_rs2==rd));
  wire id_fpr_hazard=ex_valid&&ex_writes_fpr&&
    ((id_uses_fpr[0]&&id_frs0==rd)||(id_uses_fpr[1]&&id_frs1==rd)||
     (id_uses_fpr[2]&&id_frs2==rd));
  // Dynamic FRM and header state are read only after the older CSR commits.
  wire id_reads_fp_csr=ENABLE_FPU&&(id_inst[6:0]==7'h73)&&
    (id_inst[14:12]!=0)&&((id_inst[31:20]==12'h001)||
    (id_inst[31:20]==12'h002)||(id_inst[31:20]==12'h003));
  wire id_csr_hazard=(id_reads_fp_csr&&ex_valid&&is_fp_compute)||
    (ex_valid&&csr_write&&
    (is_fp_csr||is_icache_header_csr||is_dcache_header_csr)) ||
    (wb_pending_q&&(wb_fp_csr_q||wb_icache_header_q||wb_dcache_header_q));
  wire id_stall=id_gpr_hazard||id_fpr_hazard||id_csr_hazard;
  wire is_address_header_csr=is_icache_header_csr||is_dcache_header_csr;
  wire ex_legal=decoded_legal;
  wire ex_issue_ok=ex_valid&&!halted&&!wb_terminal&&!ex_decode_fault_q&&
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
  edge_32_muldiv_asap7 muldiv(.clk(clk),.reset_n(reset_n),
    .op_valid(mul_start),.op_ready(mul_ready),
    .src0(ex_rs1_value),.src1(ex_rs2_value),.funct3(f3),
    .result_valid(mul_result_valid),.result_value(mul_result),.busy());


  wire lsu_ready,lsu_done,lsu_error; wire [31:0] lsu_value;
  wire [31:0] lsu_mem_addr;
  wire lsu_start=ex_issue_ok&&(is_int_mem||is_fp_mem)&&!mem_started_q;
  wire [31:0] fp_load_value;
  wire [63:0] fp_store_value;
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

  wire fp_compute_complete;
  wire [31:0] fpu_value, fp_csr_value;
  generate if(ENABLE_FPU) begin: g_fpu
    edge_32_fpu fpu(
      .clk(clk),.reset_n(reset_n),.cancel(core_start_i||core_force_stop_i),
      .id_capture_enable(id_capture_enable),.id_inst(id_inst[31:0]),
      .id_frs0(id_frs0),.id_frs1(id_frs1),.id_frs2(id_frs2),
      .id_fpu_control(id_fpu_control),.ex_issue_ok(ex_issue_ok),.ex_done(ex_done),
      .is_fp_compute(is_fp_compute),.ex_writes_fpr(ex_writes_fpr),
      .is_fp_csr(is_fp_csr),.csr_fflags(csr_fflags),.csr_frm(csr_frm),
      .csr_write(csr_write),.f3(f3),.csr_uimm(csr_uimm),
      .ex_rs1_value(ex_rs1_value),.lsu_value(lsu_value),
      .fp_compute_complete(fp_compute_complete),.fpu_value(fpu_value),
      .fp_load_value(fp_load_value),.fp_store_value(fp_store_value),
      .fp_csr_value(fp_csr_value),.wb_commit(wb_commit),.wb_fault_q(wb_fault_q),
      .wb_rd_q(wb_rd_q),.wb_value_q(wb_value_q),.wb_fp_csr_q(wb_fp_csr_q));
  end else begin: g_no_fpu
    assign id_fpu_control=32'd0;
    assign fp_compute_complete=1'b0;
    assign fpu_value=32'd0; assign fp_csr_value=32'd0;
    assign fp_load_value=32'd0; assign fp_store_value=64'd0;
    assign wb_fp_csr_q=1'b0;
  end endgenerate

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
  // Pipeline already owns EX valid and cancels capture on stop/redirect.
  // Export execution readiness before WB's live-owner/commit qualification.
  wire ex_release_ready=(fast_done||sys_done||(is_muldiv&&mul_started_q&&mul_result_valid)||
     ((is_int_mem||is_fp_mem)&&mem_started_q&&lsu_done)||
     fp_compute_complete||
     accel_done||cache_done||fence_i_done||ex_decode_fault_q);
  wire ex_done=ex_valid&&!halted&&!core_start_i&&!core_force_stop_i&&
               ex_release_ready;
  wire ex_faulting=ex_decode_fault_q||
    ((is_int_mem||is_fp_mem)&&lsu_done&&lsu_error)||
    (is_accel&&accel_done&&accel_resp_error);
  // Same ID->EX edge, distinct physical owner beside the frontend. Execution
  // units export narrow owned fault events; no operand/result bus enters here.
  wire terminal_complete;
  edge_32_frontend_control frontend_control(
    .clk(clk),.id_capture_enable(id_capture_enable),
    .id_decode_fault(id_error||!id_issue_legal),
    .id_terminal_break(id_terminal_break),
    .ex_valid(ex_valid),.halted(halted),.wb_terminal(wb_terminal),
    .core_start(core_start_i),.core_force_stop(core_force_stop_i),
    .memory_fault_complete((is_int_mem||is_fp_mem)&&mem_started_q&&lsu_done&&lsu_error),
    .accel_fault_complete(accel_done&&accel_resp_error),
    .ex_decode_fault(ex_decode_fault_q),.ex_terminal_break(is_terminal_break),
    .terminal_complete(terminal_complete));
  wire frontend_stop=halted||terminal_complete||wb_terminal;
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
  wire [31:0] ex_result=is_edge_break?ex_rs1_value:is_accel?accel_resp_value[31:0]:
    is_fp_compute?fpu_value:is_muldiv?mul_result:
    is_fp_load?fp_load_value:is_load?lsu_value[31:0]:is_cycle?cycle_q[31:0]:
    is_instret?(instret_q[31:0]+{31'd0,(wb_commit&&!wb_fault_q)}):is_fp_csr?
    fp_csr_value:
    is_hardware_id?EDGE_ASIC_ID[31:0]:
    is_address_header_csr?address_header_old:32'd0;
  always @(posedge clk or negedge reset_n) begin
    if(!reset_n) wb_pending_q<=1'b0;
    else if(core_start_i||core_force_stop_i||halted) wb_pending_q<=1'b0;
    else wb_pending_q<=ex_done;
  end
  // WB payload has no reset; pending owns its visibility and cancellation.
  always @(posedge clk) begin
    if(ex_done) begin
      wb_fast_value_q<=fast_result; wb_other_value_q<=ex_result;
      wb_fast_q<=is_fast_class; wb_rd_q<=rd;
      wb_gpr_q<=ex_writes_gpr;
      wb_fault_q<=ex_faulting; wb_halt_q<=is_terminal_break;
      wb_icache_header_q<=is_icache_header_csr&&address_header_write;
      wb_dcache_header_q<=is_dcache_header_csr&&address_header_write;
      wb_header_value_q<=address_header_new;
    end
  end

  edge_32_gpr #(.PREDECODED_WRITE(1)) gpr_file(
    .clk(clk),.reset_n(reset_n),.read_rs1(id_rs1),.read_rs2(id_rs2),
    .read_value1(id_rs1_value),.read_value2(id_rs2_value),
    .write_valid(wb_valid),.write_rd(wb_rd_q),.write_select(wb_gpr_select_q),.write_value(wb_value_q),
    .debug_x31(gpr_debug_x31));

  edge_32_frontend #(.PC_WIDTH(PC_WIDTH),.AUTO_START(AUTO_START)) frontend(
    .clk(clk),.reset_n(reset_n),.boot_pc(boot_pc),
    .fetch_start(core_start_i),.fetch_stop(core_force_stop_i),
    .imem_req_valid(imem_req_valid),.imem_req_ready(imem_req_ready),
    .imem_req_addr(imem_req_addr),.imem_resp_valid(imem_resp_valid),
    .imem_resp_data(imem_resp_data),.imem_resp_error(imem_resp_error),
    .op_valid(parcel_valid),.op_ready(parcel_ready),
    // Stop/redirect qualify actual transfers at the frontend, after capacity.
    .op_capacity_ready(if_capacity_ready && !core_start_i && !core_force_stop_i),.op_pc(parcel_pc),
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
    .fetch_valid(if_valid),.fetch_ready(if_ready),
    .fetch_capacity_ready(if_capacity_ready),.fetch_pc(if_pc),
    .fetch_inst(if_inst),.fetch_is_64b(if_is_64b),.fetch_error(if_error),
    .id_valid(),.id_capture_enable(id_capture_enable),.id_pc(), .id_inst(id_inst),
    .id_is_64b(id_is_64b),.id_error(id_error),
    .id_rs1_value(id_uses_gpr[0] ? id_rs1_value : 32'd0),
    .id_rs2_value(id_uses_gpr[1] ? id_rs2_value : 32'd0),.ex_valid(ex_valid),
    .id_legal(id_issue_legal),
    .id_csr_write(id_csr_write),.id_stall(id_stall),
    .ex_pc(ex_pc),.ex_inst(ex_inst),.ex_is_64b(),.ex_error(ex_error),
    .ex_rs1_value(ex_rs1_value),.ex_rs2_value(ex_rs2_value),.ex_done(ex_release_ready),
    .ex_legal(decoded_legal),
    .ex_redirect_valid(redirect||terminal_complete||wb_terminal||halted||core_start_i||
                       core_force_stop_i));

  assign debug_x31={32'd0,gpr_debug_x31};
  assign cycle_count=cycle_q; assign instret_count=instret_q;
  always @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
      mem_started_q<=0; mul_started_q<=0;
      icache_address_header_q<=0; dcache_address_header_q<=0;
      accel_started_q<=0; cache_started_q<=0;
      icache_invalidate_started_q<=0;
      halted<=0; illegal<=0;
    end else begin
      if(core_start_i) begin halted<=0; illegal<=0; end
      if(core_start_i||core_force_stop_i) begin
        mem_started_q<=0; mul_started_q<=0;
        accel_started_q<=0; cache_started_q<=0;
        icache_invalidate_started_q<=0;
      end
      if(lsu_start&&lsu_ready) mem_started_q<=1;
      if(mul_start&&mul_ready) mul_started_q<=1;
      if(accel_req_fire) accel_started_q<=1;
      if(cache_req_fire) cache_started_q<=1;
      if(icache_invalidate_fire) icache_invalidate_started_q<=1;
      if(ex_done&&!halted&&!core_start_i&&!core_force_stop_i) begin
        mem_started_q<=0; mul_started_q<=0; accel_started_q<=0;
        cache_started_q<=0;
        icache_invalidate_started_q<=0;
      end
      if(wb_commit) begin
        if(!wb_fault_q&&wb_icache_header_q)
          icache_address_header_q<=wb_header_value_q;
        if(!wb_fault_q&&wb_dcache_header_q)
          dcache_address_header_q<=wb_header_value_q;
        if(!wb_fault_q&&wb_halt_q) halted<=1;
        if(wb_fault_q) begin illegal<=1; halted<=1; end
      end
    end
  end
endmodule
