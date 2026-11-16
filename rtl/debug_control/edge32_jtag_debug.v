// Transport adapter. req/resp connect directly to edge32_debug_port (no AXI).
module edge32_jtag_debug #(
  parameter [31:0] IDCODE=32'h00000ffd,
  parameter [31:0] MISA=32'h40001120,
  parameter CONSOLE_DEPTH=64
)(
  input wire clk, reset_n, core_reset_n, tck, trst_n, tms, tdi,
  output wire tdo, ndmreset,
  output wire mem_req_valid, mem_req_write,
  output wire [31:0] mem_req_addr, mem_req_wdata,
  output wire [1:0] mem_req_size,
  input wire mem_req_ready, mem_resp_valid,
  input wire [31:0] mem_resp_rdata,
  input wire [2:0] mem_resp_error,
  output wire mem_resp_ready,
  input wire putchar_valid,
  input wire [7:0] putchar_char,
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
  edge32_dmi_debug #(.MISA(MISA),.CONSOLE_DEPTH(CONSOLE_DEPTH)) dm(
    .clk(clk),
    .reset_n(reset_n),
    .core_reset_n(core_reset_n),
    .mem_req_valid(mem_req_valid),
    .mem_req_write(mem_req_write),
    .mem_req_addr(mem_req_addr),
    .mem_req_wdata(mem_req_wdata),
    .mem_req_size(mem_req_size),
    .mem_req_ready(mem_req_ready),
    .mem_resp_valid(mem_resp_valid),
    .mem_resp_rdata(mem_resp_rdata),
    .mem_resp_error(mem_resp_error),
    .mem_resp_ready(mem_resp_ready),
    .putchar_valid(putchar_valid),.putchar_char(putchar_char),
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
