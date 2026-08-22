# Measure a finer-grained CTS tree on the timing-driven placement candidate.
# Keep the strong x24 root, but use x8 branch buffers instead of an all-x24
# tree so local sink branches can be balanced with less overdrive.
set profile_dir [file dirname [file normalize [info script]]]
source [file join $profile_dir asap7-edge32-div-native32-srt4-pipsign-tdp-2g.tcl]

set ::env(OPENROAD_CTS_ROOT_BUF) BUFx24_ASAP7_75t_R
set ::env(OPENROAD_CTS_TREE_BUF) BUFx8_ASAP7_75t_R
