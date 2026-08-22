# Keep the accepted merged-correction floorplan fixed while probing an ASAP7
# level-sensitive latch only at the QDS-to-CSA boundary.
set profile_dir [file dirname [file normalize [info script]]]
source [file join $profile_dir asap7-edge32-div-native32-srt4-mergecorr.tcl]
