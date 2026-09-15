  always @(posedge clk or negedge reset_n) begin
    if (!reset_n) ex_valid <= 1'b0;
    else if (pipeline_kill) ex_valid <= 1'b0;
    else if (!(ex_valid && !ex_release_ready))
      ex_valid <= id_capture_enable && id_valid;
  end
  always @(posedge clk) begin
    if (id_capture_enable) begin
      ex_pc <= id_pc; ex_inst <= id_inst; ex_error <= id_error;
      ex_rs1_value <= id_uses_gpr[0] ? id_rs1_value : 32'd0;
      ex_rs2_value <= id_uses_gpr[1] ? id_rs2_value : 32'd0;
      decoded_legal <= id_issue_legal;
    end
  end
