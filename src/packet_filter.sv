module packet_filter #(  
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
) pr_pc_if    (
  .clk_i      ( clk_i      )
);




packet_classer  #(
  .AMM_DWIDTH    ( AMM_DWIDTH    ),
  .AST_DWIDTH    ( AST_DWIDTH    ),
  .CHANNEL_WIDTH ( CHANNEL_WIDTH ),
  .REG_DEPTH     ( REG_DEPTH     ),
  .BITS_PER_SYMB ( BITS_PER_SYMB )
) pclasser       (
  .clk_i         ( clk_i         ),
  .srst_i        ( srst_i        ),
  
  .amm_if        ( amm_if        ),
  
  .src_if        ( pr_pc_if      ),
  
  .sink_if       ( sink_if       )
);

packet_resolver #(
  .AST_DWIDTH    ( AST_DWIDTH    ),
  .CHANNEL_WIDTH ( CHANNEL_WIDTH )
) presolver      (
  .clk_i         ( clk_i         ),
  .srst_i        ( srst_i        ),
  
  .src_if        ( src_if        ),
  
  .sink_if       ( pr_pc_if    )
);



endmodule
