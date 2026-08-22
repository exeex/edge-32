# Promote the closed 500 ps global-route profile to detailed routing.  Use the
# 0.12 um ASAP7 M4/M5 width-table entry for top-level pin shapes and replace
# synthesized constant sources with local tie cells before routing.
set profile_dir [file dirname [file normalize [info script]]]
source [file join $profile_dir asap7-edge32-div-native32-srt4-pipsign-tdp-cts8-lvt-2g.tcl]

set ::env(OPENROAD_PIN_HOR_SIZE) {0.12 0.024}
set ::env(OPENROAD_PIN_VER_SIZE) {0.024 0.12}
set ::env(OPENROAD_REPAIR_TIE_FANOUT) 1
set ::env(OPENROAD_SKIP_DETAILED_ROUTE) 0
