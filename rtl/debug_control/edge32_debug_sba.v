// Standard 32-bit-address SBA registers and an independent, single-outstanding RAM port.
module edge32_debug_sba(
  input wire clk, reset_n, enable,
  input wire access_valid, access_write,
  input wire [6:0] access_addr,
  input wire [31:0] access_data,
  output reg [31:0] read_data,
  output reg mem_req_valid, mem_req_write,
  output reg [31:0] mem_req_addr, mem_req_wdata,
  output reg [1:0] mem_req_size,
  input wire mem_req_ready,
  input wire mem_resp_valid,
  output wire mem_resp_ready,
  input wire [31:0] mem_resp_rdata,
  input wire [2:0] mem_resp_error
);
  reg [31:0] address_q,data_q;
  reg [2:0] size_q,error_q;
  reg readonaddr_q,readondata_q,increment_q,busy_error_q;
  reg waiting_q,cancelled_q,operation_increment_q;
  wire busy=mem_req_valid || waiting_q;
  assign mem_resp_ready=waiting_q;
  always @* begin
    read_data=0;
    case(access_addr)
      7'h38: read_data={3'd1,6'd0,busy_error_q,busy,readonaddr_q,size_q,
                       increment_q,readondata_q,error_q,7'd32,5'b00111};
      7'h39: read_data=address_q;
      7'h3c: read_data=data_q;
      default: begin end
    endcase
  end
  task launch(input wr,input [31:0] addr,input [31:0] value);
    begin
      if(size_q>2)error_q<=4;
      else if((size_q==1 && addr[0]) || (size_q==2 && |addr[1:0]))error_q<=3;
      else begin
        mem_req_valid<=1;mem_req_write<=wr;mem_req_addr<=addr;
        mem_req_wdata<=value;mem_req_size<=size_q[1:0];
        operation_increment_q<=increment_q;cancelled_q<=0;
      end
    end
  endtask
  always @(posedge clk or negedge reset_n)begin
    if(!reset_n)begin
      address_q<=0;data_q<=0;size_q<=2;error_q<=0;
      readonaddr_q<=0;readondata_q<=0;increment_q<=0;busy_error_q<=0;
      mem_req_valid<=0;mem_req_write<=0;mem_req_addr<=0;mem_req_wdata<=0;mem_req_size<=0;
      waiting_q<=0;cancelled_q<=0;operation_increment_q<=0;
    end else begin
      if(mem_req_valid && mem_req_ready)begin mem_req_valid<=0;waiting_q<=1;end
      if(mem_resp_valid && mem_resp_ready)begin
        waiting_q<=0;
        if(enable && !cancelled_q)begin
          if(mem_resp_error!=0)error_q<=mem_resp_error;
          else begin
            if(!mem_req_write)data_q<=mem_resp_rdata;
            if(operation_increment_q)address_q<=mem_req_addr+(32'd1<<mem_req_size);
          end
        end
      end
      if(enable && access_valid)begin
        case(access_addr)
          7'h38: if(access_write && !busy)begin
            readonaddr_q<=access_data[20];size_q<=access_data[19:17];
            increment_q<=access_data[16];readondata_q<=access_data[15];
            error_q<=error_q & ~access_data[14:12];
            if(access_data[22])busy_error_q<=0;
          end
          7'h39: if(access_write)begin
            if(busy)busy_error_q<=1;
            else begin
              address_q<=access_data;
              if(readonaddr_q && !busy_error_q && error_q==0)launch(0,access_data,0);
            end
          end
          7'h3c: begin
            if(busy)busy_error_q<=1;
            else if(!busy_error_q && error_q==0)begin
              if(access_write)begin data_q<=access_data;launch(1,address_q,access_data);end
              else if(readondata_q)launch(0,address_q,0);
            end
          end
          default: begin end
        endcase
      end
      if(!enable)begin
        address_q<=0;data_q<=0;size_q<=2;error_q<=0;
        readonaddr_q<=0;readondata_q<=0;increment_q<=0;busy_error_q<=0;
        mem_req_valid<=0;cancelled_q<=1;
        // An accepted memory operation cannot be undone. Drain its response
        // before reusing this untagged channel, even if dmactive is reenabled.
      end
    end
  end
endmodule
