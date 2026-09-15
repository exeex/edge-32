// Implementation owned by this stage module.
  edge_32_gpr gpr_file(
    .clk(clk),.reset_n(reset_n),.read_rs1(id_rs1),.read_rs2(id_rs2),
    .read_value1(id_rs1_value),.read_value2(id_rs2_value),
    .write_valid(wb_valid),.write_rd(wb_rd_q),.write_value(wb_value_q),
    .debug_x31(gpr_debug_x31));

