module edge_fpu_fmac_narrow_fmadd(
  cpurst_b,
  forever_cpuclk,
  fmadd_cancel,
  fmadd_mul_only,
  fmadd_neg_product,
  fmadd_neg_addend,
  fmadd_rm,
  fmadd_src0,
  fmadd_src1,
  fmadd_src2,
  fmadd_result,
  fmadd_fflags
);

input           cpurst_b;
input           forever_cpuclk;
input           fmadd_cancel;
input           fmadd_mul_only;
input           fmadd_neg_product;
input           fmadd_neg_addend;
input   [2 :0]  fmadd_rm;
input   [31:0]  fmadd_src0;
input   [31:0]  fmadd_src1;
input   [31:0]  fmadd_src2;
output  [31:0]  fmadd_result;
output  [4 :0]  fmadd_fflags;


wire src0_sign, src0_zero, src0_inf, src0_qnan, src0_snan;
wire [23:0] src0_sig;
wire signed [12:0] src0_exp;
wire src1_sign, src1_zero, src1_inf, src1_qnan, src1_snan;
wire [23:0] src1_sig;
wire signed [12:0] src1_exp;
wire src2_sign, src2_zero, src2_inf, src2_qnan, src2_snan;
wire [23:0] src2_sig;
wire signed [12:0] src2_exp;
wire product_sign, addend_sign, any_snan, any_nan, inf_zero;
wire product_inf, inf_cancel, special_vld, special_fflags;
wire [1:0] special_result;
edge_fpu_fmac_fp32_unpack x_src0_unpack (
  .src       (fmadd_src0), .sign(src0_sign), .exp(src0_exp),
  .sig       (src0_sig), .zero(src0_zero), .subnormal(),
  .normal    (), .inf(src0_inf), .qnan(src0_qnan), .snan(src0_snan)
);

edge_fpu_fmac_fp32_unpack x_src1_unpack (
  .src       (fmadd_src1), .sign(src1_sign), .exp(src1_exp),
  .sig       (src1_sig), .zero(src1_zero), .subnormal(),
  .normal    (), .inf(src1_inf), .qnan(src1_qnan), .snan(src1_snan)
);

edge_fpu_fmac_fp32_unpack x_src2_unpack (
  .src       (fmadd_src2), .sign(src2_sign), .exp(src2_exp),
  .sig       (src2_sig), .zero(src2_zero), .subnormal(),
  .normal    (), .inf(src2_inf), .qnan(src2_qnan), .snan(src2_snan)
);

assign product_sign = src0_sign ^ src1_sign ^ fmadd_neg_product;
assign addend_sign = src2_sign ^ fmadd_neg_addend;
assign any_snan = src0_snan || src1_snan || src2_snan;
assign any_nan = any_snan
              || src0_qnan
              || src1_qnan
              || src2_qnan;
assign inf_zero = (src0_inf && src1_zero)
               || (src1_inf && src0_zero);
assign product_inf = (src0_inf || src1_inf)
                  && !inf_zero
                  && !any_nan;
assign inf_cancel = product_inf
                 && src2_inf
                 && (product_sign ^ addend_sign);


assign special_vld = any_nan
                  || inf_zero
                  || inf_cancel
                  || product_inf
                  || src2_inf;
// {is_nan, infinity_sign}; no materialized exceptional payload in flight.
assign special_result = {any_nan || inf_zero || inf_cancel,
                         product_inf ? product_sign : addend_sign};
assign special_fflags = any_snan || inf_zero || inf_cancel;

// Numerical transport and semantic action have separate register banks.
// Every numerical capture free-runs; only the parent owns validity.
wire signed [9:0] product_exp = $signed(src0_exp[9:0]) + $signed(src1_exp[9:0]);
reg [23:0] lhs_input_q, rhs_input_q;
reg [44:0] numeric_input_q;
reg [44:0] numeric_m0, numeric_m1;
wire product_sign_mul, addend_sign_mul;
wire signed [9:0] product_exp_mul;
wire [23:0] addend_sig_mul;
wire signed [8:0] addend_exp_mul;
assign {product_sign_mul, addend_sign_mul, product_exp_mul,
        addend_sig_mul, addend_exp_mul} = numeric_m1;
