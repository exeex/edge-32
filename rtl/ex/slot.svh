  always @(posedge clk or negedge reset_n) begin
    if (!reset_n) ex_valid <= 1'b0;
    else if (pipeline_kill) ex_valid <= 1'b0;
    else if (!(ex_valid && !ex_release_ready))
      ex_valid <= id_capture_enable && id_valid;
  end
  always @(posedge clk) begin
    if (id_capture_enable) begin
      ex_pc <= id_pc; ex_inst <= id_inst;
      ex_rs1_value <= id_uses_gpr[0] ? id_rs1_value : 32'd0;
      ex_rs2_value <= id_uses_gpr[1] ? id_rs2_value : 32'd0;
    end
  end

  // Delay instret observation until an older WB slot has retired and the
  // independent counter has updated. No live WB-to-result increment bypass.
  // Every new EX slot initializes this payload; ex_valid masks reset/kill.
  reg instret_read_ready_q;
  always @(posedge clk) begin
    if (id_capture_enable) instret_read_ready_q <= 1'b0;
    else instret_read_ready_q <= 1'b1;
  end
