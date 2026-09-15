// Included in edge_32_core; preserves the existing hardware hierarchy.
  edge_32_decode if_decode(
    .inst(if_inst),  .op_class(if_decoded_class),
    .legal(if_decoded_legal), .rd(), .rs1(), .rs2(),
    .writes_gpr(), .accel_subop(),
    .accel_needs_capture(), .accel_capture_src_gpr());
