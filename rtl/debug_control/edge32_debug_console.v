// Nonblocking putchar sink. A full queue drops the newest byte; loss is sticky.
module edge32_debug_console #(parameter DEPTH=64)(
  input wire clk, reset_n,
  input wire putchar_valid,
  input wire [7:0] putchar_char,
  input wire pop, clear_overflow,
  output wire [31:0] status,
  output wire [31:0] data
);
  localparam PTR_WIDTH=$clog2(DEPTH), COUNT_WIDTH=$clog2(DEPTH+1);
  reg [7:0] bytes_q[0:DEPTH-1];
  reg [PTR_WIDTH-1:0] read_q, write_q;
  reg [COUNT_WIDTH-1:0] count_q;
  reg overflow_q;
  wire empty=count_q==0, full=count_q==DEPTH;
  wire take=pop && !empty;
  wire push=putchar_valid && (!full || take);
  wire [7:0] count8=count_q;
  localparam [15:0] CAPACITY=DEPTH;
  assign status={CAPACITY,count8,5'd0,overflow_q,full,!empty};
  assign data=empty?32'd0:{23'd0,1'b1,bytes_q[read_q]};
  always @(posedge clk) begin
    if(!reset_n) begin read_q<=0;write_q<=0;count_q<=0;overflow_q<=0;end
    else begin
      if(clear_overflow)overflow_q<=0;
      if(putchar_valid && !push)overflow_q<=1; // new loss wins over software clear
      if(push)begin
        bytes_q[write_q]<=putchar_char;
        write_q<=write_q==DEPTH-1?0:write_q+1'b1;
      end
      if(take)read_q<=read_q==DEPTH-1?0:read_q+1'b1;
      case({push,take})
        2'b10: count_q<=count_q+1'b1;
        2'b01: count_q<=count_q-1'b1;
        default: begin end
      endcase
    end
  end
  initial if(DEPTH<2 || DEPTH>255)$error("console DEPTH must be 2..255");
endmodule
