// GPR source-address lifetime and RAW backpressure owner.
module edge_32_gpr_read_port (
  input wire clk, reset_n, if_accept,
  input wire [4:0] if_rs1, if_rs2,
  input wire [1:0] uses_gpr,
  input wire ex_valid, ex_writes_gpr, input wire [4:0] ex_rd,
  output wire gpr_stall,
  output wire [31:0] read_value1, read_value2,
  input wire write_valid, input wire [4:0] write_rd,
  input wire [31:0] write_value, output wire [31:0] debug_x31
);
  // Resetless payload: ID validity masks canceled/stale read addresses.
  reg [4:0] id_rs1, id_rs2;
  // EX cannot bypass the registered WB boundary, including its completion cycle.
  assign gpr_stall = ex_valid && ex_writes_gpr && (ex_rd != 0) &&
    ((uses_gpr[0] && id_rs1 == ex_rd) || (uses_gpr[1] && id_rs2 == ex_rd));
  always @(posedge clk) if (if_accept) begin
    id_rs1 <= if_rs1; id_rs2 <= if_rs2;
  end
  edge_32_gpr bank (
    .clk(clk),.reset_n(reset_n),.read_rs1(id_rs1),.read_rs2(id_rs2),
    .read_value1(read_value1),.read_value2(read_value2),
    .write_valid(write_valid),.write_rd(write_rd),.write_value(write_value),
    .debug_x31(debug_x31));
endmodule
