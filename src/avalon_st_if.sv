interface avalon_st_if #(
  parameter DWIDTH    = 64,
  parameter CHANNEL_WIDTH = 1,
  parameter EMPTY_WIDTH   = $clog2( DWIDTH / 8 )
)(

  input clk_i

);

logic                     ready;
logic [DWIDTH-1:0]        data;
logic                     valid;
logic                     startofpacket;
logic                     endofpacket;
logic [EMPTY_WIDTH-1:0]   empty;
logic [CHANNEL_WIDTH-1:0] channel;


modport sink (
  input  data,
  input  valid, 
  input  startofpacket, 
  input  endofpacket, 
  input  empty,
  input  channel,
  
  output ready  
);

modport src (
  input  ready,
  
  output data,
  output valid, 
  output startofpacket, 
  output endofpacket, 
  output empty,
  output channel
);

endinterface
