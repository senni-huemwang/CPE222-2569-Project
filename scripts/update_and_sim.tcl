set proj_root "C:/Users/User/Documents/KMUTT_UNI/Y2/Digital/Digital_final proj"
set proj_xpr  "$proj_root/vivado_proj_v3/FlappyPigeon.xpr"

open_project $proj_xpr
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "=== Launching Vivado XSim Behavioral Simulation ==="
launch_simulation
close_sim
puts "=== Simulation verified successfully ==="
exit
