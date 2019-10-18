transcript on


vlib work

vlog -sv ../src/avalon_mm_if.sv
vlog -sv ../src/avalon_st_if.sv
vlog -sv ../src/fifo.sv
vlog -sv ../src/packet_resolver.sv

vlog -sv ./ast_src_driver_pkg.sv
vlog -sv ./ast_sink_driver_pkg.sv
vlog -sv ./ast_gen_pkg.sv
vlog -sv ./ast_arbiter_pkg.sv

vlog -sv ./packet_resolver_tb.sv

vsim -novopt packet_resolver_tb 

add wave /packet_resolver_tb/clk_i
add wave /packet_resolver_tb/srst_i

add wave /packet_resolver_tb/ast_src_if.ready
add wave -radix ascii /packet_resolver_tb/ast_src_if.data
add wave /packet_resolver_tb/ast_src_if.valid
add wave /packet_resolver_tb/ast_src_if.startofpacket
add wave /packet_resolver_tb/ast_src_if.endofpacket
add wave /packet_resolver_tb/ast_src_if.empty
add wave /packet_resolver_tb/ast_src_if.channel

add wave /packet_resolver_tb/ast_sink_if.ready
add wave -radix ascii /packet_resolver_tb/ast_sink_if.data
add wave /packet_resolver_tb/ast_sink_if.valid
add wave /packet_resolver_tb/ast_sink_if.startofpacket
add wave /packet_resolver_tb/ast_sink_if.endofpacket
add wave /packet_resolver_tb/ast_sink_if.empty
add wave /packet_resolver_tb/ast_sink_if.channel


add wave /packet_resolver_tb/DUT/*
add wave /packet_resolver_tb/DUT/dt_fifo/*


run -all

