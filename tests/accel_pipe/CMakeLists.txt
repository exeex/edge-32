set(edge_accel_pipe_build_dir "${CMAKE_CURRENT_BINARY_DIR}")
set(edge_accel_pipe_rtl "${EDGE_ROOT}/src/edge-32/rtl/edge_accel_pipe.v")
set(edge_accel_pipe_decode_tb "${CMAKE_CURRENT_LIST_DIR}/edge_accel_pipe_decode_tb.v")
set(edge_accel_pipe_actu_unit_tb "${CMAKE_CURRENT_LIST_DIR}/edge_accel_pipe_actu_unit_tb.v")
set(edge_accel_pipe_stream_shell_tb "${CMAKE_CURRENT_LIST_DIR}/edge_accel_pipe_stream_shell_tb.v")
set(edge_accel_queue_bridge_tb "${CMAKE_CURRENT_LIST_DIR}/edge_accel_queue_bridge_tb.v")
set(edge_accel_cmd_queue_rtl "${EDGE_ROOT}/src/edge-e3/edge_accel_cmd_queue/edge_accel_cmd_queue.v")
set(edge_actu_unit_rtl "${EDGE_ROOT}/src/edge-e3/edge_actu/rtl/edge_actu_unit.v")
set(edge_actu_bf16_stream_rtl "${EDGE_ROOT}/src/edge-e3/edge_actu/rtl/edge_actu_bf16_stream.v")
set(edge_accel_io_rtl "${EDGE_ROOT}/src/edge-e3/edge_accel_io/edge_accel_io.v")
set(edge_accel_core_mux_rtl "${EDGE_ROOT}/src/edge-e3/edge_accel_io/edge_accel_core_mux.v")
set(edge_accel_io_unit_rtl "${EDGE_ROOT}/src/edge-e3/edge_accel_io/edge_accel_io_unit.v")
set(edge_accel_unit_rtl "${EDGE_ROOT}/src/edge-e3/edge_accel_io/edge_accel_unit.v")
set(edge_cmpu_rtl "${EDGE_ROOT}/src/edge-e3/edge_cmpu/edge_cmpu.v")
set(edge_cmpu_relation_rtl "${EDGE_ROOT}/src/edge-e3/edge_cmpu/rtl/edge_cmpu_bf16_relation.v")
set(edge_actu_rtl "${EDGE_ROOT}/src/edge-e3/edge_actu/edge_actu.v")
set(edge_actu_exp_lut_rtl "${EDGE_ROOT}/src/edge-e3/edge_actu/rtl/edge_actu_exp_lut2base_split.v")
set(edge_actu_exp2_core_rtl "${EDGE_ROOT}/src/edge-e3/edge_actu/rtl/edge_actu_exp2_split_core.v")
set(edge_actu_exp2_pack_q28_rtl "${EDGE_ROOT}/src/edge-e3/edge_actu/rtl/edge_actu_exp2_pack_q28_fp32.v")
set(edge_actu_exp2_pack_rtl "${EDGE_ROOT}/src/edge-e3/edge_actu/rtl/edge_actu_exp2_pack_fp32.v")
set(edge_actu_exp2_split_rtl "${EDGE_ROOT}/src/edge-e3/edge_actu/rtl/edge_actu_exp2_split_mant_q14.v")
set(edge_actu_exp_range_rtl "${EDGE_ROOT}/src/edge-e3/edge_actu/rtl/edge_actu_exp_range_q16.v")
set(edge_actu_rcp_lut_rtl "${EDGE_ROOT}/src/edge-e3/edge_actu/rtl/edge_actu_rcp_lut_nr_fp32.v")
set(edge_actu_rcp_rsqrt_seed_rtl "${EDGE_ROOT}/src/edge-e3/edge_actu/rtl/edge_actu_rcp_rsqrt_seed_q16.v")
set(edge_actu_rcp_rsqrt_pipe_rtl "${EDGE_ROOT}/src/edge-e3/edge_actu/rtl/edge_actu_rcp_rsqrt_pipe.v")
set(edge_actu_rcp_seed_rtl "${EDGE_ROOT}/src/edge-e3/edge_actu/rtl/edge_actu_rcp_radix16_seed.v")
set(edge_actu_rcp_nr_rtl "${EDGE_ROOT}/src/edge-e3/edge_actu/rtl/edge_actu_rcp_one_to_two_q16.v")
set(edge_accel_pipe_stream_shell_rtl
  "${EDGE_ROOT}/src/edge-e3/edge_tensor_unit/edge_tensor_unit.v"
  "${EDGE_ROOT}/src/edge-e3/edge_tensor_unit/rtl/edge_tensor_iopsum_remux.v"
  "${EDGE_ROOT}/src/edge-e3/edge_tensor_unit/rtl/ref/wld8x8/edge_tensor_wld_reg.v"
  "${EDGE_ROOT}/src/edge-e3/edge_tensor_unit/rtl/edge_tensor_wld8x8_fill.v"
  "${EDGE_ROOT}/src/edge-asic/rtl/tensor/edge_bf16_sig_mul.v"
  "${EDGE_ROOT}/src/edge-asic/rtl/tensor/edge_dot8_kernel.v"
  "${EDGE_ROOT}/src/edge-e3/edge_tensor_unit/rtl/compute/edge_dot8_unit.v"
  "${EDGE_ROOT}/src/edge-asic/rtl/tensor/edge_psum.v"
  "${EDGE_ROOT}/src/edge-e3/edge_tensor_unit/rtl/compute/edge_tile8x8_unit.v"
)

