# Run the same pipelined-correction experiment at the 500 ps target period.
set profile_dir [file dirname [file normalize [info script]]]
source [file join $profile_dir asap7-edge32-div-native32-srt4-pipcorr-1g.tcl]
set ::env(OPENROAD_CLOCK_PERIOD) 500.0
