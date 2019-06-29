module packet_classer #(
  parameter          DATA_WIDTH    = 32,
  parameter          CHANNEL_WIDTH = 1,
  parameter          REG_DEPTH     = 3
)(
  input              clk_i,
  input              srst_i,
  
  avalon_mm_if.slave amm_slave_if,
  
  avalon_st_if.src   ast_src_if,
  
  avalon_st_if.sink  ast_sink_if
);

localparam EMPTY_WIDTH   = $clog2( DATA_WIDTH / 8 );

// delayed end signal nulling for src_channel_o
logic delayed_sink_end;

// pattern of searching
logic [0:DATA_WIDTH-1] pattern [REG_DEPTH-1:0];
// reg[0][0] - Enable
logic                    wrken;

logic [REG_DEPTH-1:0] found;

// searching area 
logic [DATA_WIDTH-1:0] substring [REG_DEPTH-1:0];

// start and fin of input packet
logic start;
logic fin;

logic start_next;
logic fin_next;

logic [DATA_WIDTH-1:0] sink_valid_data;

// avalon st reassigning
// src
logic                     sink_ready_o;
logic [DATA_WIDTH-1:0]    sink_data_i;
logic                     sink_valid_i;
logic                     sink_startofpacket_i;
logic                     sink_endofpacket_i;
logic [EMPTY_WIDTH-1:0]   sink_empty_i;
logic [CHANNEL_WIDTH-1:0] sink_channel_i;

// sink
logic                     src_ready_i;
logic [DATA_WIDTH-1:0]    src_data_o;
logic                     src_valid_o;
logic                     src_startofpacket_o;
logic                     src_endofpacket_o;
logic [EMPTY_WIDTH-1:0]   src_empty_o;
logic [CHANNEL_WIDTH-1:0] src_channel_o;


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

// avalon mm module 
control_register #(
  .DATA_WIDTH     ( DATA_WIDTH   ),
  .REG_DEPTH      ( REG_DEPTH    )
) cntr_regs       (
  .clk_i          ( clk_i        ),
  .srst_i         ( srst_i       ),
  
  .amm_slave_if   ( amm_slave_if ),
  
  .pattern_o      ( pattern      ),
  .wrken_o        ( wrken        )
);

// streaming data from input to packet_resolver
assign src_data_o          = sink_data_i;
assign src_valid_o         = sink_valid_i;
assign src_startofpacket_o = sink_startofpacket_i;
assign src_endofpacket_o   = sink_endofpacket_i;
assign src_empty_o         = sink_empty_i; 
assign sink_ready_o = src_ready_i;

// data flow in substring. It's a pipeline
//always_ff @( posedge clk_i )
//  begin
//    if( srst_i )
//      substring[0] <= '0;
//    else
//      begin : main_else
//        if( start_next && sink_valid_i )
//          substring[0] <= sink_valid_data;
//      end   : main_else
//  end
assign substring[0] = sink_valid_data;
generate
genvar i;
for( i = 1; i < REG_DEPTH; i++ )
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
        if( fin )
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
    if( sink_valid_i && sink_startofpacket_i )
      start_next = 1;
    else if( sink_valid_i && sink_endofpacket_i )
      fin_next = 1;    
  end
  
// grabbing valid data
always_comb
  begin
    sink_valid_data = '0;
    if( start_next && sink_valid_i )
      sink_valid_data = sink_data_i;
  end

// searching for matches
always_ff @( posedge clk_i )
  begin
    if( srst_i )
      delayed_sink_end <= '0;
    else
      delayed_sink_end <= sink_endofpacket_i;
  end

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      src_channel_o <= '0;
    else
      begin : main_else
        if( &found )
          src_channel_o <= '1;
        else if( delayed_sink_end )
          src_channel_o <= '0;
      end   : main_else
  end

generate
  genvar k;
  for( k = 0; k < REG_DEPTH; k++ )
    begin : searching
      always_comb
        begin
          found[k] = '0;
          if( substring[k] == pattern[k] )
            found[k] = '1;
        end
    end
endgenerate

endmodule
