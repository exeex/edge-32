// GPR source-address lifetime and RAW backpressure owner.
module edge_32_gpr_read_port (
  input wire clk, reset_n, if_accept,
  input wire [4:0] if_rs1, if_rs2,
  input wire [1:0] uses_gpr,
  input wire ex_valid, ex_writes_gpr, input wire [4:0] ex_rd,
  input wire ex_forward_valid, input wire [31:0] ex_forward_value,
  output wire gpr_stall,
  output wire [31:0] read_value1, read_value2,
  input wire write_valid, input wire [4:0] write_rd,
  input wire [31:0] write_value, output wire [31:0] debug_x31
);
  // Resetless payload: ID validity masks canceled/stale read addresses.
  reg [4:0] id_rs1, id_rs2;
  // A ready fast EX producer is newer than committed WB data. Slow producers
  // retain RAW backpressure, including their completion cycle.
  wire ex_writer = ex_valid && ex_writes_gpr && (ex_rd != 0);
  wire match1 = ex_writer && uses_gpr[0] && (id_rs1 == ex_rd);
  wire match2 = ex_writer && uses_gpr[1] && (id_rs2 == ex_rd);
  assign gpr_stall = (match1 || match2) && !ex_forward_valid;
  wire [31:0] bank_value1, bank_value2;
  assign read_value1 = (match1 && ex_forward_valid) ? ex_forward_value : bank_value1;
  assign read_value2 = (match2 && ex_forward_valid) ? ex_forward_value : bank_value2;
  always @(posedge clk) if (if_accept) begin
    id_rs1 <= if_rs1; id_rs2 <= if_rs2;
  end
  edge_32_gpr bank (
    .clk(clk),.reset_n(reset_n),.read_rs1(id_rs1),.read_rs2(id_rs2),
    .read_value1(bank_value1),.read_value2(bank_value2),
    .write_valid(write_valid),.write_rd(write_rd),.write_value(write_value),
    .debug_x31(debug_x31));
endmodule
