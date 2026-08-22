# Keep the accepted 500 ps sign-pipeline implementation and physical geometry,
# then bias analytical placement only toward the small critical-net population.
# Padding and repair margins intentionally remain at the accepted baseline so
# this profile measures timing-driven placement as a single backend variable.
set profile_dir [file dirname [file normalize [info script]]]
source [file join $profile_dir asap7-edge32-div-native32-srt4-pipsign-2g.tcl]

set ::env(OPENROAD_GLOBAL_PLACEMENT_TIMING_DRIVEN) 1
set ::env(OPENROAD_GLOBAL_PLACEMENT_TIMING_NETS_PERCENTAGE) 5
set ::env(OPENROAD_GLOBAL_PLACEMENT_TIMING_NET_WEIGHT_MAX) 3
set ::env(OPENROAD_GLOBAL_PLACEMENT_TIMING_REWEIGHT_OVERFLOW) {50 30 15}
set ::env(OPENROAD_GLOBAL_PLACEMENT_KEEP_RESIZE_BELOW_OVERFLOW) 0.20
