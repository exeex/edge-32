  // ID->EX issue needs EX capacity and only live ID operands can stall.
  assign id_can_advance = (!ex_valid || ex_release_ready) && (!id_valid || !id_stall);
    assign csr_interlock = id_valid && !id_error && id_csr_write;
  // IF->ID admission can fill an empty ID while EX remains occupied.
  assign if_capacity_ready = (!id_valid || id_can_advance) && !csr_interlock && !csr_serial_busy;
  assign if_ready = if_capacity_ready && !pipeline_kill;
  assign id_capture_enable = id_can_advance && !pipeline_kill;
  always @(posedge clk or negedge reset_n) begin
    if (!reset_n) id_valid <= 1'b0;
    else if (pipeline_kill) id_valid <= 1'b0;
    else if (if_capacity_ready || id_can_advance) id_valid <= if_valid && if_ready;
  end
  always @(posedge clk) begin
    if (if_id_fire) begin
      id_pc <= if_pc; id_inst <= if_inst; id_error <= if_error;
    end
  end
