`timescale 1ns/1ps

module edge_32_axi_coremark_tb;
  localparam integer MEM_BYTES = 1024 * 1024;
  localparam integer MEM_WORDS = MEM_BYTES / 8;
  localparam integer TIMEOUT_CYCLES = 10_000_000;
  // Edge32 RV32IMF_Zba / ILP32F LLVM 22.1.8 image built by this project.
  localparam [63:0] EDGE32_COREMARK_INSTRET = 64'd587409;

  reg clk = 1'b0;
  reg reset_n = 1'b0;
  reg core_start = 1'b0;
  reg core_force_stop = 1'b0;
  reg [31:0] boot_pc = 32'd0;
  always #5 clk = ~clk;

  reg [63:0] mem [0:MEM_WORDS-1];
  string mem64_file;
  integer i;
  integer cycles;
  integer icache_reads;
  integer dcache_reads;
  integer write_responses;
  integer return_only;
  integer address_header_smoke;
  reg address_header_software;
  reg saw_old_dcache_writeback;
  reg saw_new_dcache_refill;
  reg saw_new_icache_refill;
  reg reboot_phase;
  reg saw_reboot_icache_refill;
  reg saw_reboot_dcache_refill;
  reg force_stop_pending;
  reg held_ifetch;
  reg held_ifetch_once;
  reg release_held_ifetch;
  reg [127:0] held_ifetch_data;
  reg [7:0] held_ifetch_id;
  integer byte_i;

  wire [63:0] araddr;
  wire [1:0] arburst;
  wire [3:0] arcache;
  wire [7:0] arid;
  wire [7:0] arlen;
  wire arlock;
  wire [2:0] arprot;
  wire [2:0] arsize;
  wire arvalid;
  wire arready;
  reg [127:0] rdata_q;
  reg [7:0] rid_q;
  reg rlast_q;
  reg [1:0] rresp_q;
  reg rvalid_q;
  wire rready;
  reg [63:0] raddr_q;
  reg [7:0] rbeats_left_q;

  wire [63:0] awaddr;
  wire [1:0] awburst;
  wire [3:0] awcache;
  wire [7:0] awid;
  wire [7:0] awlen;
  wire awlock;
  wire [2:0] awprot;
  wire [2:0] awsize;
  wire awvalid;
  wire awready;
  wire [127:0] wdata;
  wire wlast;
  wire [15:0] wstrb;
  wire wvalid;
  wire wready;
  reg aw_pending_q;
  reg [63:0] awaddr_q;
  reg [7:0] awid_q;
  reg bvalid_q;
  reg [7:0] bid_q;
  wire bready;

  wire halted;
  wire illegal;
  wire [63:0] debug_x31;
  wire [63:0] cycle_count;
  wire [63:0] instret_count;

  function [127:0] read128;
    input [63:0] addr;
    begin
      read128 = {mem[addr[19:3] + 1], mem[addr[19:3]]};
    end
  endfunction

  assign arready = !rvalid_q && rbeats_left_q == 0;
  assign awready = !aw_pending_q && !bvalid_q;
  assign wready = aw_pending_q && !bvalid_q;

  edge32_axi_core #(.ENABLE_FPU(1)) dut (
    .forever_cpuclk(clk), .cpurst_b(reset_n),
    .core_start(core_start),.core_force_stop(core_force_stop),
    .boot_pc(boot_pc),
    .biu_pad_araddr(araddr), .biu_pad_arburst(arburst),
    .biu_pad_arcache(arcache), .biu_pad_arid(arid),
    .biu_pad_arlen(arlen), .biu_pad_arlock(arlock),
    .biu_pad_arprot(arprot), .biu_pad_arsize(arsize),
    .biu_pad_arvalid(arvalid), .pad_biu_arready(arready),
    .pad_biu_rdata(rdata_q), .pad_biu_rid(rid_q),
    .pad_biu_rlast(rlast_q), .pad_biu_rresp(rresp_q),
    .pad_biu_rvalid(rvalid_q), .biu_pad_rready(rready),
    .biu_pad_awaddr(awaddr), .biu_pad_awburst(awburst),
    .biu_pad_awcache(awcache), .biu_pad_awid(awid),
    .biu_pad_awlen(awlen), .biu_pad_awlock(awlock),
    .biu_pad_awprot(awprot), .biu_pad_awsize(awsize),
    .biu_pad_awvalid(awvalid), .pad_biu_awready(awready),
    .pad_biu_bid(bid_q), .pad_biu_bresp(2'b00),
    .pad_biu_bvalid(bvalid_q), .biu_pad_bready(bready),
    .biu_pad_wdata(wdata), .biu_pad_wlast(wlast),
    .biu_pad_wstrb(wstrb), .biu_pad_wvalid(wvalid),
    .pad_biu_wready(wready), .halted(halted), .illegal(illegal),
    .dtcm_base(64'd0), .dtcm_mask(64'd0), .dtcm_enable(1'b0),
    .dtcm_lsu_ready(1'b0), .dtcm_lsu_rvalid(1'b0),
    .dtcm_lsu_rdata(64'd0), .accel_req_ready(1'b0),
    .accel_resp_valid(1'b0), .accel_resp_error(1'b0),
    .accel_resp_value(64'd0),
    .debug_x31(debug_x31), .cycle_count(cycle_count),
    .instret_count(instret_count)
  );

  always @(posedge clk) begin
    if (arvalid && arready) begin
      if (address_header_smoke) begin
        if (arid != 8'hf1 || araddr != 64'h1234_5678_0000_0000)
          $fatal(1, "instruction address header mismatch id=%h addr=%h",
                 arid, araddr);
        $display("PASS: AXI Edge-32 address header=%h", araddr[63:32]);
        $finish;
      end else if (address_header_software) begin
        if (reboot_phase && arid == 8'hf1 && araddr[63:32] == 0)
          saw_reboot_icache_refill <= 1;
        else if (reboot_phase && arid == 8'hd1 && araddr[63:32] == 0)
          saw_reboot_dcache_refill <= 1;
        else if (arid == 8'hf1 && araddr[63:32] == 32'h1234_5678)
          saw_new_icache_refill <= 1;
        else if (arid == 8'hd1 && araddr[63:32] == 32'h9abc_def0)
          saw_new_dcache_refill <= 1;
        else if (araddr[63:32] != 0)
          $fatal(1, "unexpected software header read id=%h addr=%h",
                 arid, araddr);
      end else if (araddr[63:32] != 0)
        $fatal(1, "scalar cache read escaped the 32-bit address window");
      if (arburst != 2'b01 || arsize != 3'd4 || arcache != 0 || arlock ||
          arprot != 0 || (arid == 8'hf1 && arlen != 0) ||
          (arid == 8'hd1 && arlen != 3))
        $fatal(1, "invalid lite AXI read attributes");
      if (force_stop_pending && arid == 8'hf1 && !held_ifetch_once) begin
        held_ifetch <= 1'b1;
        held_ifetch_once <= 1'b1;
        held_ifetch_data <= read128(araddr);
        held_ifetch_id <= arid;
      end else begin
        rdata_q <= read128(araddr);
        rid_q <= arid;
        rlast_q <= arlen == 0;
        rvalid_q <= 1'b1;
        raddr_q <= araddr + 64'd16;
        rbeats_left_q <= arlen;
      end
      if (arid == 8'hf1) icache_reads <= icache_reads + 1;
      else if (arid == 8'hd1) dcache_reads <= dcache_reads + 1;
      else $fatal(1, "unexpected lite AXI read ID=%h", arid);
    end else if (release_held_ifetch && held_ifetch && !rvalid_q) begin
      rdata_q <= held_ifetch_data;
      rid_q <= held_ifetch_id;
      rlast_q <= 1'b1;
      rvalid_q <= 1'b1;
      held_ifetch <= 1'b0;
    end else if (rvalid_q && rready) begin
      if (rbeats_left_q != 0) begin
        rdata_q <= read128(raddr_q);
        raddr_q <= raddr_q + 64'd16;
        rbeats_left_q <= rbeats_left_q - 1'b1;
        rlast_q <= rbeats_left_q == 1;
      end else begin
        rvalid_q <= 1'b0;
        rlast_q <= 1'b0;
      end
    end

    if (awvalid && awready) begin
      if (address_header_software && awaddr[63:32] == 0)
        saw_old_dcache_writeback <= 1;
      else if (awaddr[63:32] != 0)
        $fatal(1, "scalar cache write escaped the 32-bit address window");
      if (awburst != 2'b01 || awsize != 3'd4 || awlen != 0 ||
          awid != 8'hc1 || awcache != 0 || awlock || awprot != 0)
        $fatal(1, "invalid lite AXI write attributes");
      aw_pending_q <= 1'b1;
      awaddr_q <= awaddr;
      awid_q <= awid;
    end
    if (wvalid && wready) begin
      if (!wlast) $fatal(1, "lite dirty writeback must be one AXI beat");
      for (byte_i = 0; byte_i < 16; byte_i = byte_i + 1)
        if (wstrb[byte_i])
          mem[awaddr_q[19:3] + (byte_i >= 8)]
             [(byte_i % 8) * 8 +: 8] <= wdata[byte_i * 8 +: 8];
      aw_pending_q <= 1'b0;
      bvalid_q <= 1'b1;
      bid_q <= awid_q;
    end
    if (bvalid_q && bready) begin
      bvalid_q <= 1'b0;
      write_responses <= write_responses + 1;
    end
  end

  initial begin
    rdata_q = 0; rid_q = 0; rlast_q = 0; rresp_q = 0; rvalid_q = 0;
    raddr_q = 0; rbeats_left_q = 0; aw_pending_q = 0; awaddr_q = 0;
    awid_q = 0; bvalid_q = 0; bid_q = 0; icache_reads = 0;
    dcache_reads = 0; write_responses = 0;
    return_only = $test$plusargs("return_only");
    address_header_smoke = $test$plusargs("address_header_smoke");
    address_header_software = $test$plusargs("address_header_software");
    saw_old_dcache_writeback = 0;
    saw_new_dcache_refill = 0;
    saw_new_icache_refill = 0;
    reboot_phase = 0;
    saw_reboot_icache_refill = 0;
    saw_reboot_dcache_refill = 0;
    force_stop_pending = $test$plusargs("force_stop_pending");
    held_ifetch = 0;
    held_ifetch_once = 0;
    release_held_ifetch = 0;
    held_ifetch_data = 0;
    held_ifetch_id = 0;
    for (i = 0; i < MEM_WORDS; i = i + 1) mem[i] = 64'd0;
    if (!$value$plusargs("mem64=%s", mem64_file))
      $fatal(1, "pass +mem64=<coremark_bench.data64.memh>");
    $readmemh(mem64_file, mem);

    repeat (4) @(posedge clk);
    reset_n <= 1'b1;
    repeat (3) @(posedge clk);
    if (dut.icache_address_header != 0 || dut.dcache_address_header != 0)
      $fatal(1, "I/D address headers were not zero after reset");
    if (address_header_smoke)
      dut.cached_core.core.icache_address_header_q = 32'h1234_5678;
    if (arvalid) $fatal(1, "AXI fetch escaped before core_start");
    core_start <= 1'b1;
    @(posedge clk); core_start <= 1'b0;
    if (force_stop_pending) begin
      wait (held_ifetch);
      core_force_stop <= 1'b1;
      @(posedge clk); core_force_stop <= 1'b0;
      repeat (2) @(posedge clk);
      if (instret_count != 0 || debug_x31 != 0)
        $fatal(1, "force-stop allowed pending fetch to retire");
      release_held_ifetch <= 1'b1;
      wait (!held_ifetch && !rvalid_q);
      release_held_ifetch <= 1'b0;
      boot_pc <= 32'h0000_0080;
      core_start <= 1'b1;
      @(posedge clk); core_start <= 1'b0;
    end
    cycles = 0;
    while (!halted && cycles < TIMEOUT_CYCLES) begin
      @(posedge clk);
      cycles = cycles + 1;
    end
    if (!halted)
      $fatal(1, "AXI software timeout instret=%0d AR=%0d R=%0d held=%0d I_miss=%0d core_req=%0d front_pending=%0d",
             instret_count, arvalid, rvalid_q, held_ifetch,
             dut.cached_core.debug_icache_miss_pending,
             dut.cached_core.core_imem_req_valid,
             dut.cached_core.core.frontend.request_pending_q);
    if (illegal) $fatal(1, "AXI CoreMark reported illegal instruction");
    if (debug_x31 == 0) $fatal(1, "AXI CoreMark returned zero");
    if (address_header_software &&
        (!saw_old_dcache_writeback || !saw_new_dcache_refill ||
         !saw_new_icache_refill))
      $fatal(1, "software header sequence incomplete old_D_AW=%0d new_D_AR=%0d new_I_AR=%0d",
             saw_old_dcache_writeback, saw_new_dcache_refill,
             saw_new_icache_refill);
    if (address_header_software) begin
      reset_n <= 1'b0;
      repeat (4) @(posedge clk);
      if (dut.icache_address_header != 0 || dut.dcache_address_header != 0)
        $fatal(1, "I/D address headers were not zero during reboot reset");
      reset_n <= 1'b1;
      reboot_phase = 1;
      repeat (3) @(posedge clk);
      core_start <= 1'b1;
      @(posedge clk); core_start <= 1'b0;
      cycles = 0;
      while (!halted && cycles < TIMEOUT_CYCLES) begin
        @(posedge clk);
        cycles = cycles + 1;
      end
      if (!halted || illegal || debug_x31 == 0)
        $fatal(1, "software header reboot failed halted=%0d illegal=%0d x31=%0d",
               halted, illegal, debug_x31);
      if (!saw_reboot_icache_refill || !saw_reboot_dcache_refill)
        $fatal(1, "reset retained cache state I_refill=%0d D_refill=%0d",
               saw_reboot_icache_refill, saw_reboot_dcache_refill);
    end
    if (!return_only && instret_count != EDGE32_COREMARK_INSTRET)
      $fatal(1, "AXI CoreMark instret mismatch=%0d", instret_count);
    if (icache_reads == 0 || dcache_reads == 0)
      $fatal(1, "AXI CoreMark did not use both cache read IDs");
    $display("PASS: AXI Edge-32 software x31=%0d cycles=%0d instret=%0d I$AR=%0d D$AR=%0d B=%0d",
             debug_x31, cycle_count, instret_count, icache_reads,
             dcache_reads, write_responses);
    $finish;
  end
endmodule
