module packet_classer_tb;

parameter int CLK_T        = 60;
parameter int AMM_DWIDTH   = 32; 
parameter int AMM_NUM_REGS = 4;
parameter int AMM_AWIDTH   = $clog2(AMM_NUM_REGS) + 1;
parameter int AST_DWIDTH   = 64;

logic clk_i;
logic srst_i;

class AMM_Driver;
  string key_phrase;
  bit is_enable;
  
  task init();
    amm_master_if.address   <= '0;
    amm_master_if.write     <= '0;
    amm_master_if.writedata <= '0;
    amm_master_if.read      <= '0;
  endtask
  
  task write_registers( string s );
    bit [AMM_DWIDTH-1:0] packet;
    int cntr;
    if( s.len() != 12 )
      begin
        $display("AMM_Driver.write_registers - string must be 12 chars long!");
        disable write_registers;
      end
    this.key_phrase = s;
    amm_master_if.write <= '1;
    for( int i = 1; i < AMM_NUM_REGS; i++ )
      begin
        amm_master_if.address <= i[AMM_AWIDTH-1:0];
        // forming the key phrase
        for( int j = 0; j < AMM_DWIDTH; j = j + 8 )
          begin
            packet[j+:7] = s.getc( cntr++ )[7:0];            
          end
        amm_master_if.writedata <= packet;
        @( posedge clk_i );
      end
    amm_master_if.write <= '0;
  endtask
  
  task wrk_enable( bit val );    
    if( ( val > 1 ) || ( val < 0 ) )
      begin
        $display("AMM_Driver.wrk_enable - wrong value!");
        disable wrk_enable;
      end
    this.is_enable = val;
    amm_master_if.write <= '1;
    amm_master_if.address <= '0;
    amm_master_if.writedata <= val;
    @( posedge clk_i );
    amm_master_if.write <= '0;
  endtask
  
  function bit is_working();  
    return this.is_enable;
  endfunction
  
  function string get_key_phrase();
    return this.key_phrase;
  endfunction
endclass

class AST_Driver;
  bit is_src;
  
  function new( bit mode );
    this.is_src = mode;
  endfunction
  
  task init_st();
    if( this.is_src )
      begin
      // src
        ast_src_if.data          <= '0;
        ast_src_if.valid         <= '0;
        ast_src_if.startofpacket <= '0;
        ast_src_if.endofpacket   <= '0;
        ast_src_if.empty         <= '0;
        ast_src_if.channel       <= '0;
      end
    else    
      begin
      // sink
        ast_sink_if.ready <= '0;
      end
  endtask
  
  task send_packet( int num_of_transactions = 1 );
    if( !this.is_src )
      begin
        $display("AST_Driver.send_packet - you are a sink!");
        disable send_packet;
      end
    
  endtask
  
endclass

avalon_mm_if   #(
  .DWIDTH       ( AMM_DWIDTH   ),
  .NUM_REGS     ( AMM_NUM_REGS )
) amm_master_if ();

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

packet_classer #(
  .AMM_DWIDTH   ( AMM_DWIDTH    ),
  .AST_DWIDTH   ( AST_DWIDTH    ),
  .REG_DEPTH    ( AMM_NUM_REGS  )
) DUT           (
  .clk_i        ( clk_i         ),
  .srst_i       ( srst_i        ),
  
  .amm_slave_if ( amm_master_if ),
  
  .ast_src_if   ( ast_sink_if   ),
  
  .ast_sink_if  ( ast_src_if    )
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
  amm_driver.init();
  
endtask

AMM_Driver amm_driver;

string ss;
initial
  begin
    init(); 
    amm_driver = new();
    
    fork
      clk_gen();
    join_none
    apply_rst();
    
    
    $display("Starting testbench!");
    
    amm_driver.write_registers( "abcdefghijkl" );
    @(posedge clk_i );
    
    amm_driver.wrk_enable( 1 );
    @(posedge clk_i );
    
    ss = amm_driver.get_key_phrase();
    
    $display("%s",ss);
    
    $display("Everything is OK!");
    $stop();
    
  end


endmodule
