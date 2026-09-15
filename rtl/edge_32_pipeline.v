`timescale 1ns/1ps
// SystemVerilog RTL; retain .v to preserve existing filelists and history.
// IF/ID/EX slice of the four-stage core. Registered WB is owned by the core.
module edge_32_pipeline #(
  parameter PC_WIDTH = 32,
  parameter VALUE_WIDTH = 32
) (
  input  wire                   clk,
  input  wire                   reset_n,

  input  wire                   fetch_valid,
  output wire                   fetch_ready,
  output wire                   fetch_capacity_ready,
  input  wire [PC_WIDTH-1:0]    fetch_pc,
  input  wire [31:0]            fetch_inst,
  input  wire                   fetch_error,

  output wire                   id_valid,
  output wire                   id_capture_enable,
  output wire [PC_WIDTH-1:0]    id_pc,
  output wire [31:0]            id_inst,
  output wire                   id_error,
  input  wire [VALUE_WIDTH-1:0] id_rs1_value,
  input  wire [VALUE_WIDTH-1:0] id_rs2_value,
  input  wire                   id_legal,
  input  wire                   id_csr_write,
  input  wire                   id_stall,

  output wire                   ex_valid,
  output wire [PC_WIDTH-1:0]    ex_pc,
  output wire [31:0]            ex_inst,
  output wire                   ex_error,
  output wire [VALUE_WIDTH-1:0] ex_rs1_value,
  output wire [VALUE_WIDTH-1:0] ex_rs2_value,
  output wire                   ex_legal,
  input  wire                   ex_done,
  input  wire                   ex_redirect_valid
);
  // Lifetime state is separate from payload: only these two bits reset.
  logic id_valid_q;
  logic ex_valid_q;

  // Metadata and instruction bits share the same capture/hold boundary.
  // error is payload too; consumers must qualify it with the owning valid bit.
  typedef struct packed {
    logic [PC_WIDTH-1:0] pc;
    logic [31:0] inst;
    logic error;
  } instruction_payload_t;

  typedef struct packed {
    instruction_payload_t instruction;
    logic [VALUE_WIDTH-1:0] rs1_value;
    logic [VALUE_WIDTH-1:0] rs2_value;
    logic legal;
  } execute_payload_t;

  instruction_payload_t id_payload_q;
  execute_payload_t ex_payload_q;

  wire ex_blocked = ex_valid_q && !ex_done;
  wire id_can_advance = !ex_blocked && !id_stall;
  // A CSR writer leaves an admission bubble. The core separately holds ID
  // through pending EX/WB CSR updates with id_stall; no stale FRM is captured.
  wire csr_interlock = id_valid_q && !id_payload_q.error && id_csr_write;
  // Capacity may be computed before the resolving branch. Actual admission
  // still waits for redirect qualification through fetch_ready.
  assign fetch_capacity_ready = id_can_advance && !csr_interlock;
  assign fetch_ready = fetch_capacity_ready && !ex_redirect_valid;
  assign id_valid = id_valid_q;
  assign id_capture_enable = id_can_advance && !ex_redirect_valid;
  assign id_pc = id_payload_q.pc;
  assign id_inst = id_payload_q.inst;
  assign id_error = id_payload_q.error;
  assign ex_valid = ex_valid_q;
  assign ex_pc = ex_payload_q.instruction.pc;
  assign ex_inst = ex_payload_q.instruction.inst;
  assign ex_error = ex_payload_q.instruction.error;
  assign ex_rs1_value = ex_payload_q.rs1_value;
  assign ex_rs2_value = ex_payload_q.rs2_value;
  assign ex_legal = ex_payload_q.legal;

  always_ff @(posedge clk or negedge reset_n) begin
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
  always_ff @(posedge clk) begin
    if (id_capture_enable) begin
      ex_payload_q.instruction <= id_payload_q;
      ex_payload_q.rs1_value <= id_rs1_value;
      ex_payload_q.rs2_value <= id_rs2_value;
      ex_payload_q.legal <= id_legal;
      if (fetch_valid && fetch_ready) begin
        id_payload_q.pc <= fetch_pc;
        id_payload_q.inst <= fetch_inst;
        id_payload_q.error <= fetch_error;
      end
    end
  end
endmodule