// Exact-zero sign is semantic. Rounded-to-zero nonzero values retain math sign.
wire zero_sign = fmadd_mul_only ? product_sign
               : (product_sign == addend_sign) ? product_sign
               : (fmadd_rm == 3'b010);
reg [7:0] action_input_q, action_m0, action_m1, action_a0, action_a1;
wire action_override, action_nan, action_sign, action_nv, action_zero_sign;
wire [2:0] result_rm;
assign {action_override, action_nan, action_sign, action_nv,
        action_zero_sign, result_rm} = action_a1;
always @(posedge forever_cpuclk) begin
  // Reuse the owning FMAC input capture for prepared values, not raw FP32.
  lhs_input_q <= src0_sig;
  rhs_input_q <= src1_sig;
  numeric_input_q <= {product_sign, addend_sign, product_exp, src2_sig, src2_exp[8:0]};
  action_input_q <= {special_vld, special_result, special_fflags, zero_sign, fmadd_rm};
  numeric_m0 <= numeric_input_q;
  numeric_m1 <= numeric_m0;
  action_m0 <= action_input_q;
  action_m1 <= action_m0;
  action_a0 <= action_m1;
  action_a1 <= action_a0;
end
wire [47:0] product;
edge_fpu_mul24x24_pipe2 #(.MASK_INVALID(0)) x_product (
  .clk(forever_cpuclk), .reset_n(cpurst_b), .cancel(fmadd_cancel),
  .lhs(lhs_input_q), .rhs(rhs_input_q), .product(product)
);
// Preserve every product bit; zero naturally multiplies to zero.
wire [52:0] product_sig = product[47] ? {product, 5'b0} : {product[46:0], 6'b0};
wire signed [12:0] product_biased_exp =
  {{3{product_exp_mul[9]}},product_exp_mul} + 13'sd127 + {12'b0,product[47]};
wire signed [12:0] addend_biased_exp =
  {{4{addend_exp_mul[8]}},addend_exp_mul} + 13'sd127;
wire math_zero, math_sign;
wire signed [12:0] math_exp;
wire [63:0] math_magnitude;
wire signed [7:0] math_pack_shift;
edge_fpu_fmac_align_add x_fused_align_add (
  .forever_cpuclk(forever_cpuclk),
  .op0_sign(product_sign_mul), .op0_exp(product_biased_exp), .op0_sig(product_sig),
  .op1_sign(addend_sign_mul), .op1_exp(addend_biased_exp), .op1_sig({addend_sig_mul,29'b0}),
  .add_zero(math_zero), .add_sign(math_sign), .add_exp(math_exp), .add_magnitude(math_magnitude), .add_pack_shift(math_pack_shift)
);
wire [31:0] numerical_result;
wire [4:0] numerical_fflags;
edge_fpu_fmac_fp32_fused_round_pack x_fused_round_pack (
  .sign(math_sign), .biased_exp(math_exp), .magnitude(math_magnitude), .pack_shift(math_pack_shift), .rm(result_rm),
  .result(numerical_result), .fflags(numerical_fflags)
);
// Semantic status never feeds the multiplier, aligner or add/subtract operands.
assign fmadd_result = action_override
  ? (action_nan ? 32'h7fc00000 : {action_sign,8'hff,23'b0})
  : math_zero ? {action_zero_sign,31'b0} : numerical_result;
assign fmadd_fflags = action_override ? {action_nv,4'b0}
                   : math_zero ? 5'b0 : numerical_fflags;
endmodule

// Unsigned significand multiplier: no truncation or rounding at this boundary.
module edge_fpu_mul24x24_pipe2 #(parameter MASK_INVALID = 1) (
  input wire clk, input wire reset_n, input wire cancel,
  input wire [23:0] lhs, input wire [23:0] rhs,
  output wire [47:0] product
);
  reg [31:0] partial0_q, partial1_q, partial2_q;
  reg [47:0] product_q;
  reg [1:0] live_q;
  // Only liveness is asynchronously reset. Numerical registers free-run so
  // FPGA DSP MREG can absorb the partial products. Two cleared liveness bits
  // prevent pre-reset/cancel payload from escaping, even for an off-edge reset.
  assign product = MASK_INVALID ? (live_q[1] ? product_q : 48'b0) : product_q;
  wire [47:0] p0 = {16'b0, partial0_q};
  wire [47:0] p1 = {8'b0, partial1_q, 8'b0};
  wire [47:0] p2 = {partial2_q, 16'b0};
  wire [47:0] sum = p0 ^ p1 ^ p2;
  wire [47:0] carry = ((p0 & p1) | (p0 & p2) | (p1 & p2)) << 1;
  always @(posedge clk or negedge reset_n) begin
    if (!reset_n) live_q <= 2'b0;
    else if (cancel) live_q <= 2'b0;
    else live_q <= {live_q[0], 1'b1};
  end
  always @(posedge clk) begin
    partial0_q <= lhs * rhs[7:0];
    partial1_q <= lhs * rhs[15:8];
    partial2_q <= lhs * rhs[23:16];
    product_q <= sum + carry;
  end
endmodule
