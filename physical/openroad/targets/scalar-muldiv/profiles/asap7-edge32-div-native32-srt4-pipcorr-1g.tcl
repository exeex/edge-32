# Keep the accepted merged-correction geometry fixed while measuring the
# normalized-input cleanup and true low/high correction pipeline.
set profile_dir [file dirname [file normalize [info script]]]
source [file join $profile_dir asap7-edge32-div-native32-srt4-mergecorr.tcl]
