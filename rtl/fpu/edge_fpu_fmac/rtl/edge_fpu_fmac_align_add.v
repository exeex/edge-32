// A0: complete alignment. A1: arithmetic plus normalization metadata.
// Payload free-runs; the parent owns validity and semantic actions.
module edge_fpu_fmac_align_add (
 input forever_cpuclk,
 input op0_sign, input signed [12:0] op0_exp, input [52:0] op0_sig,
 input op1_sign, input signed [12:0] op1_exp, input [52:0] op1_sig,
 output reg add_zero, output reg add_sign,
 output reg signed [12:0] add_exp,
 output reg [63:0] add_magnitude,
 output reg signed [7:0] add_pack_shift
);
wire same_sign, exp0_bigger, exp_equal, mag0_ge_mag1;
wire signed [12:0] exp_big;
wire [12:0] exp_diff;
wire [63:0] op0_ext, op1_ext, big_ext, small_ext, small_coarse;
reg same_sign_q, big_sign_q;
reg [63:0] big_q, small_aligned_q;
reg signed [12:0] exp_big_q;
function [63:0] rshift_sticky_coarse;
  input [63:0] value;
  input [10:0] coarse;
  begin
    case(coarse)
      11'd0:  rshift_sticky_coarse = value;
      11'd1:  rshift_sticky_coarse = {4'b0, value[63:5], value[4] | (|value[3:0])};
      11'd2:  rshift_sticky_coarse = {8'b0, value[63:9], value[8] | (|value[7:0])};
      11'd3:  rshift_sticky_coarse = {12'b0, value[63:13], value[12] | (|value[11:0])};
      11'd4:  rshift_sticky_coarse = {16'b0, value[63:17], value[16] | (|value[15:0])};
      11'd5:  rshift_sticky_coarse = {20'b0, value[63:21], value[20] | (|value[19:0])};
      11'd6:  rshift_sticky_coarse = {24'b0, value[63:25], value[24] | (|value[23:0])};
      11'd7:  rshift_sticky_coarse = {28'b0, value[63:29], value[28] | (|value[27:0])};
      11'd8:  rshift_sticky_coarse = {32'b0, value[63:33], value[32] | (|value[31:0])};
      11'd9:  rshift_sticky_coarse = {36'b0, value[63:37], value[36] | (|value[35:0])};
      11'd10: rshift_sticky_coarse = {40'b0, value[63:41], value[40] | (|value[39:0])};
      11'd11: rshift_sticky_coarse = {44'b0, value[63:45], value[44] | (|value[43:0])};
      11'd12: rshift_sticky_coarse = {48'b0, value[63:49], value[48] | (|value[47:0])};
      11'd13: rshift_sticky_coarse = {52'b0, value[63:53], value[52] | (|value[51:0])};
      11'd14: rshift_sticky_coarse = {56'b0, value[63:57], value[56] | (|value[55:0])};
      11'd15: rshift_sticky_coarse = {60'b0, value[63:61], value[60] | (|value[59:0])};
      default: rshift_sticky_coarse = {63'b0, |value};
    endcase
  end
endfunction

function [63:0] rshift_sticky_fine;
  input [63:0] value;
  input [1 :0] fine;
  begin
    case(fine[1:0])
      2'd0:    rshift_sticky_fine = value[63:0];
      2'd1:    rshift_sticky_fine = {1'b0, value[63:2],
                                     value[1] || value[0]};
      2'd2:    rshift_sticky_fine = {2'b0, value[63:3],
                                     value[2] || (|value[1:0])};
      2'd3:    rshift_sticky_fine = {3'b0, value[63:4],
                                     value[3] || (|value[2:0])};
      default: rshift_sticky_fine = {64{1'bx}};
    endcase
  end
endfunction


// Balanced 32/16/8/4/2/1 search; normalization targets bit 62.
// The ordered unsigned difference has bit 63 clear. For exact zero,
// shift/exponent metadata is unobservable behind the separate zero action.
function [5:0] leading_zero_count;
 input [63:0] value;
 reg [63:0] v;
 reg [5:0] count;
 begin
  v=value;count=0;
  if (!(|v[63:32])) begin count=count+6'd32;v=v<<32;end
  if (!(|v[63:48])) begin count=count+6'd16;v=v<<16;end
  if (!(|v[63:56])) begin count=count+6'd8;v=v<<8;end
  if (!(|v[63:60])) begin count=count+6'd4;v=v<<4;end
  if (!(|v[63:62])) begin count=count+6'd2;v=v<<2;end
  if (!v[63]) count=count+6'd1;
  leading_zero_count=count-6'd1;
 end
endfunction
assign same_sign = op0_sign == op1_sign;
assign exp0_bigger = op0_exp > op1_exp;
assign exp_equal = op0_exp == op1_exp;
// Zero has no magnitude irrespective of its transported exponent.
assign mag0_ge_mag1 = (|op0_sig) && (!(|op1_sig) || exp0_bigger
                   || (exp_equal && (op0_sig >= op1_sig)));
assign exp_big = mag0_ge_mag1 ? op0_exp : op1_exp;
assign exp_diff[12:0] = mag0_ge_mag1 ? op0_exp - op1_exp
                                      : op1_exp - op0_exp;

assign op0_ext[63:0] = {1'b0, op0_sig[52:0], 10'b0};
assign op1_ext[63:0] = {1'b0, op1_sig[52:0], 10'b0};
assign big_ext = mag0_ge_mag1 ? op0_ext : op1_ext;
assign small_ext = mag0_ge_mag1 ? op1_ext : op0_ext;
assign small_coarse = rshift_sticky_coarse(small_ext, exp_diff[12:2]);


always @(posedge forever_cpuclk) begin
 same_sign_q<=same_sign;
 big_sign_q<=mag0_ge_mag1 ? op0_sign : op1_sign;
 big_q<=big_ext;
 small_aligned_q<=rshift_sticky_fine(small_coarse,exp_diff[1:0]);
 exp_big_q<=exp_big;
end
wire [63:0] raw_add=big_q+small_aligned_q;
wire [63:0] raw_sub=big_q-small_aligned_q;
wire [5:0] lshift_amt=leading_zero_count(raw_sub);
wire signed [12:0] normalized_exp= same_sign_q
  ? exp_big_q+{12'b0,raw_add[63]} : exp_big_q-{7'b0,lshift_amt};
// For a normal result, shift magnitude down to 24+GRS bits. For a
// subnormal, LZ/carry adjustments cancel algebraically: 37 - base_exp.
wire signed [12:0] pack_shift=normalized_exp<=13'sd0
  ? 13'sd37-exp_big_q
  : same_sign_q ? 13'sd36+{12'b0,raw_add[63]}
                : 13'sd36-{7'b0,lshift_amt};
wire exact_zero= same_sign_q ? !(|big_q) && !(|small_aligned_q)
                             : big_q==small_aligned_q;
always @(posedge forever_cpuclk) begin
 add_zero<=exact_zero;
 add_sign<=big_sign_q;
 add_exp<=normalized_exp;
 add_magnitude<=same_sign_q ? raw_add : raw_sub;
 add_pack_shift<=pack_shift>=13'sd64 ? 8'sd64 : pack_shift[7:0];
end
endmodule
