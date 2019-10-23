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
// sfifo should have entries number to store max values of min sized packets
//localparam SFIFO_AWIDTH   = 2**DFIFO_AWIDTH / MIN_PCKT_SIZE;
// value above is too large ( 2 ** 8 / 8 = 32 )
localparam SFIFO_AWIDTH   = 16;

// fifo data indexes
localparam SOP_IDX   = DFIFO_DWIDTH - 1;
localparam EOP_IDX   = DFIFO_DWIDTH - 2;
localparam EMPTY_IDX = AST_DWIDTH;
localparam DATA_IDX  = 0;
// stat fifo indexes
localparam CHNL_IDX = SFIFO_DWIDTH - CHANNEL_WIDTH;
localparam SHFT_IDX = 0;

// FSM states

enum logic [2:0] { IDLE_S,
                   RD_S,
                   DCD_S,
                   WAIT_S,
                   TRNSM_S } state, next_state;

// data fifo signals
// input
logic [DFIFO_DWIDTH-1:0] packet_data;
logic                    wr_df;
logic                    rd_df;
logic [DFIFO_AWIDTH-1:0] shift_df;
// output
logic [DFIFO_DWIDTH-1:0] q_df;
logic                    empty_df;
logic                    full_df;

// stat fifo signals
// input
logic [SFIFO_DWIDTH-1:0] packet_stat;
logic                    wr_sf;
logic                    rd_sf;
logic [DFIFO_AWIDTH-1:0] shift_sf;
// output
logic [SFIFO_DWIDTH-1:0] q_sf;
logic                    empty_sf;
logic                    full_sf;

// fifos
fifo       #(
  .DWIDTH   ( SFIFO_DWIDTH ),
  .AWIDTH   ( SFIFO_AWIDTH ),
  .SWIDTH   ( 1            )
) st_fifo   (
  .clk_i    ( clk_i        ),
  .srst_i   ( srst_i       ),
  
  .rd_i     ( rd_sf        ),
  .wr_i     ( wr_sf        ),
  .wrdata_i ( packet_stat  ),
  
  .shift_i  ( 1'b1         ),
  
  .empty_o  ( empty_sf     ),
  .full_o   ( full_sf      ),
  .rddata_o ( q_sf         )
  
);


fifo #(
  .DWIDTH   ( DFIFO_DWIDTH ),
  .AWIDTH   ( DFIFO_AWIDTH ),
  .SWIDTH   ( DFIFO_AWIDTH )
) dt_fifo   (
  .clk_i    ( clk_i        ),
  .srst_i   ( srst_i       ),
  
  .rd_i     ( rd_df        ),
  .wr_i     ( wr_df        ),
  .wrdata_i ( packet_data  ),
  
  .shift_i  ( shift_df     ),
  
  .empty_o  ( empty_df     ),
  .full_o   ( full_df      ),
  .rddata_o ( q_df         ) 
);

// parsing fifos out packets
// data fifo
logic                    sop_df;
logic                    eop_df;
logic [EMPTY_WIDTH-1:0]  emptyast_df;
logic [AST_DWIDTH-1:0]   data_df;
// stat fifo
logic                    drop;
logic [DFIFO_AWIDTH-1:0] step_sf;
//
logic [DFIFO_AWIDTH-1:0] pcntr;
logic [DFIFO_AWIDTH-1:0] dcntr;
logic [DFIFO_AWIDTH-1:0] ncntr;
// output logic
logic                    sop_out;
logic                    eop_out;
logic                    valid_out;
logic [AST_DWIDTH-1:0]   data_out;
logic [EMPTY_WIDTH-1:0]  empty_out;
// other
logic valid_df;
logic go;

// 
assign packet_stat = { sink_if.channel, pcntr };
assign packet_data = { sink_if.startofpacket, sink_if.endofpacket,
                       sink_if.empty, sink_if.data };

