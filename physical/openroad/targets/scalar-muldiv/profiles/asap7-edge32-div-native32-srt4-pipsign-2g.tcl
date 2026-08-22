# Hold geometry and the 500 ps target fixed while measuring the true low/high
# architectural sign pipeline.
set profile_dir [file dirname [file normalize [info script]]]
source [file join $profile_dir asap7-edge32-div-native32-srt4-pipcorr-2g.tcl]
