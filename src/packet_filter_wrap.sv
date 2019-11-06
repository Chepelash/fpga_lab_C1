module packet_filter_wrap #(  
  parameter AMM_DWIDTH    = 32,
  parameter AST_DWIDTH    = 64,
  parameter REG_DEPTH     = 4,
  parameter BITS_PER_SYMB = 8,
  parameter CHANNEL_WIDTH = 1
)(
  input              clk_i,
  input              srst_i,
  
  avalon_mm_if.slave amm_if,
  
  avalon_st_if.src   src_if,
  
  avalon_st_if.sink  sink_if
);

avalon_st_if #(
  .DWIDTH     ( AST_DWIDTH )
) inp_if      (
  .clk_i      ( clk_i      )
);

avalon_st_if #(
  .DWIDTH     ( AST_DWIDTH )
) out_if      (
  .clk_i      ( clk_i      )
);

avalon_mm_if #(
  .DWIDTH     ( AMM_DWIDTH ),
  .NUM_REGS   ( REG_DEPTH  )
) amm_d_if    (
  .clk_i      ( clk_i      )
);



packet_filter   #(
  .AMM_DWIDTH    ( AMM_DWIDTH    ),
  .AST_DWIDTH    ( AST_DWIDTH    ),
  .REG_DEPTH     ( REG_DEPTH     ), 
  .BITS_PER_SYMB ( BITS_PER_SYMB ),
  .CHANNEL_WIDTH ( CHANNEL_WIDTH )
) pfilter        (
  .clk_i         ( clk_i         ),
  .srst_i        ( srst_i        ),
  
  .amm_if        ( amm_d_if      ),
  
  .src_if        ( out_if        ),
  
  .sink_if       ( inp_if        )
);


always_ff @( posedge clk_i )
  begin
    sink_if.ready        <= inp_if.ready;
    inp_if.data          <= sink_if.data;
    inp_if.valid         <= sink_if.valid;
    inp_if.startofpacket <= sink_if.startofpacket;
    inp_if.endofpacket   <= sink_if.endofpacket;
    inp_if.empty         <= sink_if.empty;
    inp_if.channel       <= sink_if.channel;
  end
  
always_ff @( posedge clk_i )
  begin
    out_if.ready         <= src_if.ready;
    src_if.data          <= out_if.data;
    src_if.valid         <= out_if.valid;
    src_if.startofpacket <= out_if.startofpacket;
    src_if.endofpacket   <= out_if.endofpacket;
    src_if.empty         <= out_if.empty;
    src_if.channel       <= out_if.channel;
  end

always_ff @( posedge clk_i )
  begin
    amm_d_if.address       <= amm_if.address;
    amm_d_if.write         <= amm_if.write;
    amm_d_if.writedata     <= amm_if.writedata;
    amm_d_if.read          <= amm_if.read;
  
    amm_if.waitrequest     <= amm_d_if.waitrequest;    
    amm_if.readdata        <= amm_d_if.readdata;
    amm_if.readdatavalid   <= amm_d_if.readdatavalid;
  end  

endmodule
