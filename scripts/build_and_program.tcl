# =============================================================================
# Vivado 2024.2 Batch Tcl Script: Synthesize, Implement, Write Bitstream & Flash
# =============================================================================
set proj_root "C:/Users/User/Documents/KMUTT_UNI/Y2/Digital/Digital_final proj"
set proj_xpr  "$proj_root/vivado_proj/FlappyPigeon.xpr"
set bit_copy  "$proj_root/FlappyPigeon.bit"

open_project $proj_xpr

puts "=== [1/3] Running Synthesis & Implementation -> Generate Bitstream ==="
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

set impl_status [get_property STATUS [get_runs impl_1]]
puts "Implementation Status: $impl_status"
if {![string match "*write_bitstream Complete!*" $impl_status]} {
    puts "ERROR: Bitstream generation did not complete cleanly ($impl_status)"
    exit 1
}

set bit_file "$proj_root/vivado_proj/FlappyPigeon.runs/impl_1/top.bit"
file copy -force $bit_file $bit_copy
puts "=== [2/3] Bitstream ready: $bit_copy ==="

puts "=== [3/3] Opening Hardware Manager & Programming Nexys A7-100T ==="
open_hw_manager
connect_hw_server -allow_non_jtag
set targets [get_hw_targets]
if {[llength $targets] == 0} {
    puts "ERROR: No FPGA JTAG hardware target detected. Check USB connection and power switch on Nexys A7-100T."
    close_hw_manager
    exit 2
}

open_hw_target [lindex $targets 0]
set dev [lindex [get_hw_devices xc7a100t*] 0]
if {$dev eq ""} {
    set dev [lindex [get_hw_devices] 0]
}
current_hw_device $dev
refresh_hw_device -update_hw_probes false $dev
set_property PROGRAM.FILE $bit_copy $dev
program_hw_devices $dev
puts "=== SUCCESS: Programmed $dev with $bit_copy ==="

close_hw_target
close_hw_manager
close_project
exit 0
