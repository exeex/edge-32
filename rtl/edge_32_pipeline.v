`timescale 1ns/1ps
// IF/ID/EX slice of the four-stage core. Registered WB is owned by the core.
module edge_32_pipeline #(
  parameter PC_WIDTH = 32,
  parameter VALUE_WIDTH = 32
) (
  input  wire                   clk,
  input  wire                   reset_n,

  input  wire                   fetch_valid,
  output wire                   fetch_ready,
  input  wire [PC_WIDTH-1:0]    fetch_pc,
  input  wire [63:0]            fetch_inst,
  input  wire                   fetch_is_64b,
  input  wire                   fetch_error,

  output wire                   id_valid,
  output wire                   id_capture_enable,
  output wire [PC_WIDTH-1:0]    id_pc,
  output wire [63:0]            id_inst,
  output wire                   id_is_64b,
  output wire                   id_error,
  input  wire [VALUE_WIDTH-1:0] id_rs1_value,
  input  wire [VALUE_WIDTH-1:0] id_rs2_value,
  input  wire                   id_legal,
  input  wire                   id_csr_write,
  input  wire                   id_stall,

  output wire                   ex_valid,
  output wire [PC_WIDTH-1:0]    ex_pc,
  output wire [63:0]            ex_inst,
  output wire                   ex_is_64b,
  output wire                   ex_error,
  output wire [VALUE_WIDTH-1:0] ex_rs1_value,
  output wire [VALUE_WIDTH-1:0] ex_rs2_value,
  output wire                   ex_legal,
  input  wire                   ex_done,
  input  wire                   ex_redirect_valid
);
  reg id_valid_q;
  reg [PC_WIDTH-1:0] id_pc_q;
  reg [63:0] id_inst_q;
  reg id_is_64b_q;
  reg id_error_q;
  reg ex_valid_q;
  reg [PC_WIDTH-1:0] ex_pc_q;
  reg [63:0] ex_inst_q;
  reg ex_is_64b_q;
  reg ex_error_q;
  reg [VALUE_WIDTH-1:0] ex_rs1_q;
  reg [VALUE_WIDTH-1:0] ex_rs2_q;
  reg ex_legal_q;

  wire ex_blocked = ex_valid_q && !ex_done;
  wire id_can_advance = !ex_blocked && !id_stall;
  // A CSR writer leaves an admission bubble. The core separately holds ID
  // through pending EX/WB CSR updates with id_stall; no stale FRM is captured.
  wire csr_interlock = id_valid_q && !id_error_q && id_csr_write;
  assign fetch_ready = id_can_advance && !ex_redirect_valid && !csr_interlock;
  assign id_valid = id_valid_q;
  assign id_capture_enable = id_can_advance && !ex_redirect_valid;
  assign id_pc = id_pc_q;
  assign id_inst = id_inst_q;
  assign id_is_64b = id_is_64b_q;
  assign id_error = id_error_q;
  assign ex_valid = ex_valid_q;
  assign ex_pc = ex_pc_q;
  assign ex_inst = ex_inst_q;
  assign ex_is_64b = ex_is_64b_q;
  assign ex_error = ex_error_q;
  assign ex_rs1_value = ex_rs1_q;
  assign ex_rs2_value = ex_rs2_q;
  assign ex_legal = ex_legal_q;

  always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      id_valid_q <= 1'b0;
      ex_valid_q <= 1'b0;
    end else if (ex_redirect_valid) begin
      // The resolving EX instruction completes; all younger ID/IF work dies.
      id_valid_q <= 1'b0;
      ex_valid_q <= 1'b0;
    end else begin
      // Completing EX must drain even when a dependency keeps ID resident.
      if (!ex_blocked) ex_valid_q <= id_can_advance && id_valid_q;
      if (id_can_advance) id_valid_q <= fetch_valid && fetch_ready;
    end
  end
  // Valid bits cancel work on reset/flush. Payload is unobservable while
  // invalid, so reset must not zero instructions/operands ahead of arithmetic.
  // Keep the same stall and redirect hold boundary (including terminal debug).
  always @(posedge clk) begin
    if (id_capture_enable) begin
      ex_pc_q <= id_pc_q;
      ex_inst_q <= id_inst_q;
      ex_is_64b_q <= id_is_64b_q;
      ex_error_q <= id_error_q;
      ex_rs1_q <= id_rs1_value;
      ex_rs2_q <= id_rs2_value;
      ex_legal_q <= id_legal;
      if (fetch_valid && fetch_ready) begin
        id_pc_q <= fetch_pc;
        id_inst_q <= fetch_inst;
        id_is_64b_q <= fetch_is_64b;
        id_error_q <= fetch_error;
      end
    end
  end
endmodule
