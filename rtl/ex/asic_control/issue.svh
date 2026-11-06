// EX accelerator request/response wiring; started state stays with the EX slot.
  assign accel_req_valid=ex_issue_ok&&is_accel&&!accel_started_q;
  assign accel_req_inst=ex_inst[31:0];
  assign accel_req_src0={32'd0,ex_rs1_value};
  assign accel_req_src1={32'd0,ex_rs2_value};
    assign accel_req_fire=accel_req_valid&&accel_req_ready;
    assign accel_done=is_accel&&accel_started_q&&accel_resp_valid;
