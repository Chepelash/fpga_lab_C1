module packet_filter_tb;

import tb_parameters_pkg::*;
import amm_driver_pkg::*;
import amm_gen_pkg::*;
import amm_arbiter_pkg::*;

import ast_src_driver_pkg::*;
import ast_sink_driver_pkg::*;
import ast_gen_pkg::*;
import ast_arbiter_pkg::*;

logic clk_i;
logic srst_i;


avalon_mm_if   #(
  .DWIDTH       ( AMM_DWIDTH   ),
  .NUM_REGS     ( AMM_NUM_REGS )
) amm_master_if (
  .clk_i        ( clk_i        )
);


avalon_st_if #(
  .DWIDTH     ( AST_DWIDTH )
) ast_sink_if (
  .clk_i      ( clk_i      )
);

avalon_st_if #(
  .DWIDTH     ( AST_DWIDTH )
) ast_src_if  (
  .clk_i      ( clk_i      )
);


packet_filter   #(
  .AMM_DWIDTH    ( AMM_DWIDTH    ),
  .AST_DWIDTH    ( AST_DWIDTH    ),
  .REG_DEPTH     ( REG_DEPTH     ), 
  .BITS_PER_SYMB ( BITS_PER_SYMB ),
  .CHANNEL_WIDTH ( CHANNEL_WIDTH )
) DUT            (
  .clk_i         ( clk_i         ),
  .srst_i        ( srst_i        ),
  
  .amm_if        ( amm_master_if ),
  
  .src_if        ( ast_src_if    ),
  
  .sink_if       ( ast_sink_if   )
);




task automatic clk_gen;
  
  forever
    begin
      # ( CLK_T / 2 );
      clk_i <= ~clk_i;
    end
  
endtask

task automatic apply_rst;
  
  srst_i <= 1'b1;
  @( posedge clk_i );
  srst_i <= 1'b0;
  @( posedge clk_i );

endtask

task automatic init;
  
  clk_i  <= '1;
  srst_i <= '0;

endtask


task automatic amm_test( AMMGen amm_gen, AMM_Arbiter amm_arbiter, int num = 1 );
  fork 
    amm_gen.amm_gen( num );
    amm_arbiter.run( num );
  join
endtask


task automatic ast_test( AMMGen amm_gen, ASTPGen gen, AstArbiter ast, AMM_Driver amm_driver, int num = 1 );
  
  amm_driver.wrk_enable( 1 );
  amm_gen.to_ast_gen( num, amm_gen_mbox );
  gen.run( num, amm_gen_mbox );
  ast.run( num );
endtask

AMM_Driver  amm_driver;
AMM_Arbiter amm_arbiter;
AMMGen      amm_gen;

ASTPGen       ast_gen;
AstSrcDriver  ast_src;
AstSinkDriver ast_sink;
AstArbiter    ast_arb;

mailbox gen2amm_driver = new;
mailbox amm_dr2arb     = new;
mailbox gen2amm_arb    = new;
mailbox gen2ast_driver = new;
mailbox gen2ast_arb    = new;
mailbox amm_gen_mbox   = new;
mailbox asink2arb      = new;


initial
  begin

    init();     
    fork
      clk_gen();
    join_none
    apply_rst();
    
    $display("Starting testbench!");
    
    ast_gen  = new( gen2ast_driver, gen2ast_arb );
    ast_src  = new( gen2ast_driver, ast_src_if );
    ast_sink = new( asink2arb, ast_sink_if, 1 ); // 0 for sink_if.ready = 1
                                                 // 1 for random 
    ast_arb  = new( ast_src, ast_sink, gen2ast_arb, asink2arb );

    amm_gen     = new( gen2amm_driver, gen2amm_arb );
    amm_driver  = new( amm_master_if, gen2amm_driver, amm_dr2arb );
    amm_arbiter = new( gen2amm_arb, amm_dr2arb, amm_driver );
    
    amm_test( amm_gen, amm_arbiter, 100 );
    
    ast_test( amm_gen, ast_gen, ast_arb, amm_driver, 100 );
    
    $display("It's fine");
    $stop();
    
  end


endmodule