edge_add_verilator_hardware_test(
  NAME edge_accel_pipe_actu_unit
  TOP edge_accel_pipe_actu_unit_tb
  WORK_DIR "${edge_accel_pipe_build_dir}"
  PASS_PATTERN "EDGE_ACCEL_PIPE_ACTU_UNIT TEST PASS"
  LABELS "dualstream;edge_accel_pipe;edge_actu;activation"
  VERILATOR_ARGS --sv
  SOURCES
    "${edge_accel_pipe_actu_unit_tb}"
    "${edge_accel_pipe_rtl}"
    "${edge_actu_unit_rtl}"
    "${edge_accel_unit_rtl}"
    "${edge_accel_io_unit_rtl}"
    "${edge_accel_io_rtl}"
    "${edge_accel_core_mux_rtl}"
    "${edge_cmpu_rtl}"
    "${edge_cmpu_relation_rtl}"
    "${edge_actu_bf16_stream_rtl}"
    "${edge_actu_rtl}"
    "${edge_actu_exp_lut_rtl}"
    "${edge_actu_exp_range_rtl}"
    "${edge_actu_exp2_core_rtl}"
    "${edge_actu_exp2_split_rtl}"
    "${edge_actu_exp2_pack_q28_rtl}"
    "${edge_actu_exp2_pack_rtl}"
    "${edge_actu_rcp_lut_rtl}"
    "${edge_actu_rcp_rsqrt_seed_rtl}"
    "${edge_actu_rcp_rsqrt_pipe_rtl}"
    "${edge_actu_rcp_nr_rtl}"
    "${edge_actu_rcp_seed_rtl}"
)

edge_add_verilator_hardware_test(
  NAME edge_accel_queue_bridge
  TOP edge_accel_queue_bridge_tb
  WORK_DIR "${edge_accel_pipe_build_dir}"
  PASS_PATTERN "EDGE_ACCEL_QUEUE_BRIDGE TEST PASS"
  LABELS "dualstream;edge_accel_pipe;edge_accel_cmd_queue;tensor"
  SOURCES
    "${edge_accel_queue_bridge_tb}"
    "${edge_accel_pipe_rtl}"
    "${edge_accel_cmd_queue_rtl}"
)

edge_add_verilator_hardware_test(
  NAME edge_accel_pipe_decode
  TOP edge_accel_pipe_decode_tb
  WORK_DIR "${edge_accel_pipe_build_dir}"
  PASS_PATTERN "EDGE_ACCEL_PIPE_DECODE TEST PASS"
  LABELS "dualstream;edge_accel_pipe"
  SOURCES
    "${edge_accel_pipe_decode_tb}"
    "${edge_accel_pipe_rtl}"
)

edge_add_verilator_hardware_test(
  NAME edge_accel_pipe_stream_shell
  TOP edge_accel_pipe_stream_shell_tb
  WORK_DIR "${edge_accel_pipe_build_dir}"
  PASS_PATTERN "EDGE_ACCEL_PIPE_STREAM_SHELL TEST PASS"
  LABELS "dualstream;edge_accel_pipe;tensor"
  SOURCES
    "${edge_accel_pipe_stream_shell_tb}"
    "${edge_accel_pipe_rtl}"
    ${edge_accel_pipe_stream_shell_rtl}
)
set_tests_properties(
  build_hw_edge_accel_pipe_stream_shell_verilator
  hw_edge_accel_pipe_stream_shell_verilator
  PROPERTIES
    DISABLED TRUE
    DISABLED_REASON "Obsolete accelerator-pipe shell test; tensor unit stream-shell tests cover the maintained path"
)
