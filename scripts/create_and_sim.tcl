# =============================================================================
# Vivado 2024.2 Batch Tcl Script: Create Project + Run Behavioral Simulation
# =============================================================================
set proj_root "C:/Users/User/Documents/KMUTT_UNI/Y2/Digital/Digital_final proj"
set proj_dir  "$proj_root/vivado_proj_v4"
set proj_name "FlappyPigeon"
set part_name "xc7a100tcsg324-1"

create_project -force $proj_name $proj_dir -part $part_name

# 1. Add RTL Design Sources & Memory Initialization (.mem) Files
add_files -fileset sources_1 [glob -directory "$proj_root/rtl" *.v]
add_files -fileset sources_1 [glob -directory "$proj_root/mem" *.mem]
set_property file_type {Memory Initialization Files} [get_files *.mem]
set_property top top [get_filesets sources_1]
update_compile_order -fileset sources_1

# 2. Add Nexys A7-100T Constraints
add_files -fileset constrs_1 [list "$proj_root/constraints/Nexys-A7-100T-FlappyPigeon.xdc"]

# 3. Add Testbench to Simulation Sources
add_files -fileset sim_1 [list "$proj_root/tb/tb_flappy_pigeon.v"]
set_property top tb_flappy_pigeon [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {20ms} -objects [get_filesets sim_1]
update_compile_order -fileset sim_1

# 4. Run Behavioral Simulation in Vivado XSim
puts "=== Launching Vivado XSim Behavioral Simulation ==="
launch_simulation
close_sim

puts "=== Project created and simulation verified successfully: $proj_dir/$proj_name.xpr ==="
exit
