// JTAG DTM with one bundled-data toggle mailbox in each clock direction.
module edge32_jtag_dtm #(
  parameter [31:0] IDCODE = 32'h00000ffd // simulation identity; assign a product ID before silicon
)(
  input wire clk, reset_n,
  input wire tck, trst_n, tms, tdi,
  output reg tdo,
  output reg dmi_valid,
  input wire dmi_ready,
  output reg [6:0] dmi_addr,
  output reg [31:0] dmi_wdata,
  output reg dmi_write,
  input wire dmi_resp_valid,
  output wire dmi_resp_ready,
  input wire [31:0] dmi_rdata,
  input wire dmi_error
);
  localparam RESET=0, IDLE=1, SELECT_DR=2, CAPTURE_DR=3, SHIFT_DR=4,
    EXIT1_DR=5, PAUSE_DR=6, EXIT2_DR=7, UPDATE_DR=8, SELECT_IR=9,
    CAPTURE_IR=10, SHIFT_IR=11, EXIT1_IR=12, PAUSE_IR=13, EXIT2_IR=14, UPDATE_IR=15;
  reg [3:0] state, next_state;
  reg [4:0] ir, ir_shift;
  reg [40:0] dr_shift;
  reg bypass;
  reg [1:0] sticky;
  reg response_consumed;
  reg request_toggle;
  reg [40:0] request_payload;
  reg response_toggle;
  reg [33:0] response_payload;
  (* async_reg = "true" *) reg rsp_sync1, rsp_sync2;
  (* async_reg = "true" *) reg req_sync1, req_sync2;
  reg req_seen, core_wait;
  wire pending = request_toggle != rsp_sync2;
  wire [1:0] dmistat = sticky != 0 ? sticky : pending ? 2'b11 : rsp_sync2!=response_consumed ? response_payload[1:0] : 2'b00;
  wire tap_reset_n=reset_n && trst_n;
  // Launch TDO on falling TCK; external probes sample it on the rising edge.
  always @(negedge tck or negedge tap_reset_n) begin
    if(!tap_reset_n) tdo<=0;
    else tdo <= state == SHIFT_IR ? ir_shift[0] :
      state == SHIFT_DR ? ((ir==1 || ir==16 || ir==17) ? dr_shift[0] : bypass) : 1'b0;
  end
  always @* begin
    case (state)
      RESET: next_state=tms?RESET:IDLE;
      IDLE: next_state=tms?SELECT_DR:IDLE;
      SELECT_DR: next_state=tms?SELECT_IR:CAPTURE_DR;
      CAPTURE_DR: next_state=tms?EXIT1_DR:SHIFT_DR;
      SHIFT_DR: next_state=tms?EXIT1_DR:SHIFT_DR;
      EXIT1_DR: next_state=tms?UPDATE_DR:PAUSE_DR;
      PAUSE_DR: next_state=tms?EXIT2_DR:PAUSE_DR;
      EXIT2_DR: next_state=tms?UPDATE_DR:SHIFT_DR;
      UPDATE_DR: next_state=tms?SELECT_DR:IDLE;
      SELECT_IR: next_state=tms?RESET:CAPTURE_IR;
      CAPTURE_IR: next_state=tms?EXIT1_IR:SHIFT_IR;
      SHIFT_IR: next_state=tms?EXIT1_IR:SHIFT_IR;
      EXIT1_IR: next_state=tms?UPDATE_IR:PAUSE_IR;
      PAUSE_IR: next_state=tms?EXIT2_IR:PAUSE_IR;
      EXIT2_IR: next_state=tms?UPDATE_IR:SHIFT_IR;
      default: next_state=tms?SELECT_DR:IDLE;
    endcase
  end
  // TRST/TMS reset only the TAP, never rewind an in-flight mailbox token.
  always @(posedge tck or negedge tap_reset_n) begin
    if (!tap_reset_n) begin
      state<=RESET; ir<=1; ir_shift<=1; dr_shift<=0; bypass<=0; sticky<=0;
    end else begin
      state<=next_state;
      if(rsp_sync2!=response_consumed && response_payload[1:0]!=0) sticky<=response_payload[1:0];
      case(state)
        RESET: begin ir<=1; sticky<=0; end
        CAPTURE_IR: ir_shift<=5'b00001;
        SHIFT_IR: ir_shift<={tdi,ir_shift[4:1]};
        UPDATE_IR: ir<=ir_shift;
        CAPTURE_DR: begin
          bypass<=0;
          case(ir)
            1: dr_shift<={9'b0,IDCODE};
            16: dr_shift<={9'b0,17'b0,3'd5,dmistat,6'd7,4'd1}; // DTM v1, abits=7, idle=5
            17: begin
              dr_shift<={request_payload[40:34],response_payload[33:2],dmistat};
              if(dmistat!=0) sticky<=dmistat;
            end
            default: dr_shift<=0;
          endcase
        end
        SHIFT_DR: begin
          if(ir==17) dr_shift<={tdi,dr_shift[40:1]};
          else dr_shift<={9'b0,tdi,dr_shift[31:1]};
          bypass<=tdi;
        end
        UPDATE_DR: begin
          if(ir==16 && dr_shift[16]) begin sticky<=0; end // dmireset does not cancel accepted work
          if(ir==17 && dr_shift[1:0]!=0 && pending) sticky<=3;
          if(ir==17 && dr_shift[1:0]==3) sticky<=2;
        end
        default: begin end
      endcase
    end
  end
  always @(posedge tck or negedge reset_n) begin
    if(!reset_n) begin
      request_toggle<=0; request_payload<=0; rsp_sync1<=0; rsp_sync2<=0; response_consumed<=0;
    end else begin
      response_consumed<=rsp_sync2;
      rsp_sync1<=response_toggle; rsp_sync2<=rsp_sync1;
      if(trst_n && state==UPDATE_DR && ir==17 && dmistat==0 && !pending &&
         (dr_shift[1:0]==1 || dr_shift[1:0]==2)) begin
        request_payload<=dr_shift;
        request_toggle<=!request_toggle;
      end
    end
  end
  assign dmi_resp_ready=core_wait;
  always @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
      req_sync1<=0; req_sync2<=0; req_seen<=0; core_wait<=0;
      dmi_valid<=0; dmi_addr<=0; dmi_wdata<=0; dmi_write<=0;
      response_toggle<=0; response_payload<=0;
    end else begin
      req_sync1<=request_toggle; req_sync2<=req_sync1;
      if(!dmi_valid && !core_wait && req_sync2!=req_seen) begin
        req_seen<=req_sync2;
        dmi_addr<=request_payload[40:34]; dmi_wdata<=request_payload[33:2];
        dmi_write<=request_payload[1]; dmi_valid<=1;
      end
      if(dmi_valid && dmi_ready) begin dmi_valid<=0; core_wait<=1; end
      if(dmi_resp_valid && dmi_resp_ready) begin
        core_wait<=0;
        response_payload<={dmi_rdata,dmi_error?2'b10:2'b00};
        response_toggle<=req_seen;
      end
    end
  end
endmodule
