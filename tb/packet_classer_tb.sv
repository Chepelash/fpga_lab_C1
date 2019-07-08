module packet_classer_tb;

parameter int CLK_T        = 60;
parameter int AMM_DWIDTH   = 32; 
parameter int AMM_NUM_REGS = 4;
parameter int AMM_AWIDTH   = $clog2(AMM_NUM_REGS) + 1;
parameter int AST_DWIDTH   = 64;

logic clk_i;
logic srst_i;

class AMM_Driver;
  bit [7:0] key_phrase [11:0];
  bit is_enable;
  
  task init();
    amm_master_if.address   <= '0;
    amm_master_if.write     <= '0;
    amm_master_if.writedata <= '0;
    amm_master_if.read      <= '0;
  endtask
  
  task write_registers( bit [7:0] s [11:0] );
    bit [0:AMM_DWIDTH-1] packet;
    int cntr;
    
    this.key_phrase = s;
    amm_master_if.write <= '1;
    for( int i = 1; i < AMM_NUM_REGS; i++ )
      begin
        amm_master_if.address <= i[AMM_AWIDTH-1:0];
        // forming the key phrase
        for( int j = 0; j < AMM_DWIDTH; j = j + 8 )
          begin
            packet[j+:8] = s[cntr++];            
          end
        amm_master_if.writedata <= packet;
        @( posedge clk_i );
      end
    amm_master_if.write <= '0;
  endtask
  
  task wrk_enable( bit val );    
    // this is not possible. bit is only 0 or 1!!!!!!!!!!
    if( ( val > 1 ) || ( val < 0 ) )
      begin
        $display("AMM_Driver.wrk_enable - wrong value!");
        disable wrk_enable;
      end
    this.is_enable           = val;
    amm_master_if.write     <= '1;
    amm_master_if.address   <= '0;
    amm_master_if.writedata <= val;
    @( posedge clk_i );
    amm_master_if.write     <= '0;
  endtask
  
  function bit is_working();  
    return this.is_enable;
  endfunction
  
  // need to define a type to set function return type. I'm too lazy
//  function get_key_phrase();
//    return this.key_phrase;
//  endfunction
  
endclass

class RandPGen;  
  bit is_put_key_phrase;
  int packet_len;
  bit [7:0] out_packet [1513:0];  
  int key_phrase_end_idx;
  bit [$clog2(AST_DWIDTH / 8) - 1:0] empty;
  
  function void pro_randomize();
    this.is_put_key_phrase  = $urandom_range(1, 0);
    this.packet_len         = $urandom_range(1514, 60);
    for( int rp = 0; rp < 1514; rp++ )
      this.out_packet[rp]   = $urandom_range(127);
      
    this.empty              = $urandom_range($clog2(AST_DWIDTH / 8)-1);
    this.key_phrase_end_idx = $urandom_range(this.packet_len-1-empty, 11);
    
  endfunction
  
endclass

class AST_src_Driver;
  bit is_src;
  bit [7:0] key_phrase [11:0];
  
  function void set_key_phrase( bit [7:0] s [11:0] );
    this.key_phrase = s;
  endfunction
  
  task init_st();

    ast_src_if.data          <= '0;
    ast_src_if.valid         <= '0;
    ast_src_if.startofpacket <= '0;
    ast_src_if.endofpacket   <= '0;
    ast_src_if.empty         <= '0;
    ast_src_if.channel       <= '0;

  endtask
  
  task send_packet( int num_of_transactions = 1 );
    bit        done;
    RandPGen   rgen;
    int        cntr;
    bit [7:0]  out_packet [1513:0];
    bit [0:63] packet;        
     
    for( int nn = 0; nn < num_of_transactions; nn++ )
      begin
        rgen = new();
        rgen.pro_randomize();
        
        $display("rgen.key_phrase_end_idx = %d", rgen.key_phrase_end_idx);
        cntr = 0;
        done = 0;
        // inserting reversed key_phrase in out packet
        out_packet = rgen.out_packet;
        if( rgen.is_put_key_phrase )
          begin
            $display("%d", rgen.key_phrase_end_idx);
            out_packet[rgen.key_phrase_end_idx-:12] = this.key_phrase;
          end      
        $display( "%p", out_packet );
        $display( "%p", this.key_phrase );
        while( !done )
          begin
            ast_src_if.valid <= '1;
            
            if( cntr == 0 )
              begin
                ast_src_if.startofpacket <= '1;
                ast_src_if.endofpacket <= '0;
              end
            // well, becouse cntr is going to be multiple of 8
            else if( cntr >= rgen.key_phrase_end_idx - 1 )
              begin
                done = 1;
                ast_src_if.endofpacket <= '1;
                ast_src_if.empty <= rgen.empty;                
              end
            else
              begin
                ast_src_if.startofpacket <= '0;
              end              
              
            for( int tt = 0; tt < 64; tt = tt + 8 )
              begin
                packet[tt+:8] = out_packet[cntr++];
              end
            ast_src_if.data <= packet;
            
            while( ast_sink_if.ready != '1 )
              begin
                @( posedge clk_i );
              end
            @( posedge clk_i );
            
          end
      end
    ast_src_if.valid <= '0;
    ast_src_if.endofpacket <= '0;
    ast_src_if.empty <= '0;
    
  endtask
  
endclass


class ASCIIRandomizer;
  rand bit [7:0] str [11:0]; 
 
  function void pro_randomize();
    for( int rs = 0; rs < 12; rs++ )
      this.str[rs] = $urandom_range(127);
  endfunction
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


AMM_Driver amm_driver;
AST_src_Driver ast_src;
//AST_Driver ast_sink;
ASCIIRandomizer str_gen;



task automatic init;
  
  clk_i  <= '1;
  srst_i <= '0;
  amm_driver.init();
  ast_sink_if.ready <= '0;
//  ast_sink.init_st();
  ast_src.init_st();
  
endtask


string ss;
initial
  begin
    init(); 
    str_gen = new();
    str_gen.pro_randomize();
    
    amm_driver = new();
    ast_src = new();
//    ast_sink = new(0);
    
    fork
      clk_gen();
    join_none
    apply_rst();
    
    
    $display("Starting testbench!");
    
    amm_driver.write_registers( str_gen.str );
    ast_src.set_key_phrase( str_gen.str );   
    @(posedge clk_i );
    
    amm_driver.wrk_enable( 1 );
    @(posedge clk_i );
    
    ast_sink_if.ready <= '1;
    @( posedge clk_i );
    ast_src.send_packet(2);
    
    for( int nd = 0; nd < 100; nd++ )
      @( posedge clk_i );
    
    $display("Everything is OK!");
    $stop();
    
  end


endmodule
