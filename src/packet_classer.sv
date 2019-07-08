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

localparam EMPTY_WIDTH   = $clog2( AST_DWIDTH / 8 );
localparam PAT_WIDTH = REG_DEPTH - 1;

// grab and use data only when sink.ready = 1, wrken = 1, start = 1 (proper sop) and sink.valid = 1
logic is_valid;

// delayed end signal nulling for src_channel_o
logic delayed_sink_end;

// pattern of searching. Reversed becouse big-endian
logic [0:AMM_DWIDTH-1] pattern [0:PAT_WIDTH-1];
// reg[0][0] - Enable
logic                  wrken;
// matching signal
logic [PAT_WIDTH-1:0]  found_t;
logic [PAT_WIDTH-1:0]  found_k;

// searching area 
logic [AMM_DWIDTH-1:0] substring [REG_DEPTH-1:0];
logic [AMM_DWIDTH-1:0] substring_n [REG_DEPTH/2-1:0];

// start and fin of input packet
logic start;
logic fin;
logic start_next;
logic fin_next;

logic [AST_DWIDTH-1:0] sink_valid_data;

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
// AST 64 bits. Separating by 2 

// latch conter!!!!111!11
always_ff @( posedge clk_i )
  begin
    if( srst_i )
      begin
        substring_n[0] <= '0;
        substring_n[1] <= '0;
      end
    else
      begin
        substring_n[0] <= substring[0];
        substring_n[1] <= substring[1];
      end
  end
always_comb
  begin
    substring[0] = substring_n[0];
    substring[1] = substring_n[1];
    if( is_valid )
      begin
        substring[0] = sink_valid_data[AST_DWIDTH/2-1:0];
        substring[1] = sink_valid_data[AST_DWIDTH-1:AST_DWIDTH/2];
      end
  end
// end latch conter
always_ff @( posedge clk_i )
  begin
    if( srst_i )
      begin
        substring[2] <= '0;
        substring[3] <= '0;
      end
    else
      begin
        if( is_valid )
          begin
            substring[2] <= substring[0];
            substring[3] <= substring[1];
          end

      end
  end
// VARIABLE key word search someday
/*
generate
genvar i;
for( i = 2; i < PAT_WIDTH; i++ )
  begin : substring_pipeline
    always_ff @( posedge clk_i )
      begin
        if( srst_i )
          substring[i] <= '0;
        else
          begin : main_else
            if( start_next && sink_valid_i )
              substring[i] <= substring[i-1];
          end   : main_else
      end
  end  
endgenerate
*/
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
    if( sink_valid_i && sink_startofpacket_i && wrken && sink_ready_o )
      start_next = 1;
    else if( sink_valid_i && sink_endofpacket_i )
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
        if( &found_k || &found_t )
          src_channel_o <= '1;
        else if( src_endofpacket_o )
          src_channel_o <= '0;
      end   
  end

generate
  genvar k;
  genvar t;
  for( k = 0; k < PAT_WIDTH; k++ )
    begin : searching_start
      always_comb
        begin
          found_k[k] = '0;
          if( substring[k] == pattern[k] )
            found_k[k] = '1;
        end
    end
  for( t = 1; t <= PAT_WIDTH; t++ )
    begin : searching_end
      always_comb
        begin
          found_t[t-1] = '0;
          if( substring[t] == pattern[t-1] )
            found_t[t-1] = '1;
        end
    end
endgenerate

endmodule
