`ifndef EDGE_INSTRUCTION_CLASSIFIER_V
`define EDGE_INSTRUCTION_CLASSIFIER_V
`timescale 1ns/1ps

// Fixed 32-bit instruction-family and ASIC command property classifier.
module edge_instruction_classifier (
  input  wire [31:0] inst,
  output reg  [3:0]  op_class,
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
  localparam [3:0] CLASS_ALU=0, CLASS_BRANCH=1, CLASS_LOAD=2,
    CLASS_STORE=3, CLASS_MULDIV=4, CLASS_FPU=5, CLASS_SYSTEM=6,
    CLASS_CUSTOM=7, CLASS_ACCEL=8, CLASS_ILLEGAL=15;
  localparam [2:0] SCALAR_OTHER=0, SCALAR_LOAD=1, SCALAR_STORE=2,
    SCALAR_ALU=3, SCALAR_M=4;

  wire [6:0] opcode=inst[6:0];
  wire [2:0] funct3=inst[14:12];
  wire [6:0] funct7=inst[31:25];
  assign rd=inst[11:7]; assign rs1=inst[19:15]; assign rs2=inst[24:20];
  assign is_accel=(opcode==7'h3f);
  assign accel_is_tensor=is_accel;
  assign accel_subop=inst[31:25];

  wire zba_op=(opcode==7'h33)&&(funct7==7'b0010000)&&
    ((funct3==2)||(funct3==4)||(funct3==6));
  wire zba_uw=(opcode==7'h3b)&&
    (((funct7==7'b0000100)&&(funct3==0))||
     ((funct7==7'b0010000)&&((funct3==2)||(funct3==4)||(funct3==6))));
  wire slli_uw=(opcode==7'h1b)&&(funct3==1)&&(inst[31:26]==6'b000010);
  wire legal_op_imm=(opcode==7'h13)&&
    (((funct3!=1)&&(funct3!=5))||
     ((funct3==1)&&(inst[31:26]==0))||
     ((funct3==5)&&((inst[31:26]==0)||(inst[31:26]==6'b010000))));
  wire legal_op=(opcode==7'h33)&&(zba_op||(funct7==0)||(funct7==1)||
    ((funct7==7'b0100000)&&((funct3==0)||(funct3==5))));
  wire legal_op_imm32=(opcode==7'h1b)&&((funct3==0)||slli_uw||
    ((funct3==1)&&(funct7==0))||
    ((funct3==5)&&((funct7==0)||(funct7==7'b0100000))));
  wire legal_op32=(opcode==7'h3b)&&(zba_uw||
    ((funct3==0)&&((funct7==0)||(funct7==1)||(funct7==7'b0100000)))||
    ((funct7==1)&&(funct3>=4))||((funct3==1)&&(funct7==0))||
    ((funct3==5)&&((funct7==0)||(funct7==7'b0100000))));
  wire legal_branch=(opcode==7'h63)&&(funct3!=2)&&(funct3!=3);
  wire legal_load=(opcode==7'h03)&&(funct3!=7);
  wire legal_store=(opcode==7'h23)&&(funct3<=3);
  wire legal_fp_mem=((opcode==7'h07)||(opcode==7'h27))&&
    ((funct3==1)||(funct3==2)||(funct3==3)||(funct3>=5));
  wire fp_opcode=(opcode==7'h43)||(opcode==7'h47)||(opcode==7'h4b)||
    (opcode==7'h4f)||(opcode==7'h53);
  wire legal_cache=(opcode==7'h0b)&&(funct7==0)&&(rd==0)&&
    (((funct3==0)&&(rs1==0)&&((rs2==1)||(rs2==2)||(rs2==3)))||
     ((funct3==1)&&((rs2==5)||(rs2==6)||(rs2==7))));
  wire legal_dma32=(opcode==7'h2b)&&(funct3==0)&&
    ((funct7==0)||((funct7==1)&&(rd==0)&&(rs1==0)&&(rs2==0)));
  wire scalar_m=((opcode==7'h33)||(opcode==7'h3b))&&(funct7==1);

  function tensor_subop_allocated;
    input [6:0] subop;
    begin
      case(subop)
        7'h01,7'h02,7'h03,7'h04,7'h05,7'h06,7'h07,7'h08,
        7'h09,
        7'h10,7'h11,7'h12,7'h13,7'h14,7'h15,7'h16,7'h17,
        7'h18,7'h19,7'h1a,7'h1b,7'h1c,7'h1d,7'h1e,7'h1f,
        7'h20,7'h21,7'h22,7'h23,7'h24,7'h25,7'h26,
        7'h27,7'h28,7'h29,7'h2a,7'h2b,7'h2c,7'h2d,7'h2e,7'h2f:
          tensor_subop_allocated=1'b1;
        default: tensor_subop_allocated=1'b0;
      endcase
    end
  endfunction

  function tensor_subop_needs_capture;
    input [6:0] subop;
    begin
      case(subop)
        7'h01,7'h03,7'h04,7'h05,7'h06,7'h07,7'h08,
        7'h11,7'h12,7'h13,7'h14,7'h17,7'h18,7'h1a,7'h1d,
        7'h21,7'h22,7'h23,7'h24,7'h28,7'h29,7'h2a,7'h2b,7'h2c:
          tensor_subop_needs_capture=1'b1;
        default: tensor_subop_needs_capture=1'b0;
      endcase
    end
  endfunction

  always @* begin
    op_class=CLASS_ILLEGAL; legal=1'b1; scalar_issue_class=SCALAR_OTHER;
    writes_gpr=1'b0;
    accel_needs_capture=1'b0; accel_capture_src_gpr=5'd0;
    accel_needs_base_gpr=1'b0; accel_base_src_gpr=rs1;
    accel_is_sync=1'b0; accel_is_getcsr=1'b0;
    if(is_accel) begin
      op_class=CLASS_ACCEL;
      legal=tensor_subop_allocated(accel_subop);
      accel_needs_capture=tensor_subop_needs_capture(accel_subop);
      accel_capture_src_gpr=rs1;
      accel_needs_base_gpr=1'b0;
      accel_base_src_gpr=rs1;
      accel_is_sync=
        ((accel_subop==7'h02)||(accel_subop==7'h16)||
         (accel_subop==7'h26)||(accel_subop==7'h2e));
      accel_is_getcsr=(accel_subop==7'h2f);
      // ASIC getcsr reports through the accelerator CSR result path.
      writes_gpr=1'b0;
    end else if(legal_op||legal_op_imm||legal_op32||legal_op_imm32||
            (opcode==7'h37)||(opcode==7'h17)) begin
      op_class=scalar_m?CLASS_MULDIV:CLASS_ALU;
      scalar_issue_class=scalar_m?SCALAR_M:SCALAR_ALU;
      writes_gpr=rd!=0;
    end else if((opcode==7'h6f)||((opcode==7'h67)&&(funct3==0))||
                legal_branch) begin
      op_class=CLASS_BRANCH;
      writes_gpr=((opcode==7'h6f)||(opcode==7'h67))&&(rd!=0);
    end else if(legal_load) begin
      op_class=CLASS_LOAD; scalar_issue_class=SCALAR_LOAD; writes_gpr=rd!=0;
    end else if(legal_store) begin
      op_class=CLASS_STORE; scalar_issue_class=SCALAR_STORE;
    end else if(legal_fp_mem||fp_opcode) op_class=CLASS_FPU;
    else if((opcode==7'h73)||((opcode==7'h0f)&&(funct3<=1))) begin
      op_class=CLASS_SYSTEM;
      writes_gpr=(opcode==7'h73)&&(funct3!=0)&&(rd!=0);
    end else if(legal_cache||legal_dma32) op_class=CLASS_CUSTOM;
    else legal=1'b0;
  end
endmodule

`endif
