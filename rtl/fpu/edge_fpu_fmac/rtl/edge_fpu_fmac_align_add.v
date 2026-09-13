// A0: complete alignment. A1: arithmetic plus normalization metadata.
// Payload free-runs; the parent owns validity and semantic actions.
module edge_fpu_fmac_align_add (
 input forever_cpuclk,
 input op0_sign, input signed [12:0] op0_exp, input [52:0] op0_sig,
 input op1_sign, input signed [12:0] op1_exp, input [52:0] op1_sig,
 input subtract_in,
 input [52:0] op0_sig_complement, op1_sig_complement,
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
// Numerical metadata computed in parallel with A0 alignment.
wire signed [12:0] subnormal_shift = 13'sd37-exp_big;
reg signed [7:0] subnormal_shift_q;
// In the complemented domain a right shift fills ones and jams discarded
// bits with AND: J_inv(~x) == ~J(x). Complement is prepared in M1.
function [63:0] rshift_sticky_coarse;
 input [63:0] value;
 input [10:0] amount;
 input inverted;
 begin
 case(amount)
 11'd0: rshift_sticky_coarse = value;
 11'd1: rshift_sticky_coarse = {{4{inverted}}, value[63:5], (inverted ? (&value[4:0]) : (|value[4:0]))};
 11'd2: rshift_sticky_coarse = {{8{inverted}}, value[63:9], (inverted ? (&value[8:0]) : (|value[8:0]))};
 11'd3: rshift_sticky_coarse = {{12{inverted}}, value[63:13], (inverted ? (&value[12:0]) : (|value[12:0]))};
 11'd4: rshift_sticky_coarse = {{16{inverted}}, value[63:17], (inverted ? (&value[16:0]) : (|value[16:0]))};
 11'd5: rshift_sticky_coarse = {{20{inverted}}, value[63:21], (inverted ? (&value[20:0]) : (|value[20:0]))};
 11'd6: rshift_sticky_coarse = {{24{inverted}}, value[63:25], (inverted ? (&value[24:0]) : (|value[24:0]))};
 11'd7: rshift_sticky_coarse = {{28{inverted}}, value[63:29], (inverted ? (&value[28:0]) : (|value[28:0]))};
 11'd8: rshift_sticky_coarse = {{32{inverted}}, value[63:33], (inverted ? (&value[32:0]) : (|value[32:0]))};
 11'd9: rshift_sticky_coarse = {{36{inverted}}, value[63:37], (inverted ? (&value[36:0]) : (|value[36:0]))};
 11'd10: rshift_sticky_coarse = {{40{inverted}}, value[63:41], (inverted ? (&value[40:0]) : (|value[40:0]))};
 11'd11: rshift_sticky_coarse = {{44{inverted}}, value[63:45], (inverted ? (&value[44:0]) : (|value[44:0]))};
 11'd12: rshift_sticky_coarse = {{48{inverted}}, value[63:49], (inverted ? (&value[48:0]) : (|value[48:0]))};
 11'd13: rshift_sticky_coarse = {{52{inverted}}, value[63:53], (inverted ? (&value[52:0]) : (|value[52:0]))};
 11'd14: rshift_sticky_coarse = {{56{inverted}}, value[63:57], (inverted ? (&value[56:0]) : (|value[56:0]))};
 11'd15: rshift_sticky_coarse = {{60{inverted}}, value[63:61], (inverted ? (&value[60:0]) : (|value[60:0]))};
 default: rshift_sticky_coarse = {{63{inverted}}, (inverted ? (&value) : (|value))};
 endcase
 end
endfunction

function [63:0] rshift_sticky_fine;
 input [63:0] value;
 input [1:0] amount;
 input inverted;
 begin
 case(amount)
 2'd0: rshift_sticky_fine = value;
 2'd1: rshift_sticky_fine = {{1{inverted}}, value[63:2], (inverted ? (&value[1:0]) : (|value[1:0]))};
 2'd2: rshift_sticky_fine = {{2{inverted}}, value[63:3], (inverted ? (&value[2:0]) : (|value[2:0]))};
 2'd3: rshift_sticky_fine = {{3{inverted}}, value[63:4], (inverted ? (&value[3:0]) : (|value[3:0]))};
 default: rshift_sticky_fine = {{63{inverted}}, (inverted ? (&value) : (|value))};
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
assign same_sign = !subtract_in;
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
wire [63:0] op0_inverse_ext = {1'b1,op0_sig_complement,10'h3ff};
wire [63:0] op1_inverse_ext = {1'b1,op1_sig_complement,10'h3ff};
assign small_ext = subtract_in
 ? (mag0_ge_mag1 ? op1_inverse_ext : op0_inverse_ext)
 : (mag0_ge_mag1 ? op1_ext : op0_ext);
assign small_coarse = rshift_sticky_coarse(small_ext, exp_diff[12:2],subtract_in);


always @(posedge forever_cpuclk) begin
 same_sign_q<=same_sign;
 big_sign_q<=mag0_ge_mag1 ? op0_sign : op1_sign;
 big_q<=big_ext;
 small_aligned_q<=rshift_sticky_fine(small_coarse,exp_diff[1:0],subtract_in);
 exp_big_q<=exp_big;
 // Only used for subnormal results; positive-range shifts saturate at 64.
 subnormal_shift_q <= subnormal_shift>=13'sd64 ? 8'sd64 : subnormal_shift[7:0];
end
// One shared magnitude adder; complement is already aligned and captured.
wire [63:0] raw_sum=big_q+small_aligned_q+{63'b0,!same_sign_q};
wire [5:0] lshift_amt=leading_zero_count(raw_sum);
wire signed [12:0] normalized_exp= same_sign_q
  ? exp_big_q+{12'b0,raw_sum[63]} : exp_big_q-{7'b0,lshift_amt};
// For a normal result, shift magnitude down to 24+GRS bits. For a
// subnormal, LZ/carry adjustments cancel algebraically: 37 - base_exp.
// Compare in parallel with normalized_exp, avoiding subtract -> compare.
wire result_subnormal = same_sign_q
  ? (exp_big_q < 13'sd0 || (exp_big_q == 13'sd0 && !raw_sum[63]))
  : exp_big_q <= $signed({7'b0,lshift_amt});
wire signed [7:0] normal_shift = same_sign_q
  ? 8'sd36+{7'b0,raw_sum[63]} : 8'sd36-$signed({2'b0,lshift_amt});
wire signed [7:0] pack_shift = result_subnormal ? subnormal_shift_q : normal_shift;
wire exact_zero= same_sign_q ? !(|big_q) && !(|small_aligned_q)
                             : big_q==~small_aligned_q;
always @(posedge forever_cpuclk) begin
 add_zero<=exact_zero;
 add_sign<=big_sign_q;
 add_exp<=normalized_exp;
 add_magnitude<=raw_sum;
 add_pack_shift<=pack_shift;
end
endmodule
