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
  output wire resp_valid,
  input wire resp_ready,
  output wire resp_error,
  output wire interrupt,
  output wire [63:0] resp_data,
  output wire debug_dcache_req_valid, debug_dcache_invalidate,
  output wire [31:0] debug_dcache_addr,
  input wire debug_dcache_req_ready, debug_dcache_complete,
  output wire debug_icache_req_valid,
  output wire [31:0] debug_icache_addr,
  input wire debug_icache_req_ready,
  input wire debug_icache_complete,
  output wire debug_resume, debug_step, debug_pc_write,
  output wire [PC_WIDTH-1:0] debug_pc_wdata,
  input wire debug_control_ack,
  input wire halted,
  input wire illegal,
  input wire debug_gpr_allowed,
  input wire [PC_WIDTH-1:0] debug_pc,
  input wire [2:0] debug_cause,
  output wire [PC_WIDTH-1:0] debug_break_pc,
  output wire debug_break_enable,
  output wire debug_gpr_write,
  output wire [31:0] debug_gpr_wdata,
  output wire debug_gpr_req_valid,
  input wire debug_gpr_req_ready,
  output wire [4:0] debug_gpr_addr,
  input wire debug_gpr_resp_valid,
  output wire debug_gpr_resp_ready,
  input wire [31:0] debug_gpr_data,
  input wire [63:0] cycle_count,
  input wire [63:0] instret_count,
  output wire [PC_WIDTH-1:0] boot_pc,
  output wire core_start,
  output wire core_force_stop
);
  // Internal synchronous reset; the containing reset manager owns capture/release.
  wire local_reset_n = reset_n;
  reg resp_valid_q;
  assign resp_valid = resp_valid_q;
  reg resp_error_q;
  assign resp_error = resp_error_q;
  reg interrupt_q;
  assign interrupt = interrupt_q;
  reg [63:0] resp_data_q;
  assign resp_data = resp_data_q;
  reg debug_dcache_req_valid_q;
  assign debug_dcache_req_valid = debug_dcache_req_valid_q;
  reg debug_dcache_invalidate_q;
  assign debug_dcache_invalidate = debug_dcache_invalidate_q;
  reg [31:0] debug_dcache_addr_q;
  assign debug_dcache_addr = debug_dcache_addr_q;
  reg debug_icache_req_valid_q;
  assign debug_icache_req_valid = debug_icache_req_valid_q;
  reg [31:0] debug_icache_addr_q;
  assign debug_icache_addr = debug_icache_addr_q;
  reg debug_resume_q;
  assign debug_resume = debug_resume_q;
  reg debug_step_q;
  assign debug_step = debug_step_q;
  reg debug_pc_write_q;
  assign debug_pc_write = debug_pc_write_q;
  reg [PC_WIDTH-1:0] debug_pc_wdata_q;
  assign debug_pc_wdata = debug_pc_wdata_q;
  reg [PC_WIDTH-1:0] debug_break_pc_q;
  assign debug_break_pc = debug_break_pc_q;
  reg debug_break_enable_q;
  assign debug_break_enable = debug_break_enable_q;
  reg debug_gpr_write_q;
  assign debug_gpr_write = debug_gpr_write_q;
  reg [31:0] debug_gpr_wdata_q;
  assign debug_gpr_wdata = debug_gpr_wdata_q;
  reg debug_gpr_req_valid_q;
  assign debug_gpr_req_valid = debug_gpr_req_valid_q;
  reg [4:0] debug_gpr_addr_q;
  assign debug_gpr_addr = debug_gpr_addr_q;
  reg [PC_WIDTH-1:0] boot_pc_q;
  assign boot_pc = boot_pc_q;
  reg core_start_q;
  assign core_start = core_start_q;
  reg core_force_stop_q;
  assign core_force_stop = core_force_stop_q;

  localparam [2:0] ID_CONTROL = 3'd0;
  localparam [2:0] ID_BOOT_PC = 3'd1;
  localparam [2:0] ID_GPR = 3'd2;
  localparam [2:0] ID_CYCLE = 3'd3;
  localparam [2:0] ID_INSTRET = 3'd4;
  localparam [2:0] ID_PC = 3'd5;
  localparam [2:0] ID_BREAK_PC = 3'd6;
  localparam [2:0] ID_BREAK_ENABLE = 3'd7;

  reg stopped_q;
  reg gpr_pending_q;
  reg halt_pending_q;
  reg icache_pending_q, dcache_pending_q;
  reg control_pending_q;
  reg step_pending_q, step_launched_q;
  assign debug_gpr_resp_ready = gpr_pending_q && !debug_gpr_req_valid_q && !resp_valid_q;
  reg halted_q;

  assign req_ready = !resp_valid_q && !gpr_pending_q && !halt_pending_q && !icache_pending_q && !dcache_pending_q && !control_pending_q && !step_pending_q;

  always @(posedge clk) begin
    if (!local_reset_n) begin
      stopped_q <= 1'b1;
      debug_resume_q <= 0; debug_step_q <= 0; debug_pc_write_q <= 0; debug_pc_wdata_q <= 0;
      step_pending_q <= 0; step_launched_q <= 0;
      control_pending_q <= 0;
      debug_gpr_write_q <= 0; debug_gpr_wdata_q <= 0;
      debug_break_pc_q <= 0; debug_break_enable_q <= 0;
      dcache_pending_q <= 0; debug_dcache_req_valid_q <= 0; debug_dcache_addr_q <= 0; debug_dcache_invalidate_q <= 0;
      icache_pending_q <= 0; debug_icache_req_valid_q <= 0; debug_icache_addr_q <= 0;
      halt_pending_q <= 0;
      gpr_pending_q <= 0; debug_gpr_req_valid_q <= 0; debug_gpr_addr_q <= 0;
      halted_q <= 1'b0;
      interrupt_q <= 1'b0;
      resp_valid_q <= 1'b0;
      resp_error_q <= 1'b0;
      resp_data_q <= 64'd0;
      boot_pc_q <= {PC_WIDTH{1'b0}};
      core_start_q <= 1'b0;
      core_force_stop_q <= 1'b0;
    end else begin
      halted_q <= debug_gpr_allowed;
      debug_resume_q <= 0; debug_step_q <= 0; debug_pc_write_q <= 0;
      if (step_pending_q && debug_control_ack) step_launched_q <= 1;
      if (step_pending_q && step_launched_q && debug_gpr_allowed) begin
        step_pending_q <= 0; step_launched_q <= 0;
        stopped_q <= 1; resp_valid_q <= 1; resp_error_q <= 0; resp_data_q <= 0;
      end
      if (control_pending_q && debug_control_ack) begin
        control_pending_q <= 0;
        resp_valid_q <= 1; resp_error_q <= 0; resp_data_q <= 0;
      end
      if (debug_dcache_req_valid_q && debug_dcache_req_ready) debug_dcache_req_valid_q <= 0;
      if (dcache_pending_q && !debug_dcache_req_valid_q && debug_dcache_complete) begin
        dcache_pending_q <= 0; resp_valid_q <= 1; resp_error_q <= 0; resp_data_q <= 0;
      end
      if (debug_icache_req_valid_q && debug_icache_req_ready)
        debug_icache_req_valid_q <= 0;
      if (icache_pending_q && !debug_icache_req_valid_q && debug_icache_complete) begin
        icache_pending_q <= 0;
        resp_valid_q <= 1; resp_error_q <= 0; resp_data_q <= 0;
      end
      // Do not acknowledge the command pulse itself or stale pre-stop permission.
      // The core owns quiescence; the external requester sees only completion.
      if (halt_pending_q && !core_force_stop_q && debug_gpr_allowed) begin
        halt_pending_q <= 0;
        resp_valid_q <= 1;
        resp_error_q <= 0;
        resp_data_q <= 64'd0;
      end
      if(debug_gpr_req_valid_q && debug_gpr_req_ready) debug_gpr_req_valid_q <= 0;
      if(debug_gpr_resp_valid && debug_gpr_resp_ready) begin
        gpr_pending_q <= 0; resp_valid_q <= 1; resp_error_q <= 0;
        resp_data_q <= debug_gpr_write_q ? 64'd0 : {32'd0, debug_gpr_data};
      end
      core_start_q <= 1'b0;
      core_force_stop_q <= 1'b0;
      if (resp_valid_q && resp_ready)
        resp_valid_q <= 1'b0;
      if (req_valid && req_ready) begin
        resp_valid_q <= 1'b1;
        resp_error_q <= 1'b0;
        resp_data_q <= 64'd0;
        if (req_write) begin
          case (req_id)
            ID_CONTROL: begin
              // START, HALT, I-SYNC, D-CLEAN, RESUME and STEP are exclusive actions.
              if (|req_data[31:8] || (!(req_data[3] || |req_data[7:6]) && |req_data[63:32]) ||
                  ((|req_data[7:6]) && ((&req_data[7:6]) || |req_data[5:3] || |req_data[1:0] || !debug_gpr_allowed)) ||
                  (req_data[3] && |req_data[33:32]) || (&req_data[1:0]) ||
                  (req_data[3] && (|req_data[1:0] || !debug_gpr_allowed)) ||
                  (req_data[4] && (|req_data[1:0] || req_data[3] || !debug_gpr_allowed)) ||
                  (req_data[5] && (|req_data[1:0] || |req_data[4:3] || !debug_gpr_allowed))) begin
                resp_error_q <= 1'b1;
              end else begin
                if (req_data[2]) interrupt_q <= 1'b0;
                if (req_data[0] || req_data[1]) stopped_q <= req_data[1];
                core_start_q <= req_data[0];
                core_force_stop_q <= req_data[1];
                if (|req_data[7:6]) begin
                  debug_dcache_invalidate_q <= req_data[7];
                  dcache_pending_q <= 1; debug_dcache_req_valid_q <= 1;
                  debug_dcache_addr_q <= req_data[63:32]; resp_valid_q <= 0;
                end
                if (req_data[5]) begin
                  debug_step_q <= 1; step_pending_q <= 1; step_launched_q <= 0;
                  stopped_q <= 0; resp_valid_q <= 0;
                end
                if (req_data[4]) begin
                  debug_resume_q <= 1; control_pending_q <= 1;
                  stopped_q <= 0; resp_valid_q <= 0;
                end
                if (req_data[3]) begin
                  icache_pending_q <= 1; debug_icache_req_valid_q <= 1;
                  debug_icache_addr_q <= req_data[63:32];
                  resp_valid_q <= 0;
                end
                if (req_data[1]) begin
                  halt_pending_q <= 1;
                  resp_valid_q <= 0;
                end
              end
            end
            ID_PC: begin
              if (!debug_gpr_allowed || |req_data[63:32] || |req_data[1:0]) resp_error_q <= 1;
              else begin
                debug_pc_wdata_q <= req_data[PC_WIDTH-1:0]; debug_pc_write_q <= 1;
                control_pending_q <= 1; resp_valid_q <= 0;
              end
            end
            ID_GPR: begin
              if (|req_data[31:5] || !debug_gpr_allowed) resp_error_q <= 1;
              else begin
                resp_valid_q <= 0; gpr_pending_q <= 1;
                debug_gpr_req_valid_q <= 1; debug_gpr_addr_q <= req_data[4:0];
                debug_gpr_write_q <= 1; debug_gpr_wdata_q <= req_data[63:32];
              end
            end
            ID_BREAK_PC: begin
              if (!debug_gpr_allowed || |req_data[63:32] || |req_data[1:0]) resp_error_q <= 1;
              else debug_break_pc_q <= req_data[PC_WIDTH-1:0];
            end
            ID_BREAK_ENABLE: begin
              if (!debug_gpr_allowed || |req_data[63:1]) resp_error_q <= 1;
              else debug_break_enable_q <= req_data[0];
            end
            ID_BOOT_PC: boot_pc_q <= req_data[PC_WIDTH-1:0];
            default: resp_error_q <= 1'b1;
          endcase
        end else begin
          case (req_id)
            ID_CONTROL: resp_data_q <= {57'd0, debug_cause, interrupt_q, stopped_q, illegal, debug_gpr_allowed};
            ID_PC: begin
              if (!debug_gpr_allowed) resp_error_q <= 1;
              else resp_data_q <= {{(64-PC_WIDTH){1'b0}}, debug_pc};
            end
            ID_BREAK_PC: resp_data_q <= {{(64-PC_WIDTH){1'b0}}, debug_break_pc_q};
            ID_BREAK_ENABLE: resp_data_q <= {63'd0, debug_break_enable_q};
            ID_BOOT_PC: resp_data_q <= {{(64-PC_WIDTH){1'b0}}, boot_pc_q};
            ID_GPR: begin
              if(|req_data[63:5] || !debug_gpr_allowed) resp_error_q <= 1;
              else begin
                resp_valid_q <= 0; gpr_pending_q <= 1;
                debug_gpr_req_valid_q <= 1; debug_gpr_addr_q <= req_data[4:0];
                debug_gpr_write_q <= 0;
              end
            end
            ID_CYCLE: resp_data_q <= cycle_count;
            ID_INSTRET: resp_data_q <= instret_count;
            default: resp_error_q <= 1'b1;
          endcase
        end
      end
      // A new event wins over simultaneous software acknowledgement.
      if (debug_gpr_allowed && !halted_q) interrupt_q <= 1'b1;
    end
  end
endmodule
