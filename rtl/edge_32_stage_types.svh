`ifndef EDGE_32_STAGE_TYPES_SVH
`define EDGE_32_STAGE_TYPES_SVH
package edge32_stage;
  typedef struct packed {
    logic [31:0] fast_value, other_value;
    logic fast;
    logic [4:0] rd;
    logic writes_gpr, fault, halt;
    logic writes_icache_header, writes_dcache_header;
    logic [31:0] header_value;
  } completion_payload_t;
endpackage
`endif
