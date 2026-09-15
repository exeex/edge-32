// Implementation owned by this stage module.
    assign address_header_old=is_icache_header_csr?
    icache_address_header_q:dcache_address_header_q;
    assign address_header_source=f3[2]?{27'd0,csr_uimm}:
                                            ex_rs1_value;
    assign address_header_new=(f3[1:0]==2'b01)?address_header_source:
    (f3[1:0]==2'b10)?(address_header_old|address_header_source):
                       (address_header_old&~address_header_source);
    assign ex_result=is_edge_break?ex_rs1_value:is_accel?accel_resp_value[31:0]:
    is_fp_compute?fpu_value:is_muldiv?mul_result:
    is_fp_load?fp_load_value:is_load?lsu_value[31:0]:is_cycle?cycle_q[31:0]:
    is_instret?instret_q[31:0]:is_fp_csr?
    fp_csr_value:
    is_hardware_id?EDGE_ASIC_ID[31:0]:
    is_address_header_csr?address_header_old:32'd0;
