module edge_fpu_misc #(
  parameter SEQ_ID_WIDTH = 8,
  parameter EPOCH_WIDTH = 4,
  parameter REG_INDEX_WIDTH = 5,
  parameter VALUE_WIDTH = 64,
  parameter OP_WIDTH = 4
) (
  input  wire                       forever_cpuclk,
  input  wire                       cpurst_b,
  input  wire                       misc_issue_valid,
  output wire                       misc_issue_ready,
  input  wire [SEQ_ID_WIDTH-1:0]    misc_issue_seq_id,
  input  wire [EPOCH_WIDTH-1:0]     misc_issue_epoch,
  input  wire [OP_WIDTH-1:0]        misc_issue_op,
  input  wire [1:0]                 misc_issue_fmt,
  input  wire [2:0]                 misc_issue_rm,
  input  wire [2:0]                 misc_issue_funct3,
  input  wire [REG_INDEX_WIDTH-1:0] misc_issue_rd,
  input  wire                       misc_issue_rd_bank,
  input  wire [31:0]                misc_issue_fsrc0,
  input  wire [31:0]                misc_issue_fsrc1,
  input  wire [VALUE_WIDTH-1:0]     misc_issue_gsrc0,
  output reg                        misc_complete_valid,
  output reg  [SEQ_ID_WIDTH-1:0]    misc_complete_seq_id,
  output reg  [EPOCH_WIDTH-1:0]     misc_complete_epoch,
  output reg  [REG_INDEX_WIDTH-1:0] misc_complete_rd,
  output reg                        misc_complete_rd_bank,
  output reg                        misc_complete_domain,
  output reg  [VALUE_WIDTH-1:0]     misc_complete_value,
  output reg  [4:0]                 misc_complete_fflags
);

  localparam [OP_WIDTH-1:0] OP_SGNJ  = 4'd0;
  localparam [OP_WIDTH-1:0] OP_MINMAX = 4'd1;
  localparam [OP_WIDTH-1:0] OP_CMP   = 4'd2;
  localparam [OP_WIDTH-1:0] OP_CLASS = 4'd3;
  localparam [OP_WIDTH-1:0] OP_MV_X_F = 4'd4;
  localparam [OP_WIDTH-1:0] OP_MV_F_X = 4'd5;
  localparam [OP_WIDTH-1:0] OP_MV_X_FP4 = 4'd6;
  localparam [OP_WIDTH-1:0] OP_MV_FP4_X = 4'd7;

  localparam [1:0] FMT_S = 2'b00;
  localparam [1:0] FMT_H = 2'b10;

  reg [VALUE_WIDTH-1:0] result_d;
  reg result_domain_d;
  reg [4:0] fflags_d;
  reg [15:0] half_payload;
  reg [31:0] fpr_result;
  reg less_than;
  reg equal;
  wire src0_nan = (&misc_issue_fsrc0[30:23]) && (|misc_issue_fsrc0[22:0]);
  wire src1_nan = (&misc_issue_fsrc1[30:23]) && (|misc_issue_fsrc1[22:0]);
  wire src0_snan = src0_nan && !misc_issue_fsrc0[22];
  wire src1_snan = src1_nan && !misc_issue_fsrc1[22];
  wire src0_zero = (misc_issue_fsrc0[30:0] == 31'b0);
  wire src1_zero = (misc_issue_fsrc1[30:0] == 31'b0);

  assign misc_issue_ready = 1'b1;

  // Finite numerical candidate: exponent ranges bound the shift to 0..11.
  // NaN/Inf never select operands, shifter controls, or rounding controls.
  function [15:0] fp32_to_fp16_finite;
    input [31:0] value;
    input [2:0] rm;
    reg [7:0] exp;
    reg [23:0] sig, shifted;
    reg [3:0] extra_shift;
    reg [10:0] kept, lost_mask;
    reg [11:0] rounded;
    reg guard, sticky, increment, overflow_to_inf;
    reg [5:0] half_exp;
    begin
      exp = value[30:23];
      sig = {exp != 0, value[22:0]};
      extra_shift = (exp >= 8'd102 && exp < 8'd113) ? 8'd113-exp : 4'd0;
      shifted = sig >> extra_shift;
      lost_mask = (11'd1 << extra_shift) - 11'd1;
      kept = (exp < 8'd102) ? 11'd0 : shifted[23:13];
      guard = (exp >= 8'd102) && shifted[12];
      sticky = (exp < 8'd102) ? |sig :
               (|shifted[11:0] || |(sig[10:0] & lost_mask));
      case (rm)
        3'd1: increment = 1'b0;
        3'd2: increment = value[31] && (guard || sticky);
        3'd3: increment = !value[31] && (guard || sticky);
        3'd4: increment = guard;
        default: increment = guard && (sticky || kept[0]);
      endcase
      rounded = {1'b0, kept} + increment;
      overflow_to_inf = (rm == 3'd0) || (rm == 3'd4) ||
                        ((rm == 3'd2) && value[31]) ||
                        ((rm == 3'd3) && !value[31]);
      half_exp = exp - 8'd112 + rounded[11];
      if (exp > 8'd142 || (exp == 8'd142 && rounded[11]))
        fp32_to_fp16_finite = overflow_to_inf ? {value[31], 5'h1f, 10'b0}
                                                  : {value[31], 5'h1e, 10'h3ff};
      else if (exp >= 8'd113)
        fp32_to_fp16_finite = {value[31], half_exp[4:0],
                               rounded[11] ? 10'b0 : rounded[9:0]};
      else
        fp32_to_fp16_finite = {value[31], 4'b0, rounded[10:0]};
    end
  endfunction

  wire [15:0] half_numeric = fp32_to_fp16_finite(misc_issue_fsrc0, misc_issue_rm);
  wire half_special = &misc_issue_fsrc0[30:23];
  // Result boundary priority: canonical NaN, signed infinity, finite candidate.
  wire [15:0] half_resolved = half_special ?
      (src0_nan ? 16'h7e00 : {misc_issue_fsrc0[31], 5'h1f, 10'b0}) : half_numeric;

  function [31:0] fp16_to_fp32;
    input [15:0] value;
    integer i;
    integer lead;
    reg [9:0] frac;
    reg [7:0] out_exp;
    reg found;
    begin
      frac = value[9:0];
      if (value[14:10] == 5'h1f)
        fp16_to_fp32 = (frac == 0) ? {value[15], 8'hff, 23'b0} : 32'h7fc00000;
      else if (value[14:10] != 0)
        fp16_to_fp32 = {value[15], value[14:10] + 8'd112, frac, 13'b0};
      else if (frac == 0)
        fp16_to_fp32 = {value[15], 31'b0};
      else begin
        lead = 0; found = 0;
        for (i = 9; i >= 0; i = i - 1)
          if (!found && frac[i]) begin lead = 9-i; found = 1; end
        out_exp = 8'd112 - lead;
        fp16_to_fp32 = {value[15], out_exp, (frac << (lead+1)), 13'b0};
      end
    end
  endfunction

  function fp32_lt;
    input [31:0] a;
    input [31:0] b;
    begin
      if (a[30:0] == 0 && b[30:0] == 0) fp32_lt = 1'b0;
      else if (a[31] != b[31]) fp32_lt = a[31];
      else if (a[31]) fp32_lt = a[30:0] > b[30:0];
      else fp32_lt = a[30:0] < b[30:0];
    end
  endfunction

  function [31:0] fp4_e2m1_to_fp32;
    input [3:0] value;
    begin
      case (value[2:0])
        3'b000: fp4_e2m1_to_fp32 = {value[3], 31'b0};
        3'b001: fp4_e2m1_to_fp32 = {value[3], 8'h7e, 23'b0};
        3'b010: fp4_e2m1_to_fp32 = {value[3], 8'h7f, 23'b0};
        3'b011: fp4_e2m1_to_fp32 = {value[3], 8'h7f, 1'b1, 22'b0};
        3'b100: fp4_e2m1_to_fp32 = {value[3], 8'h80, 23'b0};
        3'b101: fp4_e2m1_to_fp32 = {value[3], 8'h80, 1'b1, 22'b0};
        3'b110: fp4_e2m1_to_fp32 = {value[3], 8'h81, 23'b0};
        default: fp4_e2m1_to_fp32 = {value[3], 8'h81, 1'b1, 22'b0};
      endcase
    end
  endfunction

  function [3:0] fp32_to_fp4_e2m1_rne_satfinite;
    input [31:0] value;
    reg [30:0] magnitude;
    reg [2:0] code;
    begin
      magnitude = value[30:0];
      if ((value[30:23] == 8'hff) && (value[22:0] != 0)) begin
        fp32_to_fp4_e2m1_rne_satfinite = 4'b0000;
      end else begin
        if      (magnitude <= 31'h3e80_0000) code = 3'b000; // 0.25 -> even zero
        else if (magnitude <  31'h3f40_0000) code = 3'b001;
        else if (magnitude <= 31'h3fa0_0000) code = 3'b010;
        else if (magnitude <  31'h3fe0_0000) code = 3'b011;
        else if (magnitude <= 31'h4020_0000) code = 3'b100;
        else if (magnitude <  31'h4060_0000) code = 3'b101;
        else if (magnitude <= 31'h40a0_0000) code = 3'b110;
        else code = 3'b111;
        fp32_to_fp4_e2m1_rne_satfinite = {value[31], code};
      end
    end
  endfunction

  always @* begin
    result_d = {VALUE_WIDTH{1'b0}};
    result_domain_d = 1'b0;
    fflags_d = 5'b0;
    fpr_result = 32'b0;
    half_payload = half_resolved;
    equal = (misc_issue_fsrc0 == misc_issue_fsrc1) || (src0_zero && src1_zero);
    less_than = fp32_lt(misc_issue_fsrc0, misc_issue_fsrc1);
    case (misc_issue_op)
      OP_SGNJ: begin
        result_domain_d = 1'b1;
        case (misc_issue_funct3)
          3'b000: fpr_result = {misc_issue_fsrc1[31], misc_issue_fsrc0[30:0]};
          3'b001: fpr_result = {!misc_issue_fsrc1[31], misc_issue_fsrc0[30:0]};
          default: fpr_result = {misc_issue_fsrc0[31] ^ misc_issue_fsrc1[31], misc_issue_fsrc0[30:0]};
        endcase
        result_d = {{(VALUE_WIDTH-32){1'b0}}, fpr_result};
      end
      OP_MINMAX: begin
        result_domain_d = 1'b1;
        fflags_d[4] = src0_snan || src1_snan;
        if (src0_nan && src1_nan) fpr_result = 32'h7fc00000;
        else if (src0_nan) fpr_result = misc_issue_fsrc1;
        else if (src1_nan) fpr_result = misc_issue_fsrc0;
        else if (equal && src0_zero) begin
          if (misc_issue_funct3[0]) fpr_result = {misc_issue_fsrc0[31] & misc_issue_fsrc1[31], 31'b0};
          else fpr_result = {misc_issue_fsrc0[31] | misc_issue_fsrc1[31], 31'b0};
        end else if (misc_issue_funct3[0])
          fpr_result = less_than ? misc_issue_fsrc1 : misc_issue_fsrc0;
        else
          fpr_result = less_than ? misc_issue_fsrc0 : misc_issue_fsrc1;
        result_d = {{(VALUE_WIDTH-32){1'b0}}, fpr_result};
      end
      OP_CMP: begin
        fflags_d[4] = (misc_issue_funct3 == 3'b010) ? (src0_snan || src1_snan) : (src0_nan || src1_nan);
        if (src0_nan || src1_nan) result_d = 0;
        else case (misc_issue_funct3)
          3'b010: result_d = equal;
          3'b001: result_d = less_than;
          default: result_d = less_than || equal;
        endcase
      end
      OP_CLASS: begin
        if (misc_issue_fsrc0[30:23] == 8'hff)
          result_d = (misc_issue_fsrc0[22:0] == 0) ? (misc_issue_fsrc0[31] ? 10'b0000000001 : 10'b0010000000)
                                                   : (misc_issue_fsrc0[22] ? 10'b1000000000 : 10'b0100000000);
        else if (misc_issue_fsrc0[30:23] == 0)
          result_d = (misc_issue_fsrc0[22:0] == 0) ? (misc_issue_fsrc0[31] ? 10'b0000001000 : 10'b0000010000)
                                                   : (misc_issue_fsrc0[31] ? 10'b0000000100 : 10'b0000100000);
        else result_d = misc_issue_fsrc0[31] ? 10'b0000000010 : 10'b0001000000;
      end
      OP_MV_X_F: begin
        if (misc_issue_fmt == FMT_H)
          result_d = {{(VALUE_WIDTH-16){half_payload[15]}}, half_payload};
        else
          result_d = {{(VALUE_WIDTH-32){misc_issue_fsrc0[31]}}, misc_issue_fsrc0};
      end
      OP_MV_F_X: begin
        result_domain_d = 1'b1;
        fpr_result = (misc_issue_fmt == FMT_H) ?
                       fp16_to_fp32(misc_issue_gsrc0[15:0]) :
                       misc_issue_gsrc0[31:0];
        result_d = {{(VALUE_WIDTH-32){1'b0}}, fpr_result};
      end
      OP_MV_X_FP4: begin
        result_d = {{(VALUE_WIDTH-4){1'b0}},
                    fp32_to_fp4_e2m1_rne_satfinite(misc_issue_fsrc0)};
      end
      OP_MV_FP4_X: begin
        result_domain_d = 1'b1;
        fpr_result = fp4_e2m1_to_fp32(misc_issue_gsrc0[3:0]);
        result_d = {{(VALUE_WIDTH-32){1'b0}}, fpr_result};
      end
      default: begin end
    endcase
  end

  // Valid owns reset and bubbles. Payload/status/tags are only observable when
  // complete_valid is asserted and therefore need neither reset nor enable.
  always @(posedge forever_cpuclk or negedge cpurst_b) begin
    if (!cpurst_b) misc_complete_valid <= 1'b0;
    else misc_complete_valid <= misc_issue_valid && misc_issue_ready;
  end

  always @(posedge forever_cpuclk) begin
    misc_complete_seq_id <= misc_issue_seq_id;
    misc_complete_epoch <= misc_issue_epoch;
    misc_complete_rd <= misc_issue_rd;
    misc_complete_rd_bank <= misc_issue_rd_bank;
    misc_complete_domain <= result_domain_d;
    misc_complete_value <= result_d;
    misc_complete_fflags <= fflags_d;
  end
endmodule
