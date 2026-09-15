// Included in edge_32_core; preserves the existing hardware hierarchy.
  edge_32_pipeline #(.PC_WIDTH(PC_WIDTH),.VALUE_WIDTH(32)) pipeline(
    .clk(clk),.reset_n(reset_n),
    .fetch_valid(if_valid),.fetch_ready(if_ready),
    .fetch_capacity_ready(if_capacity_ready),.fetch_pc(if_pc),
    .fetch_inst(if_inst),.fetch_error(if_error),
    .id_valid(),.id_capture_enable(id_capture_enable),.id_pc(), .id_inst(id_inst),
    .id_error(id_error),
    .id_rs1_value(id_uses_gpr[0] ? id_rs1_value : 32'd0),
    .id_rs2_value(id_uses_gpr[1] ? id_rs2_value : 32'd0),.ex_valid(ex_valid),
    .id_legal(id_issue_legal),
    .id_csr_write(id_csr_write),.id_stall(id_stall),
    .ex_pc(ex_pc),.ex_inst(ex_inst),.ex_error(ex_error),
    .ex_rs1_value(ex_rs1_value),.ex_rs2_value(ex_rs2_value),.ex_done(ex_release_ready),
    .ex_legal(decoded_legal),
    .ex_redirect_valid(redirect||terminal_complete||wb_terminal||halted||core_start_i||
                       core_force_stop_i));

