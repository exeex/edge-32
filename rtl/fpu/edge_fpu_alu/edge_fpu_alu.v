`timescale 1ns/1ps

// Single-issue architectural FPU boundary.  The owner supplies one decoded
// instruction at a time; this leaf owns the FPR file, FP decode and the
// variable-latency execution-unit selection.  Issue/retire policy stays in the
// surrounding core (edge-rv or edge-rv-lite).
module edge_fpu_alu (
  input  wire        clk,
  input  wire        reset_n,
  input  wire        issue_valid,
  output wire        issue_ready,
  input  wire [31:0] issue_inst,
  input  wire [63:0] issue_gpr_src,
  input  wire [2:0]  issue_frm,
  output wire        issue_legal,
  output reg         complete_valid,
  output reg         complete_gpr_write,
  output reg  [4:0]  complete_rd,
  output reg  [63:0] complete_value,
  output reg  [4:0]  complete_fflags,
  input  wire        load_write_valid,
  input  wire [4:0]  load_write_rd,
  input  wire [31:0] load_write_value,
  input  wire [4:0]  store_read_rs,
  output wire [31:0] store_read_value
);
  localparam [3:0] MISC_SGNJ=0, MISC_MINMAX=1, MISC_CMP=2,
    MISC_CLASS=3, MISC_MV_X_F=4, MISC_MV_F_X=5,
    MISC_MV_X_FP4=6, MISC_MV_FP4_X=7;
  localparam [1:0] CVT_F2F=0, CVT_F2I=1, CVT_I2F=2;

  reg [31:0] fpr [0:31];
  reg busy_q;
  reg [4:0] pending_rd_q;
  integer i;

  wire [6:0] opcode=issue_inst[6:0];
  wire [2:0] funct3=issue_inst[14:12];
  wire [4:0] rd=issue_inst[11:7], rs1=issue_inst[19:15];
  wire [4:0] rs2=issue_inst[24:20], rs3=issue_inst[31:27];
  wire op_madd=(opcode==7'h43)||(opcode==7'h47)||(opcode==7'h4b)||(opcode==7'h4f);
  wire op_fp=opcode==7'h53;
  wire rounding_rm_valid=(funct3<=3'b100)||
                         ((funct3==3'b111)&&(issue_frm<=3'b100));
  wire [2:0] rm=funct3==3'b111 ? issue_frm:funct3;
  wire fmac_basic=op_fp&&((issue_inst[31:27]==5'b00000)||
    (issue_inst[31:27]==5'b00001)||(issue_inst[31:27]==5'b00010));
  wire fmac_op=(op_madd||fmac_basic)&&rounding_rm_valid;
  wire slow_div=op_fp&&(issue_inst[31:27]==5'b00011);
  wire slow_sqrt=op_fp&&(issue_inst[31:27]==5'b01011)&&(rs2==0);
  wire slow_op=(slow_div||slow_sqrt)&&rounding_rm_valid;
  wire misc_sgnj=op_fp&&(issue_inst[31:27]==5'b00100)&&(funct3<=2);
  wire misc_minmax=op_fp&&(issue_inst[31:27]==5'b00101)&&(funct3<=1);
  wire misc_cmp=op_fp&&(issue_inst[31:27]==5'b10100)&&(funct3<=2);
  wire misc_class=op_fp&&(issue_inst[31:27]==5'b11100)&&(rs2==0)&&(funct3==1);
  wire misc_mvx=op_fp&&(issue_inst[31:27]==5'b11100)&&(rs2==0)&&(funct3==0);
  wire misc_mvf=op_fp&&(issue_inst[31:27]==5'b11110)&&(rs2==0)&&(funct3==0);
  wire misc_x_fp4=op_fp&&(issue_inst[31:25]==7'b1110011)&&(rs2==0)&&(funct3==0);
  wire misc_fp4_x=op_fp&&(issue_inst[31:25]==7'b1111011)&&(rs2==0)&&(funct3==0);
  wire misc_op=((issue_inst[26:25]!=2'b11)&&(misc_sgnj||misc_minmax||
    misc_cmp||misc_class||misc_mvx||misc_mvf))||misc_x_fp4||misc_fp4_x;
  wire cvt_f2f=op_fp&&(issue_inst[31:27]==5'b01000)&&(rs2[4:2]==0)&&(rs2[1:0]!=3);
  wire cvt_f2i=op_fp&&(issue_inst[31:27]==5'b11000)&&(rs2[4:2]==0);
  wire cvt_i2f=op_fp&&(issue_inst[31:27]==5'b11010)&&(rs2[4:2]==0);
  wire cvt_op=(issue_inst[26:25]!=2'b11)&&rounding_rm_valid&&
              (cvt_f2f||cvt_f2i||cvt_i2f);
  assign issue_legal=fmac_op||slow_op||misc_op||cvt_op;

  reg [3:0] misc_sel;
  reg [1:0] cvt_sel;
  reg [19:0] fmac_func;
  always @* begin
    misc_sel=MISC_SGNJ;
    if(misc_minmax) misc_sel=MISC_MINMAX; else if(misc_cmp) misc_sel=MISC_CMP;
    else if(misc_class) misc_sel=MISC_CLASS; else if(misc_mvx) misc_sel=MISC_MV_X_F;
    else if(misc_mvf) misc_sel=MISC_MV_F_X;
    if(misc_x_fp4) misc_sel=MISC_MV_X_FP4;
    else if(misc_fp4_x) misc_sel=MISC_MV_FP4_X;
    cvt_sel=cvt_f2i ? CVT_F2I : cvt_i2f ? CVT_I2F : CVT_F2F;
    fmac_func=0;
    if(op_madd) begin
      fmac_func[6:4]=3'b010;
      fmac_func[2:0]=(opcode==7'h43)?3'b001:(opcode==7'h47)?3'b011:
                        (opcode==7'h4f)?3'b101:3'b111;
    end else if(issue_inst[31:27]==5'b00000) begin
      fmac_func[15:12]=4'b0010; fmac_func[7]=1; fmac_func[4]=1;
    end else if(issue_inst[31:27]==5'b00001) begin
      fmac_func[15:12]=4'b0010; fmac_func[7]=1; fmac_func[3]=1;
    end else fmac_func[6:4]=3'b010;
  end

  wire fmac_stall, fmac_done; wire [31:0] fmac_value; wire [4:0] fmac_flags;
  wire misc_ready, misc_done, misc_domain; wire [63:0] misc_value; wire [4:0] misc_flags;
  wire cvt_ready, cvt_done, cvt_domain; wire [63:0] cvt_value; wire [4:0] cvt_flags;
  wire slow_ready, slow_done; wire [31:0] slow_value; wire [4:0] slow_flags;
  wire fire=issue_valid&&issue_ready&&issue_legal;
  assign issue_ready=!busy_q && (!fmac_op||!fmac_stall) && (!slow_op||slow_ready);
  assign store_read_value=fpr[store_read_rs];

  edge_fpu_fmac fmac(.cpurst_b(reset_n),.forever_cpuclk(clk),.fmac_cancel(1'b0),
    .fmac_inst_vld(fire&&fmac_op),.fmac_func(fmac_func),.fmac_rm(rm),
    .fmac_src0(fpr[rs1]),.fmac_src1(fpr[rs2]),.fmac_src2(fpr[rs3]),
    .fmac_dst_reg(rd),.fmac_dst_vld(1'b1),.fmac_stall(fmac_stall),
    .fmac_wb_data(fmac_value),.fmac_wb_fflags(fmac_flags),.fmac_wb_reg(),
    .fmac_wb_vld(fmac_done));
  edge_fpu_misc #(.SEQ_ID_WIDTH(1),.EPOCH_WIDTH(1)) misc(
    .forever_cpuclk(clk),.cpurst_b(reset_n),.misc_issue_valid(fire&&misc_op),
    .misc_issue_ready(misc_ready),.misc_issue_seq_id(1'b0),.misc_issue_epoch(1'b0),
    .misc_issue_op(misc_sel),.misc_issue_fmt(issue_inst[26:25]),.misc_issue_rm(rm),
    .misc_issue_funct3(funct3),.misc_issue_rd(rd),.misc_issue_rd_bank(1'b0),
    .misc_issue_fsrc0(fpr[rs1]),.misc_issue_fsrc1(fpr[rs2]),
    .misc_issue_gsrc0(issue_gpr_src),.misc_complete_valid(misc_done),
    .misc_complete_seq_id(),.misc_complete_epoch(),.misc_complete_rd(),
    .misc_complete_rd_bank(),.misc_complete_domain(misc_domain),
    .misc_complete_value(misc_value),.misc_complete_fflags(misc_flags));
  edge_fpu_cvt #(.SEQ_ID_WIDTH(1),.EPOCH_WIDTH(1)) cvt(
    .forever_cpuclk(clk),.cpurst_b(reset_n),.cvt_issue_valid(fire&&cvt_op),
    .cvt_issue_ready(cvt_ready),.cvt_issue_seq_id(1'b0),.cvt_issue_epoch(1'b0),
    .cvt_issue_op(cvt_sel),.cvt_issue_int_type(rs2[1:0]),.cvt_issue_rm(rm),
    .cvt_issue_rd(rd),.cvt_issue_rd_bank(1'b0),.cvt_issue_fsrc(fpr[rs1]),
    .cvt_issue_gsrc(issue_gpr_src),.cvt_complete_valid(cvt_done),
    .cvt_complete_seq_id(),.cvt_complete_epoch(),.cvt_complete_rd(),
    .cvt_complete_rd_bank(),.cvt_complete_domain(cvt_domain),
    .cvt_complete_value(cvt_value),.cvt_complete_fflags(cvt_flags));
  edge_fpu_slow #(.SEQ_ID_WIDTH(1),.EPOCH_WIDTH(1)) slow(
    .forever_cpuclk(clk),.cpurst_b(reset_n),.slow_cancel(1'b0),
    .slow_issue_valid(fire&&slow_op),.slow_issue_ready(slow_ready),
    .slow_issue_seq_id(1'b0),.slow_issue_epoch(1'b0),.slow_issue_sqrt(slow_sqrt),
    .slow_issue_rm(rm),.slow_issue_rd(rd),.slow_issue_rd_bank(1'b0),
    .slow_issue_src0(fpr[rs1]),.slow_issue_src1(fpr[rs2]),
    .slow_complete_valid(slow_done),.slow_complete_seq_id(),.slow_complete_epoch(),
    .slow_complete_rd(),.slow_complete_rd_bank(),.slow_complete_value(slow_value),
    .slow_complete_fflags(slow_flags));

  always @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
      busy_q<=0; complete_valid<=0; complete_gpr_write<=0; complete_rd<=0;
      complete_value<=0; complete_fflags<=0; pending_rd_q<=0;
      for(i=0;i<32;i=i+1) fpr[i]<=0;
    end else begin
      complete_valid<=0;
      if(load_write_valid) fpr[load_write_rd]<=load_write_value;
      if(fire) begin busy_q<=1; pending_rd_q<=rd; end
      if(fmac_done||misc_done||cvt_done||slow_done) begin
        busy_q<=0; complete_valid<=1; complete_rd<=pending_rd_q;
        complete_gpr_write=(misc_done&& !misc_domain)||(cvt_done&&!cvt_domain);
        complete_value<=fmac_done?{32'b0,fmac_value}:slow_done?{32'b0,slow_value}:
                        misc_done?misc_value:cvt_value;
        complete_fflags<=fmac_done?fmac_flags:slow_done?slow_flags:
                         misc_done?misc_flags:cvt_flags;
        if(fmac_done) fpr[pending_rd_q]<=fmac_value;
        else if(slow_done) fpr[pending_rd_q]<=slow_value;
        else if(misc_done&&misc_domain) fpr[pending_rd_q]<=misc_value[31:0];
        else if(cvt_done&&cvt_domain) fpr[pending_rd_q]<=cvt_value[31:0];
      end
    end
  end
endmodule
