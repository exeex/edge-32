# Start from the measured edge-rv-lite folded-SRT probe geometry.
set ::env(OPENROAD_DIE_AREA) "0 0 105 105"
set ::env(OPENROAD_CORE_AREA) "2 2 103 103"
set ::env(OPENROAD_PIN_REGION) "2 2 103 103"
set ::env(OPENROAD_FLOORPLAN_TCL) "/work/synth/openroad/floorplans/standard_cell_only.tcl"
set ::env(OPENROAD_CLOCK_PORT) "clk"
# The edge-rv-lite 500 ps probe does not close after composition with the RV32
# adapter (post-route WNS was -406.6 ps).  Establish the first legal baseline
# at 1 ns before attempting divider-specific pipeline/floorplan changes.
set ::env(OPENROAD_CLOCK_PERIOD) 1000.0
set ::env(OPENROAD_GLOBAL_PLACEMENT_DENSITY) 0.55
set ::env(OPENROAD_STOP_AFTER_MACRO_PLACEMENT) 0
set ::env(OPENROAD_REPAIR_DESIGN) 1
set ::env(OPENROAD_REPAIR_TIMING_SETUP) 1
set ::env(OPENROAD_REPAIR_TIMING_POST_GLOBAL_ROUTE) 1
set ::env(OPENROAD_REPAIR_TIMING_SETUP_MARGIN) 10.0
set ::env(OPENROAD_REPAIR_TIMING_HOLD_POST_GLOBAL_ROUTE) 1
set ::env(OPENROAD_SKIP_CTS) 0
set ::env(OPENROAD_CLOCK_ROUTING_LAYERS) "M6-M9"
set ::env(OPENROAD_SKIP_GLOBAL_ROUTE) 0
set ::env(OPENROAD_SKIP_DETAILED_ROUTE) 1
