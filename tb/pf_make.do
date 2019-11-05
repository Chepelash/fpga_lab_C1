transcript on


vlib work

vlog -sv ../src/avalon_mm_if.sv
vlog -sv ../src/avalon_st_if.sv
vlog -sv ../src/control_register.sv
vlog -sv ../src/packet_filter.sv
vlog -sv ../src/packet_classer.sv
vlog -sv ../src/packet_resolver.sv
vlog -sv ../src/fifo.sv

vlog -sv ./tb_parameters_pkg.sv
vlog -sv ./amm_driver_pkg.sv
vlog -sv ./amm_arbiter_pkg.sv
vlog -sv ./amm_gen_pkg.sv

vlog -sv ./ast_src_driver_pkg.sv
vlog -sv ./ast_sink_driver_pkg.sv
vlog -sv ./ast_gen_pkg.sv
vlog -sv ./ast_arbiter_pkg.sv

vlog -sv ./packet_filter_tb.sv

vsim -novopt packet_filter_tb 

add wave /packet_filter_tb/clk_i
add wave /packet_filter_tb/srst_i
add wave -radix ascii /packet_filter_tb/DUT/pclasser/pattern
add wave /packet_filter_tb/DUT/pclasser/wrken

add wave /packet_filter_tb/amm_master_if.waitrequest
add wave -radix hex /packet_filter_tb/amm_master_if.address
add wave /packet_filter_tb/amm_master_if.write
add wave -radix ascii /packet_filter_tb/amm_master_if.writedata
add wave /packet_filter_tb/amm_master_if.read
add wave -radix ascii /packet_filter_tb/amm_master_if.readdata
add wave /packet_filter_tb/amm_master_if.readdatavalid

add wave /packet_filter_tb/ast_src_if.ready
add wave -radix ascii /packet_filter_tb/ast_src_if.data
add wave /packet_filter_tb/ast_src_if.valid
add wave /packet_filter_tb/ast_src_if.startofpacket
add wave /packet_filter_tb/ast_src_if.endofpacket
add wave /packet_filter_tb/ast_src_if.empty
add wave /packet_filter_tb/ast_src_if.channel

add wave /packet_filter_tb/ast_sink_if.ready
add wave -radix ascii /packet_filter_tb/ast_sink_if.data
add wave /packet_filter_tb/ast_sink_if.valid
add wave /packet_filter_tb/ast_sink_if.startofpacket
add wave /packet_filter_tb/ast_sink_if.endofpacket
add wave /packet_filter_tb/ast_sink_if.empty
add wave /packet_filter_tb/ast_sink_if.channel


run -all

