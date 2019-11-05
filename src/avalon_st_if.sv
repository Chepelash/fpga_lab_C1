interface avalon_st_if #(
  parameter DWIDTH    = 64,
  parameter CHANNEL_WIDTH = 1  
)(

  input clk_i

);

localparam EMPTY_WIDTH   = $clog2( DWIDTH / 8 );

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
  output data,
  output valid, 
  output startofpacket, 
  output endofpacket, 
  output empty,
  output channel,
  
  input  ready
);

endinterface
