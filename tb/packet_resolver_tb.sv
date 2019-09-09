module packet_resolver_tb;


import tb_parameters_pkg::*;

import ast_src_driver_pkg::*;
import ast_sink_driver_pkg::*;
import ast_gen_pkg::*;
import ast_arbiter_pkg::*;

logic clk_i;
logic srst_i;



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


packet_resolver #(
  .AST_DWIDTH    ( AST_DWIDTH    ),
  .CHANNEL_WIDTH ( 1             )
) DUT            (
  .clk_i         ( clk_i         ),
  .srst_i        ( srst_i        ),
  
  .src_if        ( ast_sink_if   ),
  
  .sink_if       ( ast_src_if    )
);



task automatic init;
  
  clk_i   <= '1;
  srst_i  <= '0;
    
endtask

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

ASTPGen       ast_gen;
AstSrcDriver  ast_src;
AstSinkDriver ast_snk;
AstArbiter    ast_arb;

mailbox gen2src = new;
mailbox gen2arb = new;
mailbox snk2arb = new;

task automatic main_test( ASTPGen gen, AstArbiter arb, int num = 1 );
  gen.run( num );
  arb.run( num, 1 );
endtask

initial
  begin
    init(); 
    
    fork
      clk_gen();
    join_none
    apply_rst();
    $display("Starting testbench!");

    ast_gen = new( gen2src, gen2arb, 1 );
    ast_src = new( gen2src, ast_src_if );
    ast_snk = new( snk2arb, ast_sink_if );
    ast_arb = new( ast_src, ast_snk, gen2arb, snk2arb );
    
    main_test( ast_gen, ast_arb, 10 );
    
    $display("Everything is OK!");
    $stop();
    
  end


endmodule
