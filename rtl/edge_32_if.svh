// IF stage source entry. Included once by edge_32_core.
// Stage-owned signals and boundary payload.
  wire parcel_valid, parcel_ready, parcel_error;
  wire [PC_WIDTH-1:0] parcel_pc; wire [31:0] parcel_inst;
  wire if_valid, if_ready, if_capacity_ready, if_error;
  wire [PC_WIDTH-1:0] if_pc; wire [31:0] if_inst;
  reg [3:0] id_decoded_class;
  reg id_decoded_legal;
  wire [3:0] if_decoded_class;
  wire if_decoded_legal;
  reg id_csr_write;
  reg [4:0] id_rs1, id_rs2;
  reg [4:0] id_write_rd;
  reg id_rd_gpr, id_rd_fpr;
  reg [4:0] id_frs0, id_frs1, id_frs2;
  reg [2:0] id_uses_fpr;
  wire [4:0] if_rs1, if_rs2, if_frs0, if_frs1, if_frs2, if_write_rd;
  wire [2:0] if_uses_fpr;
  wire if_rd_gpr, if_rd_fpr, if_csr_write;

`include "if/predecode.svh"
`include "if/admission.svh"
`include "if/fetch.svh"
