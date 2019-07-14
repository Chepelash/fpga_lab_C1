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
// + 2 for sop and eop, + EMPTY_WIDTH for empty
localparam DFIFO_DWIDTH   = AST_DWIDTH + 2 + EMPTY_WIDTH;
// 256 dwords
localparam DFIFO_AWIDTH   = 8;
// 1 for channel + DFIFO_AWIDTH for mem offset
localparam SFIFO_DWIDTH   = CHANNEL_WIDTH + DFIFO_AWIDTH;
localparam SFIFO_AWIDTH   = 8;


///

enum logic [1:0] { IDLE_S,
                   RDSTAT_S,
                   TRANSMIT_S } state, next_state;
// 

logic                    start;
logic                    fin;
logic                    start_next;
logic                    fin_next;
logic                    is_valid;
// dfifo signals
logic                    rd_data;
logic                    wr_data;
logic                    dfifo_empty;
logic                    dfifo_full;
logic [DFIFO_DWIDTH-1:0] dfifo_data;
logic [DFIFO_AWIDTH-1:0] dfifo_shift;
logic [DFIFO_DWIDTH-1:0] packet_data;
// sfifo signals
logic                    rd_stat;
logic                    wr_stat;
logic                    sfifo_empty;
logic                    sfifo_full;
logic [SFIFO_DWIDTH-1:0] packet_stat;
logic [SFIFO_DWIDTH-1:0] sfifo_data;

logic [DFIFO_AWIDTH-1:0] dword_cntr;

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

/*
  HOW SHIFT WORKS
  ---------------
  e.g. read pointer in dfifo at 0. We have read from sfifo 'b1 ( channel ) 10000, so 
  shift should be 1 for transmittiong every dword from dfifo.
  When data chunk from sfifo 'b0 ( channel ) 01010 this means that 1010 dwords in dfifo 
  must be droped ( mustn't be transmitted ), so read pointer 
  in dfifo should shift by 1010.
*/


fifo #(
  .DWIDTH   ( DFIFO_DWIDTH ),
  .AWIDTH   ( DFIFO_AWIDTH )
) data_fifo (
  .clk_i    ( clk_i        ),
  .srst_i   ( srst_i       ),
  
  .rd_i     ( rd_data      ),
  .wr_i     ( wr_data      ),
  .wrdata_i ( packet_data  ),
  .shift_i  ( dfifo_shift  ),
  
  .empty_o  ( dfifo_empty  ),
  .full_o   ( dfifo_full   ),
  .rddata_o ( dfifo_data   )  
);

