// One outstanding debug transaction, synchronous to the core clock.
module edge32_debug_port #(
  parameter PC_WIDTH = 32
) (
  input wire clk,
  input wire reset_n,
  input wire req_valid,
  output wire req_ready,
  input wire req_write,
  input wire [2:0] req_id,
  input wire [63:0] req_data,
  output reg resp_valid,
  input wire resp_ready,
  output reg resp_error,
  output reg interrupt,
  output reg [63:0] resp_data,
  input wire halted,
  input wire illegal,
  input wire debug_gpr_allowed,
  output reg debug_gpr_req_valid,
  input wire debug_gpr_req_ready,
  output reg [4:0] debug_gpr_addr,
  input wire debug_gpr_resp_valid,
  output wire debug_gpr_resp_ready,
  input wire [31:0] debug_gpr_data,
  input wire [63:0] cycle_count,
  input wire [63:0] instret_count,
  output reg [PC_WIDTH-1:0] boot_pc,
  output reg core_start,
  output reg core_force_stop
);
  localparam [2:0] ID_CONTROL = 3'd0;
  localparam [2:0] ID_BOOT_PC = 3'd1;
  localparam [2:0] ID_GPR = 3'd2;
  localparam [2:0] ID_CYCLE = 3'd3;
  localparam [2:0] ID_INSTRET = 3'd4;

  reg stopped_q;
  reg gpr_pending_q;
  assign debug_gpr_resp_ready = reset_n && gpr_pending_q && !debug_gpr_req_valid && !resp_valid;
  reg halted_q;

  assign req_ready = reset_n && !resp_valid && !gpr_pending_q;

  always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      stopped_q <= 1'b1;
      gpr_pending_q <= 0; debug_gpr_req_valid <= 0; debug_gpr_addr <= 0;
      halted_q <= 1'b0;
      interrupt <= 1'b0;
      resp_valid <= 1'b0;
      resp_error <= 1'b0;
      resp_data <= 64'd0;
      boot_pc <= {PC_WIDTH{1'b0}};
      core_start <= 1'b0;
      core_force_stop <= 1'b0;
    end else begin
      halted_q <= halted;
      if(debug_gpr_req_valid && debug_gpr_req_ready) debug_gpr_req_valid <= 0;
      if(debug_gpr_resp_valid && debug_gpr_resp_ready) begin
        gpr_pending_q <= 0; resp_valid <= 1; resp_error <= 0;
        resp_data <= {32'd0, debug_gpr_data};
      end
      core_start <= 1'b0;
      core_force_stop <= 1'b0;
      if (resp_valid && resp_ready)
        resp_valid <= 1'b0;
      if (req_valid && req_ready) begin
        resp_valid <= 1'b1;
        resp_error <= 1'b0;
        resp_data <= 64'd0;
        if (req_write) begin
          case (req_id)
            ID_CONTROL: begin
              // Reject reserved bits and simultaneous start/stop commands.
              if (|req_data[63:3] || (&req_data[1:0])) begin
                resp_error <= 1'b1;
              end else begin
                if (req_data[2]) interrupt <= 1'b0;
                if (req_data[0] || req_data[1]) stopped_q <= req_data[1];
                core_start <= req_data[0];
                core_force_stop <= req_data[1];
              end
            end
            ID_BOOT_PC: boot_pc <= req_data[PC_WIDTH-1:0];
            default: resp_error <= 1'b1;
          endcase
        end else begin
          case (req_id)
            ID_CONTROL: resp_data <= {60'd0, interrupt, stopped_q, illegal, halted};
            ID_BOOT_PC: resp_data <= {{(64-PC_WIDTH){1'b0}}, boot_pc};
            ID_GPR: begin
              if(|req_data[63:5] || !debug_gpr_allowed) resp_error <= 1;
              else begin
                resp_valid <= 0; gpr_pending_q <= 1;
                debug_gpr_req_valid <= 1; debug_gpr_addr <= req_data[4:0];
              end
            end
            ID_CYCLE: resp_data <= cycle_count;
            ID_INSTRET: resp_data <= instret_count;
            default: resp_error <= 1'b1;
          endcase
        end
      end
      // A new event wins over simultaneous software acknowledgement.
      if ((halted && !halted_q) || core_force_stop) interrupt <= 1'b1;
    end
  end
endmodule
