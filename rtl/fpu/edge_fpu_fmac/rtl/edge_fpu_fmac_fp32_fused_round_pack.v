// Finish the A1 unfinished magnitude packet with one combined shift/RNE.
module edge_fpu_fmac_fp32_fused_round_pack(
 input sign,
 input signed [12:0] base_exp,
 input norm_subtract,
 input [5:0] norm_adjust,
 input [63:0] magnitude,
 input signed [7:0] pack_shift,
 input [2:0] rm,
 output [31:0] result,
 output [4:0] fflags
);
// Numerical exponent path runs parallel to magnitude shifting/GRS generation.
wire signed [12:0] biased_exp = norm_subtract
 ? base_exp - $signed({7'b0,norm_adjust})
 : base_exp + $signed({7'b0,norm_adjust});
wire [63:0] shifted_right=magnitude >> pack_shift[6:0];
wire [63:0] discarded_mask=~(64'hffffffffffffffff << pack_shift[6:0]);
wire [26:0] right_grs=pack_shift>=8'sd64 ? {26'b0,|magnitude}
 : {shifted_right[26:1],shifted_right[0] | (|(magnitude & discarded_mask))};
wire [7:0] left_shift=-pack_shift;
wire [63:0] shifted_left=magnitude << left_shift[5:0];
wire [26:0] rounded_sig=pack_shift<0 ? shifted_left[26:0] : right_grs;
wire [23:0] main=rounded_sig[26:3];
wire guard_bit=rounded_sig[2];
wire round_bit=rounded_sig[1];
wire sticky_bit=rounded_sig[0];
wire inexact=guard_bit || round_bit || sticky_bit;
wire rne = rm == 3'b000;
wire rmm = rm == 3'b100;
wire rdn = rm == 3'b010;
wire rup = rm == 3'b011;
wire increment = (rne && guard_bit && (round_bit || sticky_bit || main[0]))
               || (rmm && guard_bit)
               || (rup && !sign && inexact)
               || (rdn && sign && inexact);
wire [24:0] rounded = {1'b0, main} + {{24{1'b0}}, increment};
wire carry = rounded[24];
wire [7:0] out_exp = biased_exp[7:0] + {{7{1'b0}}, carry};
wire exact_zero = !(|magnitude);
wire overflow = (biased_exp >= 13'sd255)
             || ((biased_exp == 13'sd254) && carry);
wire subnormal_to_normal = (biased_exp <= 13'sd0) && rounded[23];
wire underflow = !overflow && !exact_zero && inexact
              && (biased_exp <= 13'sd0) && !subnormal_to_normal;
wire round_to_inf = rne || rmm || (rup && !sign) || (rdn && sign);
wire [31:0] finite_result = biased_exp > 13'sd0
                          ? {sign, out_exp,
                             carry ? rounded[23:1] : rounded[22:0]}
                          : {sign, subnormal_to_normal ? 8'd1 : 8'd0,
                             rounded[22:0]};

assign result = overflow
              ? (round_to_inf ? {sign, 8'hff, 23'b0}
                                : {sign, 8'hfe, 23'h7f_ffff})
              : finite_result;
assign fflags = {1'b0, 1'b0, overflow, underflow,
                 overflow || inexact};

endmodule
