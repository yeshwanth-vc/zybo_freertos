# 
# Usage: To re-create this platform project launch xsct with below options.
# xsct /home/admin1/workspace/freertos_interrupt/platform.tcl
# 
# OR launch xsct and run below command.
# source /home/admin1/workspace/freertos_interrupt/platform.tcl
# 
# To create the platform in a different location, modify the -out option of "platform create" command.
# -out option specifies the output directory of the platform project.

platform create -name {freertos_interrupt}\
-hw {/media/admin1/967b2ee1-147e-40ca-8880-8e90880fb8c1/admin1/yeshwanth_ws/zybo_wrapper.xsa}\
-proc {ps7_cortexa9_0} -os {freertos10_xilinx} -fsbl-target {psu_cortexa53_0} -out {/home/admin1/workspace}

platform write
platform generate -domains 
platform active {freertos_interrupt}
platform generate
platform generate -domains freertos10_xilinx_domain 
platform generate -domains freertos10_xilinx_domain 
platform generate
platform clean
platform generate
platform generate -domains freertos10_xilinx_domain 
platform clean
platform generate
platform clean
platform generate
