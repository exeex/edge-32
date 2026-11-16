// Single-hart run-control DM subset over the existing addressed debug interface.
// Independent RAM port; SBA owns halt/cache/resume sequencing. No Program Buffer/full compliance.
module edge32_dmi_debug #(parameter [31:0] MISA=32'h40001120, parameter CONSOLE_DEPTH=64)(
  input wire clk, reset_n, core_reset_n,
  output wire mem_req_valid, mem_req_write,
  output wire [31:0] mem_req_addr, mem_req_wdata,
  output wire [1:0] mem_req_size,
  input wire mem_req_ready, mem_resp_valid,
  input wire [31:0] mem_resp_rdata,
  input wire [2:0] mem_resp_error,
  output wire mem_resp_ready,
  input wire putchar_valid,
  input wire [7:0] putchar_char,
  input wire dmi_valid, dmi_write,
  input wire [6:0] dmi_addr,
  input wire [31:0] dmi_wdata,
  output wire dmi_ready,
  output reg dmi_resp_valid,
  input wire dmi_resp_ready,
  output reg [31:0] dmi_rdata,
  output reg dmi_error,
  output reg ndmreset,
  output reg req_valid, req_write,
  output reg [2:0] req_id,
  output reg [63:0] req_data,
  input wire req_ready, resp_valid, resp_error,
  input wire [63:0] resp_data,
  output wire resp_ready
);
  reg active, selected, havereset, resumeack, step;
  wire [31:0] sba_data;
  wire sba_resp_ready, sba_req_valid, sba_req_ready;
  localparam M_IDLE=0, M_PREP=1, M_ISSUE=2, M_WAIT=3, M_POST=4, M_DONE=5, M_FAIL=6;
  reg [2:0] mem_state;
  reg auto_resume, mem_failed;
  wire memory_owned=(mem_state!=M_IDLE) || sba_req_valid;
  // A queued external halt takes precedence over automatic restart.
  wire external_halt_waiting=dmi_valid && dmi_write && dmi_addr==7'h10 &&
                            dmi_wdata[0] && dmi_wdata[31];
  assign mem_req_valid=sba_req_valid && mem_state==M_ISSUE;
  assign sba_req_ready=(mem_state==M_ISSUE && mem_req_ready) || mem_state==M_FAIL;
  assign mem_resp_ready=sba_resp_ready && mem_state==M_DONE;
  wire local_failure_response=(mem_state==M_FAIL && sba_resp_ready);
  edge32_debug_sba sba(.clk(clk),.reset_n(reset_n),.enable(active),
    .access_valid(dmi_valid && dmi_ready),.access_write(dmi_write),
    .access_addr(dmi_addr),.access_data(dmi_wdata),.read_data(sba_data),
    .mem_req_valid(sba_req_valid),
    .mem_req_write(mem_req_write),
    .mem_req_addr(mem_req_addr),
    .mem_req_wdata(mem_req_wdata),
    .mem_req_size(mem_req_size),
    .mem_req_ready(sba_req_ready),
    .mem_resp_valid(local_failure_response || (mem_resp_valid && mem_state==M_DONE)),
    .mem_resp_rdata(mem_resp_rdata),
    .mem_resp_error(mem_failed ? 3'd7 : mem_resp_error),
    .mem_resp_ready(sba_resp_ready));
  wire [31:0] console_status,console_data;
  wire console_pop=dmi_valid && dmi_ready && active && !dmi_write && dmi_addr==7'h75;
  wire console_clear=dmi_valid && dmi_ready && active && dmi_write &&
    dmi_addr==7'h74 && dmi_wdata==32'd4;
  edge32_debug_console #(.DEPTH(CONSOLE_DEPTH)) console(
    .clk(clk),.reset_n(reset_n),.putchar_valid(putchar_valid && core_reset_n),
    .putchar_char(putchar_char),.pop(console_pop),.clear_overflow(console_clear),
    .status(console_status),.data(console_data));

  reg [31:0] data0, command, raw_lo, raw_hi;
  reg [2:0] cmderr;
  reg [15:0] csr_number;
  reg busy;
  reg [3:0] operation;
  reg abstract_read, raw_error;
  localparam STATUS=0, ABSTRACT=1, DCSR=2, HALT=3, RESUME=4, RAW=5, MEM_CHECK=6, MEM_HALT=7, MEM_VERIFY=8, MEM_CLEAN=9, MEM_SYNC=10, MEM_RESUME=11;
  assign dmi_ready=!dmi_resp_valid && !busy && !memory_owned;
  assign resp_ready=busy && !req_valid;
  function [31:0] status_word(input [63:0] s);
    begin
      status_word=32'h82; // authenticated, DM v0.13
      if(selected) status_word=status_word|32'hc000; // nonexistent
      else if(ndmreset || !core_reset_n) status_word=status_word|32'h3000;
      else status_word=status_word|(s[0]?32'h300:32'hc00);
      if(havereset && !selected) status_word=status_word|32'hc0000;
      if(resumeack && !selected) status_word=status_word|32'h30000;
    end
  endfunction
  task dispatch(input [2:0] id, input wr, input [63:0] data, input [3:0] owner);
    begin req_id<=id; req_write<=wr; req_data<=data; req_valid<=1;
      busy<=1; operation<=owner; dmi_resp_valid<=0; end
  endtask
  always @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
      mem_state<=M_IDLE; auto_resume<=0; mem_failed<=0;
      active<=0; selected<=0; havereset<=1; resumeack<=0; step<=0; ndmreset<=0;
      data0<=0; command<=0; csr_number<=0; raw_lo<=0; raw_hi<=0; cmderr<=0;
      busy<=0; operation<=0; abstract_read<=0; raw_error<=0;
      req_valid<=0; req_write<=0; req_id<=0; req_data<=0;
      dmi_resp_valid<=0; dmi_rdata<=0; dmi_error<=0;
    end else begin
      if(mem_state==M_IDLE && sba_req_valid && !busy && !dmi_resp_valid) begin
        auto_resume<=0; mem_failed<=0;
        if(core_reset_n && !ndmreset) begin
          mem_state<=M_PREP; dispatch(0,0,0,MEM_CHECK);
        end else mem_state<=M_ISSUE;
      end
      if(mem_req_valid && mem_req_ready) mem_state<=M_WAIT;
      if(mem_state==M_WAIT && mem_resp_valid && !busy) begin
        if(core_reset_n && !ndmreset && mem_req_write) begin
          mem_state<=M_POST;
          // Also synchronize after a failed/partially completed RAM write.
          dispatch(0,1,{mem_req_addr[31:6],6'd0,32'd8},MEM_SYNC);
        end else if(core_reset_n && auto_resume && !external_halt_waiting) begin
          mem_state<=M_POST; dispatch(0,1,64'd16,MEM_RESUME);
        end else mem_state<=M_DONE;
      end
      if((mem_resp_valid && mem_resp_ready) || local_failure_response) begin
        mem_state<=M_IDLE; auto_resume<=0; mem_failed<=0;
      end
      if(dmi_resp_valid && dmi_resp_ready) dmi_resp_valid<=0;
      if(req_valid && req_ready) req_valid<=0;
      if(resp_valid && resp_ready) begin
        busy<=0; dmi_resp_valid<=1; dmi_rdata<=0;
        case(operation)
          MEM_CHECK: begin
            dmi_resp_valid<=0;
            if(resp_error) begin mem_failed<=1; mem_state<=M_FAIL; end
            else if(resp_data[0])
              dispatch(0,1,{mem_req_addr,mem_req_write?32'd128:32'd64},MEM_CLEAN);
            else dispatch(0,1,64'd2,MEM_HALT);
          end
          MEM_HALT: begin
            dmi_resp_valid<=0;
            if(resp_error) begin mem_failed<=1; mem_state<=M_FAIL; end
            else dispatch(0,0,0,MEM_VERIFY);
          end
          MEM_VERIFY: begin
            dmi_resp_valid<=0;
            if(resp_error || !resp_data[0]) begin mem_failed<=1; mem_state<=M_FAIL; end
            else begin
              // Preserve a breakpoint/EBREAK/step halt that won the race.
              auto_resume<=resp_data[6:4]==3'd3;
              dispatch(0,1,{mem_req_addr,mem_req_write?32'd128:32'd64},MEM_CLEAN);
            end
          end
          MEM_CLEAN: begin
            dmi_resp_valid<=0;
            if(resp_error) begin mem_failed<=1; mem_state<=M_FAIL; auto_resume<=0; end
            else mem_state<=M_ISSUE;
          end
          MEM_SYNC: begin
            dmi_resp_valid<=0;
            if(resp_error) begin mem_failed<=1; mem_state<=M_DONE; auto_resume<=0; end
            else if(auto_resume && !external_halt_waiting) dispatch(0,1,64'd16,MEM_RESUME);
            else mem_state<=M_DONE;
          end
          MEM_RESUME: begin
            dmi_resp_valid<=0; mem_state<=M_DONE; auto_resume<=0;
            if(resp_error) mem_failed<=1;
          end
          STATUS: dmi_rdata<=status_word(resp_data);
          DCSR: begin
            if(resp_error || !resp_data[0]) cmderr<=4;
            else case(csr_number)
              16'h7b0: if(abstract_read) data0<=32'h40008003 | {23'd0,resp_data[6:4],6'd0} | (step?32'd4:32'd0);
                else step<=data0[2];
              16'h301: if(abstract_read) data0<=MISA; else cmderr<=2;
              16'hf11,16'hf12,16'hf13,16'hf14: if(abstract_read) data0<=0; else cmderr<=2;
              16'h7a0,16'h7a1: if(abstract_read) data0<=0; // WARL zero: no standard triggers
              16'h7a4: if(abstract_read) data0<=1; else cmderr<=2;
              default: cmderr<=2;
            endcase
          end
          ABSTRACT: begin
            if(resp_error) cmderr<=3'd4;
            else if(abstract_read) data0<=resp_data[31:0];
          end
          RESUME: begin if(!resp_error) resumeack<=1; end
          RAW: begin raw_error<=resp_error; raw_lo<=resp_data[31:0]; raw_hi<=resp_data[63:32]; end
          default: begin end
        endcase
      end
      if(dmi_valid && dmi_ready) begin
        dmi_resp_valid<=1; dmi_rdata<=0; dmi_error<=0;
        if(dmi_write) begin
          if(dmi_addr==7'h10) begin
            active<=dmi_wdata[0]; selected<=|dmi_wdata[25:16] || |dmi_wdata[15:6];
            if(!dmi_wdata[0]) begin
              ndmreset<=0; cmderr<=0; step<=0; resumeack<=0; data0<=0; command<=0;
            end else begin
              ndmreset<=dmi_wdata[1];
              if(dmi_wdata[1]) havereset<=1;
              else if(dmi_wdata[28]) havereset<=0;

              if(!dmi_wdata[1] && !(|dmi_wdata[25:6])) begin
                if(dmi_wdata[31]) dispatch(0,1,64'd2,HALT);
                else if(dmi_wdata[30]) begin resumeack<=0; dispatch(0,1,step?64'd32:64'd16,RESUME); end
              end
            end
          end else if(active) begin
            case(dmi_addr)
              7'h04: data0<=dmi_wdata;
              7'h16: if(|dmi_wdata[10:8]) cmderr<=0;
              7'h17: begin
                command<=dmi_wdata; csr_number<=dmi_wdata[15:0];
                abstract_read<=!dmi_wdata[16];
                if(cmderr==0) begin
                  if(selected || ndmreset || !core_reset_n) cmderr<=4;
                  else if(dmi_wdata[31:24]!=0 || dmi_wdata[22:20]!=2 ||
                          dmi_wdata[23] || dmi_wdata[19] || dmi_wdata[18]) cmderr<=2;
                  else if(dmi_wdata[17]) begin
                    if(dmi_wdata[15:5]==11'h080)
                      dispatch(2,dmi_wdata[16],dmi_wdata[16]?{data0,27'd0,dmi_wdata[4:0]}:{59'd0,dmi_wdata[4:0]},ABSTRACT);
                    else case(dmi_wdata[15:0])
                      16'h7b1: dispatch(5,dmi_wdata[16],{32'd0,data0},ABSTRACT);
                      16'h7b0,16'h301,16'hf11,16'hf12,16'hf13,16'hf14,
                      16'h7a0,16'h7a1,16'h7a4: dispatch(0,0,0,DCSR);
                      default: cmderr<=2;
                    endcase
                  end
                end
              end
              7'h74: if(dmi_wdata!=4) dmi_error<=1;
              7'h75: dmi_error<=1; // read-only destructive data register
              7'h70: raw_lo<=dmi_wdata;
              7'h71: raw_hi<=dmi_wdata;
              7'h72: if(|dmi_wdata[31:4]) dmi_error<=1; else dispatch(dmi_wdata[2:0],dmi_wdata[3],{raw_hi,raw_lo},RAW);
              default: begin end // optional unimplemented registers read zero / ignore writes
            endcase
          end
        end else if(dmi_addr==7'h10) dmi_rdata<={15'd0,selected,14'd0,ndmreset,active};
        else if(active) begin
          case(dmi_addr)
            7'h38,7'h39,7'h3c: dmi_rdata<=sba_data;
            7'h04: dmi_rdata<=data0;
            7'h11: if(selected || ndmreset || !core_reset_n) dmi_rdata<=status_word(0); else dispatch(0,0,0,STATUS);
            7'h12: dmi_rdata<=0; // no data access/program buffer, one hart
            7'h16: dmi_rdata<={21'd0,cmderr,4'd0,4'd1}; // datacount=1, progbufsize=0
            7'h17: dmi_rdata<=command;
            7'h74: dmi_rdata<=console_status;
            7'h75: dmi_rdata<=console_data;
            7'h70: dmi_rdata<=raw_lo;
            7'h71: dmi_rdata<=raw_hi;
            7'h73: dmi_rdata<={31'd0,raw_error};
            default: dmi_rdata<=0;
          endcase
        end
      end
      // A target reset cancels its backend transaction but preserves DMI/TAP access.
      if(!core_reset_n) begin
        havereset<=1; req_valid<=0; auto_resume<=0;
        if(mem_state==M_PREP) begin mem_state<=M_FAIL; mem_failed<=1; end
        if(mem_state==M_POST) begin mem_state<=M_DONE; mem_failed<=1; end
        if(busy) begin
          busy<=0; dmi_resp_valid<=1; dmi_rdata<=0;
          if(operation>=MEM_CHECK) dmi_resp_valid<=0;
          if(operation==ABSTRACT || operation==DCSR) cmderr<=4;
          if(operation==RAW) raw_error<=1;
          if(operation==STATUS) dmi_rdata<=status_word(0);
        end
      end
    end
  end
endmodule
