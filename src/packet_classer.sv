module packet_classer #(
  parameter          AMM_DWIDTH    = 32,
  parameter          AST_DWIDTH    = 64,
  parameter          CHANNEL_WIDTH = 1,
  parameter          REG_DEPTH     = 4,
  parameter          BITS_PER_SYMB = 8
)(
  input              clk_i,
  input              srst_i,
  
  avalon_mm_if.slave amm_if,
  
  avalon_st_if.src   src_if,
  
  avalon_st_if.sink  sink_if 
);

localparam EMPTY_WIDTH = $clog2( AST_DWIDTH / 8 );
localparam PAT_WIDTH   = REG_DEPTH - 1;
localparam PAT_SIZE    = AMM_DWIDTH * PAT_WIDTH;

localparam SEARCH_SIZE = ( AST_DWIDTH*3 - PAT_SIZE ) / BITS_PER_SYMB + 1;

// searching symbols
logic [PAT_SIZE-1:0]    pattern;
logic                   wrken;

// searching area 
logic [AST_DWIDTH*3 - 1:0] substring;
logic [AST_DWIDTH-1:0]     pre_data;
logic [SEARCH_SIZE-1:0]    found;

// ast signals
logic [AST_DWIDTH-1:0]  data_d1;
logic [AST_DWIDTH-1:0]  data_d2;
logic                   val_d1;
logic                   val_d2;
logic                   sop_d1;
logic                   sop_d2;
logic                   eop_d1;
logic                   eop_d2;
logic [EMPTY_WIDTH-1:0] empty_d1;
logic [EMPTY_WIDTH-1:0] empty_d2;


// avalon mm module 
control_register #(
  .REG_WIDTH      ( AMM_DWIDTH ),
  .REG_DEPTH      ( REG_DEPTH  )
) cntr_regs       (
  .clk_i          ( clk_i      ),
  .srst_i         ( srst_i     ),
  
  .amm_slave_if   ( amm_if     ),
  
  .pattern_o      ( pattern    ),
  .wrken_o        ( wrken      )
);


// output data valid conditions
//assign src_if.valid = ( val_d2 & val_d1 & sink_if.valid ) |
//                      ( val_d2 & val_d1 & eop_d1 ) |
//                      ( val_d2 & eop_d2 );
assign src_if.valid = val_d2;


// pipelines
always_ff @( posedge clk_i )
  begin
    if( srst_i )
      begin
        data_d1  <= '0;
        val_d1   <= '0;
        sop_d1   <= '0;
        eop_d1   <= '0;
        empty_d1 <= '0;
      end
    else
      begin
        if( src_if.ready && wrken )
          begin
            data_d1  <= sink_if.data;
            val_d1   <= sink_if.valid;
            sop_d1   <= sink_if.startofpacket;
            eop_d1   <= sink_if.endofpacket;
            empty_d1 <= sink_if.empty;
          end
      end
    
  end
  

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      begin
        data_d2  <= '0;
        val_d2   <= '0;
        sop_d2   <= '0;
        eop_d2   <= '0;
        empty_d2 <= '0;
      end
    else
      begin
        if( src_if.ready && wrken )
          begin
            data_d2  <= data_d1;
            val_d2   <= val_d1;
            sop_d2   <= sop_d1;
            eop_d2   <= eop_d1;
            empty_d2 <= empty_d1;
          end
      end
  end
  

    
// creating search area
assign substring = {data_d2, data_d1, sink_if.data};

// searching for matches

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      src_if.channel <= '0;
    else
      begin 
        if( |found )
          src_if.channel <= '1;
        else if( eop_d2 && src_if.ready )
          src_if.channel <= '0;
      end   
  end

generate
  genvar n;
  for( n = 0; n < SEARCH_SIZE; n++ )
    begin : pat_search
      always_comb
        begin
          found[n] = '0;
          if( substring[PAT_SIZE+n*BITS_PER_SYMB-1-:PAT_SIZE] == pattern )
            found[n] = '1;
        end
    end
endgenerate
    
    
assign sink_if.ready        = src_if.ready;
assign src_if.data          = data_d2;
assign src_if.startofpacket = sop_d2;
assign src_if.endofpacket   = eop_d2;
assign src_if.empty         = empty_d2;

endmodule
