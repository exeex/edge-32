# Retain RVT-only synthesis, timing-driven placement, and the x8 CTS branch
# candidate.  Expose matching LVT cells only to OpenROAD so repair_timing may
# swap critical combinational cells without converting the whole block.
set profile_dir [file dirname [file normalize [info script]]]
source [file join $profile_dir asap7-edge32-div-native32-srt4-pipsign-tdp-cts8-2g.tcl]

set asap7_nldm /OpenROAD-flow-scripts/flow/platforms/asap7/lib/NLDM
set asap7_lvt_lef \
  /OpenROAD-flow-scripts/flow/platforms/asap7/lef/asap7sc7p5t_28_L_1x_220121a.lef
set ::env(OPENROAD_EXTRA_LEFS) \
  "$::env(OPENROAD_EXTRA_LEFS):$asap7_lvt_lef"
set lvt_timing_libs [list \
  [file join $asap7_nldm asap7sc7p5t_AO_LVT_TT_nldm_211120.lib.gz] \
  [file join $asap7_nldm asap7sc7p5t_INVBUF_LVT_TT_nldm_220122.lib.gz] \
  [file join $asap7_nldm asap7sc7p5t_OA_LVT_TT_nldm_211120.lib.gz] \
  [file join $asap7_nldm asap7sc7p5t_SEQ_LVT_TT_nldm_220123.lib] \
  [file join $asap7_nldm asap7sc7p5t_SIMPLE_LVT_TT_nldm_211120.lib.gz]]
set ::env(OPENROAD_TIMING_LIBERTIES) \
  "$::env(OPENROAD_LIBERTIES):[join $lvt_timing_libs :]"
