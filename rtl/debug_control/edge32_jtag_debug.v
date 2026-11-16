// Transport adapter. req/resp connect directly to edge32_debug_port (no AXI).
module edge32_jtag_debug #(
  parameter [31:0] IDCODE=32'h00000ffd,
  parameter [31:0] MISA=32'h40001120
)(
  input wire clk, reset_n, core_reset_n, tck, trst_n, tms, tdi,
  output wire tdo, ndmreset,
  output wire req_valid, req_write,
  output wire [2:0] req_id,
  output wire [63:0] req_data,
  input wire req_ready, resp_valid, resp_error,
  input wire [63:0] resp_data,
  output wire resp_ready
);
  wire dmi_valid,dmi_write,dmi_ready,dmi_resp_valid,dmi_resp_ready,dmi_error;
  wire [6:0] dmi_addr;
  wire [31:0] dmi_wdata,dmi_rdata;
  edge32_jtag_dtm #(.IDCODE(IDCODE)) dtm(
    .clk(clk),
    .reset_n(reset_n),
    .tck(tck),
    .trst_n(trst_n),
    .tms(tms),
    .tdi(tdi),
    .tdo(tdo),
    .dmi_valid(dmi_valid),
    .dmi_ready(dmi_ready),
    .dmi_addr(dmi_addr),
    .dmi_wdata(dmi_wdata),
    .dmi_write(dmi_write),
    .dmi_resp_valid(dmi_resp_valid),
    .dmi_resp_ready(dmi_resp_ready),
    .dmi_rdata(dmi_rdata),
    .dmi_error(dmi_error)
  );
  edge32_dmi_debug #(.MISA(MISA)) dm(
    .clk(clk),
    .reset_n(reset_n),
    .core_reset_n(core_reset_n),
    .dmi_valid(dmi_valid),
    .dmi_write(dmi_write),
    .dmi_addr(dmi_addr),
    .dmi_wdata(dmi_wdata),
    .dmi_ready(dmi_ready),
    .dmi_resp_valid(dmi_resp_valid),
    .dmi_resp_ready(dmi_resp_ready),
    .dmi_rdata(dmi_rdata),
    .dmi_error(dmi_error),
    .ndmreset(ndmreset),
    .req_valid(req_valid),
    .req_write(req_write),
    .req_id(req_id),
    .req_data(req_data),
    .req_ready(req_ready),
    .resp_valid(resp_valid),
    .resp_error(resp_error),
    .resp_data(resp_data),
    .resp_ready(resp_ready)
  );
endmodule
