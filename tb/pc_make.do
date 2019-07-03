transcript on


vlib work

vlog -sv ../src/avalon_mm_if.sv
vlog -sv ../src/avalon_st_if.sv
vlog -sv ../src/control_register.sv
vlog -sv ../src/packet_classer.sv

vlog -sv ./packet_classer_tb.sv

vsim -novopt packet_classer_tb 

add wave /packet_classer_tb/clk_i
add wave /packet_classer_tb/srst_i

run -all

