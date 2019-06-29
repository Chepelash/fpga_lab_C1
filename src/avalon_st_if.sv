interface avalon_st_if #(
  parameter DATA_WIDTH    = 32,
  parameter CHANNEL_WIDTH = 1,
  parameter EMPTY_WIDTH   = $clog2( DATA_WIDTH / 8 )
)(
  input clk
);

logic                     ready;
logic [DATA_WIDTH-1:0]    data;
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
