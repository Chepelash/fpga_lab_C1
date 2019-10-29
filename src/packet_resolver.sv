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

// FSM states

enum logic [1:0] { IDLE_S,
                   RD_S,
                   DCD_S,
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
//
typedef struct {
  logic                   sop;
  logic                   eop;
  logic [EMPTY_WIDTH-1:0] empty;
  logic [AST_DWIDTH-1:0]  data;
} out_data_t;

typedef struct {
  logic                    channel;
  logic [DFIFO_AWIDTH-1:0] cntr;
} out_stat_t;
// fifos
fifo        #(
  .DWIDTH    ( SFIFO_DWIDTH ),
  .AWIDTH    ( SFIFO_AWIDTH ),
  .SWIDTH    ( 1            ),
  .SHOWAHEAD ( "ON"         )
) st_fifo    (
  .clk_i     ( clk_i        ),
  .srst_i    ( srst_i       ),
  
  .rd_i      ( rd_sf        ),
  .wr_i      ( wr_sf        ),
  .wrdata_i  ( packet_stat  ),
  
  .shift_i   ( 1'b1         ),
  
  .empty_o   ( empty_sf     ),
  .full_o    ( full_sf      ),
  .rddata_o  ( q_sf         )
  
);


fifo        #(
  .DWIDTH    ( DFIFO_DWIDTH ),
  .AWIDTH    ( DFIFO_AWIDTH ),
  .SWIDTH    ( DFIFO_AWIDTH ),
  .SHOWAHEAD ( "ON"         )
) dt_fifo    (
  .clk_i     ( clk_i        ),
  .srst_i    ( srst_i       ),
  
  .rd_i      ( rd_df        ),
  .wr_i      ( wr_df        ),
  .wrdata_i  ( packet_data  ),
  
  .shift_i   ( shift_df     ),
  
  .empty_o   ( empty_df     ),
  .full_o    ( full_df      ),
  .rddata_o  ( q_df         ) 
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
// output logic
logic                    sop_out;
logic                    eop_out;
logic                    valid_out;
logic [AST_DWIDTH-1:0]   data_out;
logic [EMPTY_WIDTH-1:0]  empty_out;
// other
logic dcd_rd;
out_data_t out_data;
out_stat_t out_stat;
// 
assign packet_stat = { sink_if.channel, pcntr };
assign packet_data = { sink_if.startofpacket, sink_if.endofpacket,
                       sink_if.empty, sink_if.data };

////////////////////////////
// data fifo
assign out_data = out_data_t'(q_df);
assign sop_df      = out_data.sop;
assign eop_df      = out_data.eop;
assign emptyast_df = out_data.empty;
assign data_df     = out_data.data;
// stat fifo
assign out_stat = out_stat_t'(q_sf);
assign drop    = ~out_stat.channel;
assign step_sf = out_stat.cntr;

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
        if( eop_df && src_if.valid && src_if.ready )
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
      dcd_rd <= '0;
    else
      begin
        if( state == DCD_S && drop )
          dcd_rd <= '1;
        else
          dcd_rd <= '0;
      end
  end

always_comb
  begin
    if( ( ( state == TRNSM_S ) && src_if.ready && src_if.valid ) || dcd_rd )
      rd_df = '1;
    else
      rd_df = '0;
  end
 
// output valid signal
always_ff @( posedge clk_i )
  begin
    if( srst_i )
      valid_out <= '0;
    else
      begin
        if( state == TRNSM_S )
          begin
            if( eop_df && src_if.ready )
              valid_out <= '0;
            else
              valid_out <= '1;
          end
        else
          valid_out <= '0;
      end
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
