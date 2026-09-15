`timescale 1ns/1ps
// Optional FP owner: ID decode/read, EX payload/issue, memory format and WB state.
// The core owns stage validity, dependencies and retirement authorization.
module edge_32_fpu (
  input wire clk, reset_n, cancel,
  input wire id_capture_enable,
  input wire [31:0] id_inst,
  input wire [4:0] id_frs0, id_frs1, id_frs2,
  output wire [31:0] id_fpu_control,
  input wire ex_issue_ok, ex_done, is_fp_compute, ex_writes_fpr,
  input wire is_fp_csr, csr_fflags, csr_frm, csr_write,
  input wire [2:0] f3,
  input wire [4:0] csr_uimm,
  input wire [31:0] ex_rs1_value, lsu_value,
  output wire fp_compute_complete,
  output wire [31:0] fpu_value, fp_load_value, fp_csr_value,
  output wire [63:0] fp_store_value,
  input wire wb_commit, wb_fault_q,
  input wire [4:0] wb_rd_q,
  input wire [31:0] wb_value_q,
  output reg wb_fp_csr_q
);
  reg [4:0] fflags_q;
  reg [2:0] frm_q;
  reg fpu_started_q;
  reg wb_fpr_q, wb_fp_flags_q, wb_csr_fflags_q, wb_csr_frm_q;
  reg [4:0] wb_fflags_q;
  reg [7:0] wb_fp_csr_value_q;
  wire fpu_ready, fpu_done, fpr_load_ready;
  wire [4:0] fpu_fflags;
  wire wb_fpr_valid=wb_commit&&!wb_fault_q&&wb_fpr_q;
  wire fpu_start=ex_issue_ok&&is_fp_compute&&!fpu_started_q&&fpu_ready;
  assign fp_compute_complete=is_fp_compute&&fpu_started_q&&fpu_done;
  wire [31:0] id_fsrc0, id_fsrc1, id_fsrc2;
  reg [31:0] ex_fsrc0_q, ex_fsrc1_q, ex_fsrc2_q;
  reg [31:0] ex_fpu_control_q;
  edge_fpu_id_decode #(.GPR_WIDTH(32)) id_fp_decode(
    .inst(id_inst),.frm(frm_q),.control(id_fpu_control));
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
  edge_fpu_alu #(.GPR_WIDTH(32),.PREDECODED(1),.EXTERNAL_FPR_WRITEBACK(1)) fpu_alu(
    .clk(clk),.reset_n(reset_n),
    .cancel(cancel),
    .issue_valid(ex_issue_ok&&is_fp_compute&&!fpu_started_q),
    .issue_ready(fpu_ready),.issue_inst(32'b0),.issue_control(ex_fpu_control_q),
    .issue_gpr_src(ex_rs1_value),.issue_frm(3'b0),
    .issue_fsrc0(ex_fsrc0_q),.issue_fsrc1(ex_fsrc1_q),.issue_fsrc2(ex_fsrc2_q),
    .read_frs0(id_frs0),.read_frs1(id_frs1),.read_frs2(id_frs2),
    .read_fsrc0(id_fsrc0),.read_fsrc1(id_fsrc1),.read_fsrc2(id_fsrc2),
    .issue_legal(),
    .complete_valid(fpu_done),.complete_gpr_write(),
    .complete_rd(),.complete_value(fpu_value),
    .complete_fflags(fpu_fflags),
    .load_write_valid(wb_fpr_valid),
    .load_write_ready(fpr_load_ready),.load_write_rd(wb_rd_q),.load_write_value(wb_value_q),
    .store_read_rs(5'd0),.store_read_value());

  edge_32_fp_mem_format fp_mem_format(
    .funct3(f3),.load_value({32'd0,lsu_value}),.store_fp32(ex_fsrc1_q),
    .load_fp32(fp_load_value),.store_value(fp_store_value));
  assign fp_csr_value={24'd0,fp_csr_old};
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

  // Resetless WB payload is visible only under the core's commit authorization.
  always @(posedge clk) begin
    if(ex_done) begin
      wb_fpr_q<=ex_writes_fpr;
      wb_fp_flags_q<=is_fp_compute; wb_fflags_q<=fpu_fflags;
      wb_fp_csr_q<=is_fp_csr&&fp_csr_write;
      wb_csr_fflags_q<=csr_fflags; wb_csr_frm_q<=csr_frm;
      wb_fp_csr_value_q<=fp_csr_new;
    end
  end
  always @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
      fpu_started_q<=0; fflags_q<=0; frm_q<=0;
    end else begin
      if(cancel) fpu_started_q<=0;
      if(fpu_start) fpu_started_q<=1;
      if(ex_done) fpu_started_q<=0;
      if(wb_commit) begin
        if(!wb_fault_q&&wb_fp_csr_q) begin
          if(wb_csr_fflags_q)
            fflags_q<=wb_fp_csr_value_q[4:0];
          else if(wb_csr_frm_q)
            frm_q<=wb_fp_csr_value_q[2:0];
          else begin
            fflags_q<=wb_fp_csr_value_q[4:0];
            frm_q<=wb_fp_csr_value_q[7:5];
          end
        end

        if(!wb_fault_q&&wb_fp_flags_q)
          fflags_q<=fflags_q|wb_fflags_q;
      end
    end
  end
endmodule
