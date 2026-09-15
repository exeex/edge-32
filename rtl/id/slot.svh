    assign id_can_advance = !(ex_valid && !ex_release_ready) && !id_stall;
    assign csr_interlock = id_valid && !id_error && id_csr_write;
  assign if_capacity_ready = id_can_advance && !csr_interlock;
  assign if_ready = if_capacity_ready && !pipeline_kill;
  assign id_capture_enable = id_can_advance && !pipeline_kill;
  always @(posedge clk or negedge reset_n) begin
    if (!reset_n) id_valid <= 1'b0;
    else if (pipeline_kill) id_valid <= 1'b0;
    else if (id_can_advance) id_valid <= if_valid && if_ready;
  end
  always @(posedge clk) begin
    if (id_capture_enable && if_valid && if_ready) begin
      id_pc <= if_pc; id_inst <= if_inst; id_error <= if_error;
    end
  end
