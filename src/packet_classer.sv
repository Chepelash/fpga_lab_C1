module packet_classer #(
  parameter          AMM_DWIDTH    = 32,
  parameter          AST_DWIDTH    = 64,
  parameter          CHANNEL_WIDTH = 1,
  parameter          REG_DEPTH     = 4
)(
  input              clk_i,
  input              srst_i,
  
  avalon_mm_if.slave amm_slave_if,
  
  avalon_st_if.src   ast_src_if,
  
  avalon_st_if.sink  ast_sink_if 
);

localparam EMPTY_WIDTH = $clog2( AST_DWIDTH / 8 );
localparam PAT_WIDTH   = REG_DEPTH - 1;
localparam PAT_SIZE    = AMM_DWIDTH * PAT_WIDTH;
localparam SEARCH_SIZE = AST_DWIDTH*2 - PAT_SIZE;

// grab and use data only when sink.ready = 1, wrken = 1, start = 1 (proper sop) and sink.valid = 1
logic                      is_valid;

// pattern of searching. Reversed becouse big-endian
logic [0:PAT_SIZE-1]       pattern;
// reg[0][0] - Enable
logic                      wrken;
// matching signal
logic [SEARCH_SIZE-1:0]    found;

// searching area 
logic [AST_DWIDTH*2 - 1:0] substring;
logic [AST_DWIDTH-1:0]     pre_data;

// start and fin of input packet
logic                      start;
logic                      start_next;
logic                      fin_next;

logic [AST_DWIDTH-1:0]     sink_valid_data;

// avalon st reassigning
// sink
logic                      sink_ready_o;
logic [AST_DWIDTH-1:0]     sink_data_i;
logic                      sink_valid_i;
logic                      sink_startofpacket_i;
logic                      sink_endofpacket_i;
logic [EMPTY_WIDTH-1:0]    sink_empty_i;
logic [CHANNEL_WIDTH-1:0]  sink_channel_i;

// src
logic                      src_ready_i;
logic [AST_DWIDTH-1:0]     src_data_o;
logic                      src_valid_o;
logic                      src_startofpacket_o;
logic                      src_endofpacket_o;
logic [EMPTY_WIDTH-1:0]    src_empty_o;
logic [CHANNEL_WIDTH-1:0]  src_channel_o;

// avalon delays
/*
  in 'worst' case searched data comes with last word. 1 tick is needed to check matches, 
  another one tick needed to grab found signal by src_channel_o. Data from sink to src should be delayed 
  by 2 ticks, becouse decision is made at high 'endofpacket' signal.
  ready and channel_o should not be delayed
*/

logic [AST_DWIDTH-1:0]    d_sink_data_i;
logic                     d_sink_valid_i;
logic                     d_sink_startofpacket_i;
logic                     d_sink_endofpacket_i;
logic [EMPTY_WIDTH-1:0]   d_sink_empty_i;
logic [CHANNEL_WIDTH-1:0] d_sink_channel_i;


assign ast_sink_if.ready    = sink_ready_o;
assign sink_data_i          = ast_sink_if.data;
assign sink_valid_i         = ast_sink_if.valid;
assign sink_startofpacket_i = ast_sink_if.startofpacket;
assign sink_endofpacket_i   = ast_sink_if.endofpacket;
assign sink_empty_i         = ast_sink_if.empty;
assign sink_channel_i       = ast_sink_if.channel;

assign src_ready_i              = ast_src_if.ready;
assign ast_src_if.data          = src_data_o;
assign ast_src_if.valid         = src_valid_o;
assign ast_src_if.startofpacket = src_startofpacket_o;
assign ast_src_if.endofpacket   = src_endofpacket_o;
assign ast_src_if.empty         = src_empty_o;
assign ast_src_if.channel       = src_channel_o;
// end avalon st reassigning

assign is_valid = sink_ready_o & wrken & start_next & sink_valid_i;
assign sink_ready_o = src_ready_i;

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      begin
       // sink
        d_sink_data_i          <= '0;
        d_sink_valid_i         <= '0;
        d_sink_startofpacket_i <= '0;
        d_sink_endofpacket_i   <= '0;
        d_sink_empty_i         <= '0;
        d_sink_channel_i       <= '0;

      end
    else
      begin : main_else
        // first
        d_sink_data_i          <= sink_data_i;
        d_sink_valid_i         <= sink_valid_i;
        d_sink_startofpacket_i <= sink_startofpacket_i;
        d_sink_endofpacket_i   <= sink_endofpacket_i;
        d_sink_empty_i         <= sink_empty_i;
        d_sink_channel_i       <= sink_channel_i;
        // second
        src_data_o          <= d_sink_data_i;
        src_valid_o         <= d_sink_valid_i;
        src_startofpacket_o <= d_sink_startofpacket_i;
        src_endofpacket_o   <= d_sink_endofpacket_i;
        src_empty_o         <= d_sink_empty_i;

        
      end   : main_else
  end

/////////////////


// avalon mm module 
control_register #(
  .REG_WIDTH      ( AMM_DWIDTH   ),
  .REG_DEPTH      ( REG_DEPTH    )
) cntr_regs       (
  .clk_i          ( clk_i        ),
  .srst_i         ( srst_i       ),
  
  .amm_slave_if   ( amm_slave_if ),
  
  .pattern_o      ( pattern      ),
  .wrken_o        ( wrken        )
);




// data flow in substring. It's a pipeline

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      pre_data <= '0;
    else
      pre_data <= substring[AST_DWIDTH-1:0];
  end
always_comb
  begin
    substring[AST_DWIDTH-1:0] = pre_data;
    if( is_valid )
      substring[AST_DWIDTH-1:0] = sink_valid_data;
  end

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      substring[AST_DWIDTH*2-1:AST_DWIDTH] <= '0;
    else
      begin
        if( is_valid ) 
          substring[AST_DWIDTH*2-1:AST_DWIDTH] <= substring[AST_DWIDTH-1:0];
      end
  end

// starting and ending conditions
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
    if( sink_valid_i && sink_startofpacket_i && wrken && sink_ready_o )
      start_next = 1;
    else if( sink_valid_i && sink_endofpacket_i && sink_ready_o && start )
      fin_next = 1;    
  end

  
  
// grabbing valid data
always_comb
  begin
    sink_valid_data = '0;
    if( is_valid )
      sink_valid_data = sink_data_i;
  end

// searching for matches

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      src_channel_o <= '0;
    else
      begin 
        if( |found )
          src_channel_o <= '1;
        else if( src_endofpacket_o )
          src_channel_o <= '0;
      end   
  end

generate
  genvar n;
  for( n = 0; n < SEARCH_SIZE; n++ )
    begin : pat_search
      always_comb
        begin
          found[n] = '0;
          if( substring[PAT_SIZE+n-1:n] == pattern )
            found[n] = '1;
        end
    end
endgenerate

endmodule