fifo #(
  .DWIDTH   ( SFIFO_DWIDTH ),
  .AWIDTH   ( SFIFO_AWIDTH )
) stat_fifo (
  .clk_i    ( clk_i        ),
  .srst_i   ( srst_i       ),
  
  .rd_i     ( rd_stat      ),
  .wr_i     ( wr_stat      ),
  .wrdata_i ( packet_stat  ),
  // stat fifo should read every value
  .shift_i  ( '1           ),
  
  .empty_o  ( sfifo_empty  ),
  .full_o   ( sfifo_full   ),
  .rddata_o ( sfifo_data   )
);

// valid start and fin
always_ff @( posedge clk_i )
  begin
    if( srst_i )
      start <= '0;      
    else
      begin
        if( fin_next )
          start <= '0;
        else
          start <= start_next;
      end
  end

always_comb
  begin
    start_next = start;
    fin_next   = 0;    
    if( sink_valid_i && sink_startofpacket_i && wrken_i && sink_ready_o )
      start_next = 1;
    else if( sink_valid_i && sink_endofpacket_i && sink_ready_o && start )
      fin_next = 1;    
  end

// valid signal
assign is_valid = start_next & sink_ready_o & sink_valid_i;

// ready signal
assign sink_ready_o = src_ready_i & ( ~dfifo_full ) & ( ~sfifo_full );

// packet_stat
assign packet_stat = {dword_cntr, sink_channel_i};


// sfifo wren
assign wr_stat = fin_next;

// dfifo wren
assign wr_data = is_valid & ( ~dfifo_full );

// dfifo data
assign packet_data = {sink_startofpacket_i, sink_endofpacket_i,
                      sink_empty_i, sink_data_i};

// writing to sfifo. dword_cntr starts from 1, becouse dfifo rdpntr shift.
/*
  e.g. 6 dwords should be droped
  rdpntr | cntr
->0      | 1
  1      | 2 
  2      | 3
  3      | 4
  4      | 5
  5      | 6
->6      | 1
*/
always_ff @( posedge clk_i )
  begin
    if( srst_i )
      dword_cntr <= '1;
    else
      begin
        // end of valid packet
        if( fin_next )
          dword_cntr <= '1;
        // dfifo wren 
        else if( wr_data )
          dword_cntr <= dword_cntr + 1'b1;
      end
  end
// reading
/*
  FSM
*/

//
always_ff @( posedge clk_i )
  if( srst_i )
    state <= IDLE_S;
  else
    state <= next_state;
//
always_comb
  begin
    next_state = state;
    
    case( state )
      IDLE_S: begin
        if( ~sfifo_empty )
          next_state = RDSTAT_S;          
      end
      
      RDSTAT_S: begin
        //  channel
        if( packet_stat[0] == '0 && sfifo_empty )
          next_state = IDLE_S;
        else if( packet_stat[0] == '1 )
          next_state = TRANSMIT_S;
      end
      
      TRANSMIT_S: begin
        // eop
        if( dfifo_data[DFIFO_DWIDTH-2] == '1 && ( ~sfifo_empty ) )
          next_state = RDSTAT_S;
        else if( dfifo_data[DFIFO_DWIDTH-1] == '1 && sfifo_empty )
          next_state = IDLE_S;
      end
    endcase
  end
// outputs
always_ff @( posedge clk_i )
  begin
    case( state )
      IDLE_S: begin
        src_data_o          <= '0;
        src_valid_o         <= '0;
        src_startofpacket_o <= '0;
        src_endofpacket_o   <= '0;
        src_empty_o         <= '0;
        src_channel_o       <= '0;
      end
      
      RDSTAT_S: begin
        src_data_o          <= '0;
        src_valid_o         <= '0;
        src_startofpacket_o <= '0;
        src_endofpacket_o   <= '0;
        src_empty_o         <= '0;
        src_channel_o       <= '0;
      end
//      assign packet_data = {sink_startofpacket_i, sink_endofpacket_i,
//                      sink_empty_i, sink_data_i};
      TRANSMIT_S: begin
        src_data_o          <= dfifo_data[AST_DWIDTH-1:0];
        src_valid_o         <= '1;
        src_startofpacket_o <= dfifo_data[DFIFO_DWIDTH-1];
        src_endofpacket_o   <= dfifo_data[DFIFO_DWIDTH-2];
        src_empty_o         <= dfifo_data[DFIFO_DWIDTH-3-:EMPTY_WIDTH];
        src_channel_o       <= '0;
      end
    endcase
  end

// sfifo and dfifo signals
/*
fifo #(
  .DWIDTH   ( DFIFO_DWIDTH ),
  .AWIDTH   ( DFIFO_AWIDTH )
) data_fifo (
  .clk_i    ( clk_i        ),
  .srst_i   ( srst_i       ),
  
  .rd_i     ( rd_data      ),
  .wr_i     ( wr_data      ),
  .wrdata_i ( packet_data  ),
  .shift_i  ( dfifo_shift  ),
  
  .empty_o  ( dfifo_empty  ),
  .full_o   ( dfifo_full   ),
  .rddata_o ( dfifo_data   )  
);
*/
always_ff @( posedge clk_i )
  begin
    if( srst_i )
      begin
        rd_data <= '0;
        dfifo_shift <= 1'b1;
      end
    else
      begin
        case( state )
          IDLE_S: begin
            rd_data <= '0;
            dfifo_shift <= 1'b1;
          end
          
          RDSTAT_S: begin
            if( packet_stat[0] == '0 )
              begin
                rd_data     <= '1;
                dfifo_shift <= packet_stat[DFIFO_AWIDTH-1:0];
              end
            else
              begin
                rd_data     <= '0;
                dfifo_shift <= 1'b1;
              end
          end
          
          TRANSMIT_S: begin
            rd_data     <= '1;
            dfifo_shift <= 1'b1;
          end
          
        endcase
      end
  end
//
/*
fifo #(
  .DWIDTH   ( SFIFO_DWIDTH ),
  .AWIDTH   ( SFIFO_AWIDTH )
) stat_fifo (
  .clk_i    ( clk_i        ),
  .srst_i   ( srst_i       ),
  
  .rd_i     ( rd_stat      ),
  .wr_i     ( wr_stat      ),
  .wrdata_i ( packet_stat  ),
  // stat fifo should read every value
  .shift_i  ( '1           ),
  
  .empty_o  ( sfifo_empty  ),
  .full_o   ( sfifo_full   ),
  .rddata_o ( sfifo_data   )
);
*/
always_ff @( posedge clk_i )
  begin
    if( srst_i )
      rd_stat <= '0;
    else
      begin
        case( state )
          IDLE_S: begin
            rd_stat <= '0;
          end
          
          RDSTAT_S: begin
            rd_stat <= '1;
          end
          
          TRANSMIT_S: begin
            rd_stat <= '0;
          end
        endcase
      end
  end


endmodule
