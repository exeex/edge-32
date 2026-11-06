// Dispatch cache maintenance and fence.i to the owning cache interfaces.
  assign cache_op_valid=ex_issue_ok&&is_edge_cache&&!cache_started_q;
  assign cache_op_is_va=cache_is_va;
  assign cache_op_kind=cache_kind;
  assign cache_op_addr=ex_rs1_value;
    assign cache_req_fire=cache_op_valid&&cache_op_ready;
    assign cache_done=is_edge_cache&&cache_started_q&&cache_op_complete_valid;
  assign icache_invalidate_valid=
    ex_issue_ok&&is_fence_i&&!icache_invalidate_started_q;
    assign icache_invalidate_fire=
    icache_invalidate_valid&&icache_invalidate_ready;
    assign fence_i_done=is_fence_i&&icache_invalidate_started_q&&
    icache_invalidate_complete;
