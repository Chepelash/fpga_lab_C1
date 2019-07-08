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
localparam MIN_PCKT_SIZE = 60;
localparam MAX_PCKT_SIZE = 1514;
localparam MEM_OFFSET    = 190;

/*
  Actually, i need memory for 1 max packet. When 1 packet comes and it is valid, 
  module should start transmitting at eop high.
  But i need to create backpressure, when second packet is shorter, than first.
  
  Actually, module recieves only valid data, so there is no need to check it. 
  It happens at packet classer.
*/

///
logic wren;
logic [8:0] wrpntr;
logic [8:0] rdpntr;
logic start;
logic fin;
logic start_next;
logic fin_next;
logic shift;

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

// memory to store packets. 2**9 = 512. to store 2 packets. 1516 B / 8 = 190
ram_memory #(
  .DWIDTH   ( AST_DWIDTH  ),
  .AWIDTH   ( 9           )
) mem       (
  .clk_i    ( clk_i       ),
  
  .wren_i   ( wren        ),
  .wrpntr_i ( wrpntr      ),  
  .data_i   ( sink_data_i ),
  
  .rdpntr_i ( rdpntr      ),
  
  .q_o      ( src_data_o  )
);



////
assign wren = sink_ready_o & sink_valid_i & start_next;

// starting and ending conditions
always_ff @( posedge clk_i )
  begin
    if( srst_i )
      begin
        start <= '0;
        fin   <= '0;
      end
    else
      begin
        if( fin_next )
          begin
            start <= '0;
            fin   <= '0;
          end
        else
          begin
            start <= start_next;
            fin   <= fin_next;
          end
      end
  end

always_comb
  begin
    start_next = start;
    fin_next   = fin;
    if( fin )
      begin
        start_next = 0;
        fin_next   = 0;
      end
    if( sink_valid_i && sink_startofpacket_i && wrken_i && sink_ready_o )
      start_next = 1;
    else if( sink_valid_i && sink_endofpacket_i )
      fin_next = 1;    
  end

  
// wrpntr
always_ff @( posedge clk_i )
  begin
    if( srst_i )
      begin
        wrpntr <= '0;
      end
    else
      begin
        if( wren )
          wrpntr <= wrpntr + '1;
        else if( fin )
          wrpntr <= '0;
      end
  end
// rdpntr
always_ff @( posedge clk_i )
  begin
    if( srst_i )
      begin
        rdpntr <= '0;
      end
    else
      begin
        if( src_valid_o )
          rdpntr <= rdpntr + '1;
        else if( src_endofpacket_o )
          rdpntr <= '0;
      end
  end
//
// ready signal
always_ff @( posedge clk_i )
  begin
    if( srst_i )
      sink_ready_o <= '1;
    else
      begin
        /*
          ready must go down when module transmitting a packet,
          and next packet comes with sink_channel_i == 1 and it is shorter than first.
          Ready must go up after first packet finishes transmission.
        */
      end
  end
//
// shift signal
always_ff @( posedge clk_i )
  begin
    if( srst_i )
      shift <= '0;
    else
      begin
        if( sink_endofpacket_i && sink_channel_i )
          shift <= ~shift;
          
      end
  end

// transmitting


endmodule
