// Single-hart run-control DM subset over the existing addressed debug interface.
// No SBA/program buffer/memory commands: this is not a complete Debug Spec DM.
module edge32_dmi_debug #(parameter [31:0] MISA=32'h40001120)(
  input wire clk, reset_n, core_reset_n,
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
  reg [31:0] data0, command, raw_lo, raw_hi;
  reg [2:0] cmderr;
  reg [15:0] csr_number;
  reg busy;
  reg [2:0] operation;
  reg abstract_read, raw_error;
  localparam STATUS=0, ABSTRACT=1, DCSR=2, HALT=3, RESUME=4, RAW=5;
  assign dmi_ready=!dmi_resp_valid && !busy;
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
  task dispatch(input [2:0] id, input wr, input [63:0] data, input [2:0] owner);
    begin req_id<=id; req_write<=wr; req_data<=data; req_valid<=1;
      busy<=1; operation<=owner; dmi_resp_valid<=0; end
  endtask
  always @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
      active<=0; selected<=0; havereset<=1; resumeack<=0; step<=0; ndmreset<=0;
      data0<=0; command<=0; csr_number<=0; raw_lo<=0; raw_hi<=0; cmderr<=0;
      busy<=0; operation<=0; abstract_read<=0; raw_error<=0;
      req_valid<=0; req_write<=0; req_id<=0; req_data<=0;
      dmi_resp_valid<=0; dmi_rdata<=0; dmi_error<=0;
    end else begin
      if(dmi_resp_valid && dmi_resp_ready) dmi_resp_valid<=0;
      if(req_valid && req_ready) req_valid<=0;
      if(resp_valid && resp_ready) begin
        busy<=0; dmi_resp_valid<=1; dmi_rdata<=0;
        case(operation)
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
              7'h70: raw_lo<=dmi_wdata;
              7'h71: raw_hi<=dmi_wdata;
              7'h72: if(|dmi_wdata[31:4]) dmi_error<=1; else dispatch(dmi_wdata[2:0],dmi_wdata[3],{raw_hi,raw_lo},RAW);
              default: begin end // optional unimplemented registers read zero / ignore writes
            endcase
          end
        end else if(dmi_addr==7'h10) dmi_rdata<={15'd0,selected,14'd0,ndmreset,active};
        else if(active) begin
          case(dmi_addr)
            7'h04: dmi_rdata<=data0;
            7'h11: if(selected || ndmreset || !core_reset_n) dmi_rdata<=status_word(0); else dispatch(0,0,0,STATUS);
            7'h12: dmi_rdata<=0; // no data access/program buffer, one hart
            7'h16: dmi_rdata<={21'd0,cmderr,4'd0,4'd1}; // datacount=1, progbufsize=0
            7'h17: dmi_rdata<=command;
            7'h70: dmi_rdata<=raw_lo;
            7'h71: dmi_rdata<=raw_hi;
            7'h73: dmi_rdata<={31'd0,raw_error};
            default: dmi_rdata<=0;
          endcase
        end
      end
      // A target reset cancels its backend transaction but preserves DMI/TAP access.
      if(!core_reset_n) begin
        havereset<=1; req_valid<=0;
        if(busy) begin
          busy<=0; dmi_resp_valid<=1; dmi_rdata<=0;
          if(operation==ABSTRACT || operation==DCSR) cmderr<=4;
          if(operation==RAW) raw_error<=1;
          if(operation==STATUS) dmi_rdata<=status_word(0);
        end
      end
    end
  end
endmodule