////////////////////////////
// data fifo
assign sop_df      = q_df[SOP_IDX];
assign eop_df      = q_df[EOP_IDX];
assign emptyast_df = q_df[EMPTY_IDX+:EMPTY_WIDTH];
assign data_df     = q_df[DATA_IDX+:AST_DWIDTH];
// stat fifo
assign drop    = ~q_sf[CHNL_IDX+:CHANNEL_WIDTH];
assign step_sf = q_sf[SHFT_IDX+:DFIFO_AWIDTH];

// FSM
always_ff @( posedge clk_i )
  begin
    if( srst_i )
      state <= IDLE_S;
    else
      state <= next_state;
  end

always_comb
  begin
    next_state = state;
    
    case( state )
      IDLE_S: begin
        if( ~empty_sf )
          next_state = RD_S;
      end
      
      RD_S: begin
        next_state = WAIT_S;
      end
      
      WAIT_S: begin
        next_state = DCD_S;
      end
      
      DCD_S: begin
        if( !drop )
          next_state = TRNSM_S;
        else if( drop && ~empty_sf )
          next_state = RD_S;
        else
          next_state = IDLE_S;
      end
      TRNSM_S: begin
        if( eop_df )
          begin
            if( ~empty_sf )
              next_state = RD_S;
            else
              next_state = IDLE_S;
          end
      end
    endcase
    
  end
// sfifo signals
always_ff @( posedge clk_i )
  begin
    if( srst_i )
      begin
        rd_sf <= '0;
      end
    else
      begin
        if( state == RD_S )
          rd_sf <= '1;
        else
          rd_sf <= '0;
      end
  end
//dfifo signals
always_ff @( posedge clk_i )
  begin
    if( srst_i )
      begin
        shift_df    <= '0;
        shift_df[0] <= '1;
      end
      
    else
      begin
        if( state == DCD_S )
          begin
            if( drop )
              shift_df <= step_sf;
            else
              begin
                shift_df    <= '0;
                shift_df[0] <= 1'b1;
              end
              
          end
          
        else if( state == TRNSM_S )
          begin
            shift_df    <= '0;
            shift_df[0] <= 1'b1;
            end
        else
          begin
            shift_df    <= '0;
            shift_df[0] <= 1'b1;
          end
      end
  end

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      rd_df <='0;
    else
      begin
        if( state == DCD_S )
          rd_df <= '1;
        else if( ( state == TRNSM_S ) && go && src_if.ready )
          rd_df <= '1;
        else
          rd_df <= '0;
      end
    
  end
  
// go - constraining rd_df signal
assign go = ( ncntr < ( dcntr - 2'd2 )) ? '1 : '0;

// ncntr - counting output packets 
always_ff @( posedge clk_i )
  begin
    if( srst_i )
      ncntr <= '0;
    else
      begin
        if( state == DCD_S )
          ncntr <= '0;
        else if( src_if.valid && src_if.ready )
          ncntr <= ncntr + 1'b1;
      end
  end
// output valid signal
always_ff @( posedge clk_i )
  begin
    if( srst_i )
      valid_out <= '0;
    else
      begin
        if( state == TRNSM_S )
          valid_out <= rd_df;
        else
          valid_out <= '0;
      end
  end


// dcntr - saving number of packets in current packet
always_ff @( posedge clk_i )
  begin
    if( srst_i )
      dcntr <= '0;
    else
      if( rd_sf )
        dcntr <= step_sf;
  end
                          
// pcntr - counting incoming packets
always_ff @( posedge clk_i )
  begin
    if( srst_i )
      pcntr <= '0 + 1'b1;
    else
      begin
        if( sink_if.endofpacket && sink_if.ready )
          pcntr <= '0 + 1'b1;
        else if( sink_if.valid && sink_if.ready )
          pcntr += 1'b1;        
      end
  end


assign wr_sf = sink_if.endofpacket & sink_if.ready;
assign wr_df = sink_if.valid & sink_if.ready;  
  
assign src_if.startofpacket = sop_df;
assign src_if.endofpacket   = eop_df;
assign src_if.data          = data_df;
assign src_if.empty         = emptyast_df;
assign src_if.valid         = valid_out;
assign src_if.channel       = '0;

assign sink_if.ready = ~full_df;

endmodule
