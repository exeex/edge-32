// Implementation owned by this stage module.
`include "ex/csr/operations.svh"
    assign ex_result=is_edge_break?ex_rs1_value:is_accel?accel_resp_value[31:0]:
`ifdef EDGE32_LOCAL_FP_WB
    (is_fp_compute && !ex_writes_fpr)?fpu_value:is_muldiv?mul_result:
`else
    is_fp_compute?fpu_value:is_muldiv?mul_result:
    is_fp_load?fp_load_value:
`endif
    is_load?lsu_value[31:0]:csr_value;
