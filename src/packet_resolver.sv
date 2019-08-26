module packet_resolver #(
  parameter AST_DWIDTH    = 64,
  parameter CHANNEL_WIDTH =  1
  
)(
  input             clk_i,
  input             srst_i,
  
  
  avalon_st_if.src  src_if,
  
  avalon_st_if.sink sink_if
);

localparam EMPTY_WIDTH   = $clog2( AST_DWIDTH / 8 );
/*
  60 Bytes with AST_DWIDTH = 64. 60/8 = 7.5 so i guess min_PCKT_SIZE in dwords 64/8 = 8 
  1514 Bytes -//- max_PCKT_SIZE in dwords 1520/8 = 190
*/
localparam MIN_PCKT_SIZE = 8;
localparam MAX_PCKT_SIZE = 190;
// + 2 for sop, eop + EMPTY_WIDTH for empty
localparam DFIFO_DWIDTH   = AST_DWIDTH + 2 + EMPTY_WIDTH;
// 256 dwords
localparam DFIFO_AWIDTH   = 8;
// 1 for channel + DFIFO_AWIDTH for mem offset
localparam SFIFO_DWIDTH   = CHANNEL_WIDTH + DFIFO_AWIDTH;
localparam SFIFO_AWIDTH   = $clog2(  2**DFIFO_AWIDTH / MIN_PCKT_SIZE );
///
localparam EOP_IDX   = DFIFO_DWIDTH - 1;
localparam SOP_IDX   = DFIFO_DWIDTH - 2;
localparam EMPTY_IDX = AST_DWIDTH;
localparam DATA_IDX  = 0;

localparam CHNL_IDX = SFIFO_DWIDTH - CHANNEL_WIDTH;
localparam SHFT_IDX = 0;

// FSM states

enum logic [1:0] { IDLE_S,
                   RD_S,
                   DCD_S,
                   TRNSM_S } state, next_state;

// data_fifo signals
logic                       rd_data;
logic                       wr_data;
logic [DFIFO_DWIDTH-1:0]    packet_data;
logic [DFIFO_DWIDTH-1:0]    df_data;
logic [DFIFO_AWIDTH-1:0] df_shift;
logic                       df_empty;
logic                       df_full;
logic [DFIFO_AWIDTH-1:0] shift;

// stat_fifo signals
logic                    rd_stat;
logic                    wr_stat;
logic [SFIFO_DWIDTH-1:0] packet_stat;
logic [SFIFO_DWIDTH-1:0] sf_data;
logic                    sf_empty;
logic                    sf_full;

// parsed dfifo signals
logic                   val;
logic                   eop;
logic                   sop;
logic [EMPTY_WIDTH-1:0] empty;
logic [AST_DWIDTH-1:0]  data;

// parsed sfifo signals
logic [DFIFO_AWIDTH-1:0] pcntr;
logic                       channel;

// structures
assign packet_data = {sink_if.startofpacket, sink_if.endofpacket,
                      sink_if.empty, sink_if.data};
assign eop   = df_data[EOP_IDX];
assign sop   = df_data[SOP_IDX];
assign empty = df_data[EMPTY_IDX+:EMPTY_WIDTH];
assign data  = df_data[DATA_IDX+:AST_DWIDTH];

assign packet_stat = {sink_if.channel, pcntr};
assign shift       = sf_data[SHFT_IDX+:DFIFO_AWIDTH];
assign channel     = sf_data[CHNL_IDX+:CHANNEL_WIDTH];

// sink ready
assign sink_if.ready = ~df_full;

// FSM 

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
  .shift_i  ( df_shift     ),
  
  .empty_o  ( df_empty     ),
  .full_o   ( df_full      ),
  .rddata_o ( df_data      )  
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
  
  .empty_o  ( sf_empty     ),
  .full_o   ( sf_full      ),
  .rddata_o ( sf_data      )
);

// FSM
always_ff @( posedge clk_i )
  if( srst_i )
    state <= IDLE_S;
  else
    state <= next_state;

/*
{ IDLE_S,
  RD_S,
  DCD_S,
  TRNSM_S } state, next_state;
*/
always_comb
  begin
    next_state = state;
    case( state )
      IDLE_S: begin
        if( !sf_empty )
          next_state = RD_S;
      end
      
      RD_S: begin
        next_state = DCD_S;
      end
      
      DCD_S: begin
        if( ( !channel ) && !sf_empty )
          next_state = RD_S;
        else if( channel )
          next_state = TRNSM_S;
        else
          next_state = IDLE_S;
      end
      
      TRNSM_S: begin
        if( src_if.ready ) 
          begin
            if( eop && ( !sf_empty ) )
              next_state = RD_S;
            else if( eop && sf_empty )
              next_state = IDLE_S;  
          end              
      end
    endcase
  end
// sfifo control
//sfifo reading
always_ff @( posedge clk_i )
  begin
    if( srst_i )
      begin
        rd_stat <= '0;
      end
    else
      begin
        case( state )
          IDLE_S: begin
            rd_stat <= '0;
          end
          
          RD_S: begin
            rd_stat <= '1;
          end
          
          DCD_S: begin
            rd_stat <= '0;
          end
          
          TRNSM_S: begin
            rd_stat <= '0;
          end
        endcase
      end
  end
// sfifo writing
assign wr_stat = sink_if.ready & sink_if.endofpacket;
always_ff @( posedge clk_i )
  begin
    if( srst_i )
      begin
        pcntr <= '0;
      end
    else
      begin
        if( sink_if.ready && sink_if.valid && ( !sink_if.endofpacket ) )
          pcntr += 1'b1;
        else if( sink_if.ready && sink_if.endofpacket )
          pcntr <= '0;
      end
  end

//dfifo control
//dfifo reading
always_ff @( posedge clk_i )
  begin
    if( srst_i )
      begin
        rd_data  <= '0;
        df_shift <= 1'b1;
      end
    else
      begin
        case( state )
          IDLE_S: begin
            df_shift <= 1'b1;
            rd_data  <= '0;
            val <= '0;
          end
          
          RD_S: begin
            val <= '0;
            df_shift <= 1'b1;
            rd_data  <= '0;
          end
          
          DCD_S: begin
            val <= '0;
            rd_data <= '1;
            if( !channel )              
              df_shift <= shift;              
            else
              df_shift <= 1'b1;
          end
          
          TRNSM_S: begin
            if( eop )
              rd_data <= '0;
            else if( src_if.ready )
              rd_data <= '1;
            else
              rd_data <= '0;
            val <= '1;
            df_shift  <= 1'b1;
          end
        endcase
      end
  end
//dfifo writing
assign wr_data = sink_if.ready & sink_if.valid;

// TRANSMITTION
assign src_if.startofpacket = sop;
assign src_if.endofpacket   = eop;
assign src_if.data          = data;
assign src_if.empty         = empty;
assign src_if.valid         = val;
assign src_if.channel       = '0;

endmodule
