module edge_fpu_cvt #(
  parameter SEQ_ID_WIDTH = 8,
  parameter EPOCH_WIDTH = 4,
  parameter REG_INDEX_WIDTH = 5,
  parameter VALUE_WIDTH = 64,
  parameter GPR_WIDTH = VALUE_WIDTH
) (
  input wire forever_cpuclk, input wire cpurst_b,
  input wire cvt_issue_valid, output wire cvt_issue_ready,
  input wire [SEQ_ID_WIDTH-1:0] cvt_issue_seq_id,
  input wire [EPOCH_WIDTH-1:0] cvt_issue_epoch,
  input wire [1:0] cvt_issue_op,
  input wire [1:0] cvt_issue_int_type,
  input wire [2:0] cvt_issue_rm,
  input wire [REG_INDEX_WIDTH-1:0] cvt_issue_rd,
  input wire cvt_issue_rd_bank,
  input wire [31:0] cvt_issue_fsrc,
  input wire [GPR_WIDTH-1:0] cvt_issue_gsrc,
  output reg cvt_complete_valid,
  output reg [SEQ_ID_WIDTH-1:0] cvt_complete_seq_id,
  output reg [EPOCH_WIDTH-1:0] cvt_complete_epoch,
  output reg [REG_INDEX_WIDTH-1:0] cvt_complete_rd,
  output reg cvt_complete_rd_bank,
  output reg cvt_complete_domain,
  output reg [VALUE_WIDTH-1:0] cvt_complete_value,
  output reg [4:0] cvt_complete_fflags
);
  localparam [1:0] OP_F2F=0, OP_F2I=1, OP_I2F=2;
  // Low metadata bits: fsrc[31:0], NaN, input NV, integer sign, float sign,
  // rm[2:0], unsigned, word, op[1:0]. Upper bits are the destination tag.
  localparam META_WIDTH = 43 + SEQ_ID_WIDTH + EPOCH_WIDTH + REG_INDEX_WIDTH + 1;
  reg [META_WIDTH-1:0] meta_q [0:1];
  reg [1:0] valid_q;
  wire word_in = !cvt_issue_int_type[1];
  wire unsigned_in = cvt_issue_int_type[0];
  wire [63:0] gsrc64 = cvt_issue_gsrc;
  wire integer_sign = !unsigned_in && (word_in ? gsrc64[31] : gsrc64[63]);
  // Complete the two's-complement magnitude in parallel 32-bit pieces.
  // Carry into the high half of -x is exactly (x[31:0] == 0).
  wire [31:0] magnitude_low = integer_sign ? (~gsrc64[31:0]+32'd1) : gsrc64[31:0];
  wire magnitude_high_carry = !(|gsrc64[31:0]);
  wire [31:0] magnitude_high = word_in ? 32'b0 :
    ((!unsigned_in && gsrc64[63]) ? (~gsrc64[63:32]+{31'b0,magnitude_high_carry}) : gsrc64[63:32]);
  wire input_nan = (&cvt_issue_fsrc[30:23]) && (|cvt_issue_fsrc[22:0]);
  // Includes NaN/Inf and finite exponent overflow. Does not gate arithmetic.
  wire input_nv = cvt_issue_fsrc[30:23] > 8'd190;

  wire [23:0] sig_in = {|cvt_issue_fsrc[30:23],cvt_issue_fsrc[22:0]};
  wire [7:0] exp_in = (cvt_issue_fsrc[30:23]==0)?8'd1:cvt_issue_fsrc[30:23];
  reg [63:0] magnitude_q0, f2i_mag_q0, f2i_signed_q1;
  reg f2i_inc_q0, f2i_nx_q0, f2i_nx_q1, f2i_nv_q1;
  reg zero_q1;
  reg [23:0] fp_main_q1;
  reg fp_guard_q1, fp_sticky_q1;
  reg [7:0] fp_exp_q1;

  // Six balanced binary decisions, rather than a 64-entry priority chain.
  function [5:0] highest_bit;
    input [63:0] v;
    reg [31:0] a;
    reg [15:0] b;
    reg [7:0] c;
    reg [3:0] d;
    reg [1:0] e;
    begin
      highest_bit[5]=|v[63:32]; a=highest_bit[5]?v[63:32]:v[31:0];
      highest_bit[4]=|a[31:16]; b=highest_bit[4]?a[31:16]:a[15:0];
      highest_bit[3]=|b[15:8]; c=highest_bit[3]?b[15:8]:b[7:0];
      highest_bit[2]=|c[7:4]; d=highest_bit[2]?c[7:4]:c[3:0];
      highest_bit[1]=|d[3:2]; e=highest_bit[1]?d[3:2]:d[1:0];
      highest_bit[0]=e[1];
    end
  endfunction

  function [25:0] right_sticky;
    input [25:0] v;
    input [7:0] amount;
    reg [25:0] t;
    begin
      t=v;
      if(amount[0]) t={1'b0,t[25:2],|t[1:0]};
      if(amount[1]) t={2'b0,t[25:3],|t[2:0]};
      if(amount[2]) t={4'b0,t[25:5],|t[4:0]};
      if(amount[3]) t={8'b0,t[25:9],|t[8:0]};
      if(amount[4]) t={16'b0,t[25:17],|t[16:0]};
      right_sticky=(amount>=26)?{25'b0,|v}:t;
    end
  endfunction

  function round_increment;
    input [2:0] rm;
    input sign, lsb, guard_bit, sticky_bit;
    begin
      case(rm)
        3'd1: round_increment=0;
        3'd2: round_increment=sign && (guard_bit || sticky_bit);
        3'd3: round_increment=!sign && (guard_bit || sticky_bit);
        3'd4: round_increment=guard_bit;
        default: round_increment=guard_bit && (sticky_bit || lsb);
      endcase
    end
  endfunction

  wire f2i_left = exp_in >= 8'd150;
  wire [7:0] right_amount = 8'd150-exp_in;
  wire [5:0] left_amount = exp_in-8'd150;
  wire [25:0] f2i_shifted = right_sticky({sig_in,2'b0},right_amount);
  wire [63:0] f2i_mag = f2i_left ? ({40'b0,sig_in} << left_amount)
                                                : {40'b0,f2i_shifted[25:2]};
  wire f2i_guard = !f2i_left && f2i_shifted[1];
  wire f2i_sticky = !f2i_left && f2i_shifted[0];
  wire [5:0] msb = highest_bit(magnitude_q0);
  wire [63:0] fp_normalized = magnitude_q0 << (6'd63-msb);
  wire [63:0] f2i_rounded = f2i_mag_q0 + {{63{1'b0}},f2i_inc_q0};
  // -(m+inc) = ~m + !inc: rounding and negation share one carry chain.
  wire [63:0] f2i_signed = (meta_q[0][35] ? ~f2i_mag_q0 : f2i_mag_q0)
    + {{63{1'b0}},(meta_q[0][35] ? !f2i_inc_q0 : f2i_inc_q0)};
  wire fp_increment = round_increment(meta_q[1][38:36],meta_q[1][34],
                                     fp_main_q1[0],fp_guard_q1,fp_sticky_q1);
  wire [24:0] fp_rounded = {1'b0,fp_main_q1}+{{24{1'b0}},fp_increment};
  wire [7:0] fp_exp = fp_exp_q1+{7'b0,fp_rounded[24]};
  wire [31:0] fp_result = zero_q1 ? 32'b0 :
    {meta_q[1][34],fp_exp,fp_rounded[24]?fp_rounded[23:1]:fp_rounded[22:0]};

  // Range checks operate on the rounded finite candidate. NV has priority
  // over NX at the consumer; negative unsigned fractions may legally round to 0.
  wire finite_nv = meta_q[0][39]
    ? ((meta_q[0][35] && (|f2i_rounded)) ||
       (meta_q[0][40] && (|f2i_rounded[63:32])))
    : meta_q[0][40]
      ? ((|f2i_rounded[63:32]) ||
         (f2i_rounded[31] && (!meta_q[0][35] || (|f2i_rounded[30:0]))))
      : (f2i_rounded[63] && (!meta_q[0][35] || (|f2i_rounded[62:0])));
  wire [63:0] signed_limit = meta_q[1][40] ? 64'h80000000 : 64'h8000000000000000;
  wire [63:0] unsigned_limit = meta_q[1][40] ? 64'hffffffff : 64'hffffffffffffffff;
  wire saturation_negative = meta_q[1][35] && !meta_q[1][32];
  wire [63:0] saturated = meta_q[1][39]
    ? (saturation_negative ? 64'b0 : unsigned_limit)
    : (saturation_negative ? signed_limit : signed_limit-1'b1);
  wire invalid_result = meta_q[1][33] || f2i_nv_q1;
  wire [63:0] integer_result = invalid_result ? saturated : f2i_signed_q1;
  wire [63:0] word_result = meta_q[1][40]
    ? {{32{integer_result[31]}},integer_result[31:0]} : integer_result;

  assign cvt_issue_ready=1'b1;
  // Only validity resets. All payload is unspecified while complete_valid=0.
  always @(posedge forever_cpuclk or negedge cpurst_b) begin
    if(!cpurst_b) begin valid_q<=0; cvt_complete_valid<=0; end
    else begin
      valid_q<={valid_q[0],cvt_issue_valid};
      cvt_complete_valid<=valid_q[1];
    end
  end

  always @(posedge forever_cpuclk) begin
    // S1: I2F absolute value; F2I alignment and guard/sticky. Classify once.
    magnitude_q0<={magnitude_high,magnitude_low};
    f2i_mag_q0<=f2i_mag;
    f2i_inc_q0<=round_increment(cvt_issue_rm,cvt_issue_fsrc[31],
                                f2i_mag[0],f2i_guard,f2i_sticky);
    f2i_nx_q0<=f2i_guard || f2i_sticky;
    meta_q[0]<={cvt_issue_seq_id,cvt_issue_epoch,cvt_issue_rd,cvt_issue_rd_bank,
      cvt_issue_op,word_in,unsigned_in,cvt_issue_rm,cvt_issue_fsrc[31],
      integer_sign,input_nv,input_nan,cvt_issue_fsrc};
    meta_q[1]<=meta_q[0];
    // S2: I2F balanced priority encode/normalize; F2I round/sign/range.
    fp_main_q1<=fp_normalized[63:40];
    fp_guard_q1<=fp_normalized[39];
    fp_sticky_q1<=|fp_normalized[38:0];
    fp_exp_q1<=8'd127+{2'b0,msb};
    zero_q1<=!(|magnitude_q0);
    f2i_signed_q1<=f2i_signed;
    f2i_nv_q1<=finite_nv;
    f2i_nx_q1<=f2i_nx_q0;
    // S3: materialize semantic results only at the output boundary.
    {cvt_complete_seq_id,cvt_complete_epoch,cvt_complete_rd,cvt_complete_rd_bank}
      <=meta_q[1][META_WIDTH-1:43];
    cvt_complete_domain<=meta_q[1][42:41]!=OP_F2I;
    cvt_complete_value<=0;
    cvt_complete_fflags<=0;
    case(meta_q[1][42:41])
      OP_F2F: cvt_complete_value<=meta_q[1][31:0];
      OP_F2I: begin
        cvt_complete_value<=word_result;
        cvt_complete_fflags<=invalid_result ? 5'b10000 : {4'b0,f2i_nx_q1};
      end
      OP_I2F: begin
        cvt_complete_value<=fp_result;
        cvt_complete_fflags<={4'b0,fp_guard_q1 || fp_sticky_q1};
      end
      default: begin end
    endcase
  end
endmodule
