// Maintained radix-4 restoring divider. Each digit keeps 0 <= remainder < D.
// Three candidate subtracts run in parallel; the 3D decision selects last.
module edge32_div_nonnegative (
  input wire clk, reset_n, op_valid,
  output wire op_ready,
  input wire [31:0] src0, src1,
  input wire [2:0] funct3,
  output reg result_valid,
  output reg [31:0] result_value,
  output wire busy
);
  localparam IDLE=0, PREP=1, ITER=2, SIGN=3;
  reg [1:0] state;
  reg [31:0] dividend, divisor, remainder;
  reg [33:0] divisor3;
  reg [4:0] rounds;
  reg rem_op, negative, zero_divisor;
  reg [31:0] zero_value;
  // a - ~b - 1 = a + b; reuse the short borrow-prefix structure for 3D.
  wire [34:0] prepared_divisor3;
  edge32_sub34_prefix #(.BORROW_IN(1)) prepare_d3(
    {1'b0,divisor,1'b0}, ~{2'b0,divisor}, prepared_divisor3);
  wire [33:0] trial = {remainder, dividend[31:30]};
  wire [34:0] sub1, sub2, sub3;
  edge32_sub34_prefix sub_d1(trial, {2'b0,divisor}, sub1);
  edge32_sub34_prefix sub_d2(trial, {1'b0,divisor,1'b0}, sub2);
  edge32_sub34_prefix sub_d3(trial, divisor3, sub3);
  wire [31:0] rem012 = !sub2[34] ? sub2[31:0] :
                          !sub1[34] ? sub1[31:0] : trial[31:0];
  wire [1:0] q012 = !sub2[34] ? 2'd2 : !sub1[34] ? 2'd1 : 2'd0;
  wire [31:0] rem_next = !sub3[34] ? sub3[31:0] : rem012;
  wire [1:0] digit = !sub3[34] ? 2'd3 : q012;
  wire [31:0] magnitude = rem_op ? remainder : dividend;
  assign op_ready = state==IDLE && !result_valid;
  assign busy = state!=IDLE || result_valid;
  always @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin state<=IDLE; result_valid<=0; end
    else begin
      result_valid<=0;
      case(state)
        IDLE: if(op_valid && op_ready) state<=PREP;
        PREP: state<=(zero_divisor || dividend<=divisor) ? SIGN : ITER;
        ITER: if(rounds==1) state<=SIGN;
        SIGN: begin state<=IDLE; result_valid<=1; end
      endcase
    end
  end
  always @(posedge clk) begin
    if(state==IDLE && op_valid && op_ready) begin
      dividend<=!funct3[0] && src0[31] ? -src0 : src0;
      divisor<=!funct3[0] && src1[31] ? -src1 : src1;
      rem_op<=funct3[1];
      negative<=!funct3[0] && (funct3[1] ? src0[31] : src0[31]^src1[31]);
      zero_divisor<=src1==0;
      zero_value<=funct3[1] ? src0 : 32'hffffffff;
    end
    if(state==PREP) begin
      divisor3<=prepared_divisor3[33:0];
      rounds<=16;
      remainder<=dividend<divisor ? dividend : 0;
      if(dividend<=divisor) dividend<=dividend==divisor ? 1 : 0;
    end
    if(state==ITER) begin
      remainder<=rem_next;
      dividend<={dividend[29:0],digit};
      rounds<=rounds-1'b1;
    end
    if(state==SIGN)
      result_value<=zero_divisor ? zero_value : negative ? -magnitude : magnitude;
  end
endmodule

// Local sums speculate borrow-in; hierarchy prevents a wide ripple remap.
(* keep_hierarchy = "yes" *)
module edge32_sub_chunk #(parameter W=8)(
  input wire [W-1:0] a,b, input wire borrow_in,
  output wire [W-1:0] difference, output wire generate_borrow, propagate_borrow
);
  wire [W-1:0] d0=a-b;
  wire [W-1:0] d1=a-b-1'b1;
  assign difference=borrow_in ? d1 : d0;
  assign generate_borrow=a<b;
  assign propagate_borrow=a==b;
endmodule

(* keep_hierarchy = "yes" *)
module edge32_sub34_prefix #(parameter BORROW_IN=0)(input wire [33:0] a,b, output wire [34:0] difference);
  wire [4:0] g,p;
  wire [4:0] g1,p1,g2,p2,g4;
  wire [4:0] borrow_in;
  assign g1=g | (p & (g<<1));
  assign p1=p & (p<<1);
  assign g2=g1 | (p1 & (g1<<2));
  assign p2=p1 & (p1<<2);
  assign g4=g2 | (p2 & (g2<<4));
  assign borrow_in[0]=BORROW_IN;
  genvar j;
  generate for(j=1;j<5;j=j+1) begin: borrow_prefix
    assign borrow_in[j]=g4[j-1] | (BORROW_IN && (&p[j-1:0]));
  end endgenerate
  genvar i;
  generate for(i=0;i<4;i=i+1) begin: chunks
    edge32_sub_chunk slice(a[i*8+:8],b[i*8+:8],borrow_in[i],difference[i*8+:8],g[i],p[i]);
  end endgenerate
  edge32_sub_chunk #(.W(2)) high(a[33:32],b[33:32],borrow_in[4],difference[33:32],g[4],p[4]);
  assign difference[34]=g4[4] | (BORROW_IN && (&p));
endmodule
