module edge_dcache_lookup_scheduler_tb;
  reg c0v, c0c, c0h, c0p, c1v, c1c, c1h, c1p;
  reg hit_ready, miss_ready;
  reg oldest_index;
  wire select_valid, select_index, select_hit, park_candidate0;

  edge_dcache_lookup_scheduler dut (
    .oldest_index(oldest_index),
    .candidate0_valid(c0v), .candidate0_classified(c0c),
    .candidate0_hit(c0h), .candidate0_phase_match(c0p),
    .candidate1_valid(c1v), .candidate1_classified(c1c),
    .candidate1_hit(c1h), .candidate1_phase_match(c1p),
    .hit_ready(hit_ready), .miss_ready(miss_ready),
    .select_valid(select_valid), .select_index(select_index),
    .select_hit(select_hit), .park_candidate0(park_candidate0)
  );

  task check_outputs;
    input ev, ei, eh, ep;
    input [383:0] msg;
    begin
      #1;
      if (select_valid !== ev || select_index !== ei ||
          select_hit !== eh || park_candidate0 !== ep) begin
        $display("TEST FAIL: %0s got=%b/%b/%b/%b expected=%b/%b/%b/%b",
          msg, select_valid, select_index, select_hit, park_candidate0,
          ev, ei, eh, ep);
        $finish;
      end
    end
  endtask

  initial begin
    c0v=0; c0c=0; c0h=0; c0p=0; c1v=0; c1c=0; c1h=0; c1p=0;
    hit_ready=1; miss_ready=1; oldest_index=0;
    check_outputs(0,0,0,0,"empty");
    c0v=1; c0c=1; c0h=1; c0p=1;
    check_outputs(1,0,1,0,"oldest hit");
    c0h=0; c0p=0;
    check_outputs(1,0,0,0,"miss ignores phase");
    miss_ready=0; c1v=1; c1c=1; c1h=1; c1p=1;
    check_outputs(1,1,1,1,"younger hit bypasses blocked miss");
    c1h=0;
    check_outputs(0,0,0,1,"second miss cannot bypass");
    c0h=1; c0p=0; miss_ready=1; c1h=1;
    check_outputs(0,0,1,0,"older phase wait preserves hit order");
    c0c=0;
    check_outputs(0,0,1,0,"unclassified oldest blocks bypass");
    c0v=0; c1h=0;
    check_outputs(1,1,0,0,"candidate1 miss recovers empty slot");
    c0v=1; c0c=1; c0h=1; c0p=1; c1h=1; hit_ready=0;
    check_outputs(0,0,1,0,"hit queue blocks both hits");
    hit_ready=1; miss_ready=0; oldest_index=1;
    c0v=1; c0c=1; c0h=1; c0p=1;
    c1v=1; c1c=1; c1h=0; c1p=0;
    check_outputs(1,0,1,1,"physical slot0 hit bypasses slot1 oldest miss");
    $display("EDGE_DCACHE_LOOKUP_SCHEDULER TEST PASS");
    $finish;
  end
endmodule
