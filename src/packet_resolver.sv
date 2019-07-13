module packet_resolver #(
  parameter AST_DWIDTH    = 64,
  parameter CHANNEL_WIDTH =  1
  
)(
  input             clk_i,
  input             srst_i,
  
  input             wrken_i,
  
  avalon_st_if.src  ast_src_if,
  
  avalon_st_if.sink ast_sink_if
);

localparam EMPTY_WIDTH   = $clog2( AST_DWIDTH / 8 );
/*
  60 Bytes with AST_DWIDTH = 64. 60/8 = 7.5 so i guess min_PCKT_SIZE in dwords 64/8 = 8 
  1514 Bytes -//- max_PCKT_SIZE in dwords 1520/8 = 190
*/
localparam MIN_PCKT_SIZE = 8;
localparam MAX_PCKT_SIZE = 190;
// + 2 for sop and eop
localparam FIFO_DWIDTH   = AST_DWIDTH + 2;
// 256 dwords
localparam FIFO_AWIDTH   = 8;

///
logic       wren;
// 9 - AWIDTH of ram_memory
logic       start;
logic       fin;
logic       start_next;
logic       fin_next;

// avalon st reassigning
// sink
logic                     sink_ready_o;
logic [AST_DWIDTH-1:0]    sink_data_i;
logic                     sink_valid_i;
logic                     sink_startofpacket_i;
logic                     sink_endofpacket_i;
logic [EMPTY_WIDTH-1:0]   sink_empty_i;
logic [CHANNEL_WIDTH-1:0] sink_channel_i;

// src
logic                     src_ready_i;
logic [AST_DWIDTH-1:0]    src_data_o;
logic                     src_valid_o;
logic                     src_startofpacket_o;
logic                     src_endofpacket_o;
logic [EMPTY_WIDTH-1:0]   src_empty_o;
logic [CHANNEL_WIDTH-1:0] src_channel_o;

assign ast_sink_if.ready        = sink_ready_o;
assign sink_data_i              = ast_sink_if.data;
assign sink_valid_i             = ast_sink_if.valid;
assign sink_startofpacket_i     = ast_sink_if.startofpacket;
assign sink_endofpacket_i       = ast_sink_if.endofpacket;
assign sink_empty_i             = ast_sink_if.empty;
assign sink_channel_i           = ast_sink_if.channel;

assign src_ready_i              = ast_src_if.ready;
assign ast_src_if.data          = src_data_o;
assign ast_src_if.valid         = src_valid_o;
assign ast_src_if.startofpacket = src_startofpacket_o;
assign ast_src_if.endofpacket   = src_endofpacket_o;
assign ast_src_if.empty         = src_empty_o;
assign ast_src_if.channel       = src_channel_o;

fifo #(
  .DWIDTH ( FIFO_DWIDTH ),
  .AWIDTH ( FIFO_AWIDTH )
) data_fifo (
  .clk_i ( clk_i ),
  .
);

fifo #(
) stat_fifo (
);



endmodule
