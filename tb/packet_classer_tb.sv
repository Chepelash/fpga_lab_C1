module packet_classer_tb;

parameter int CLK_T          = 60;
parameter int AMM_DWIDTH     = 32; // bits
parameter int AMM_NUM_REGS   = 4;
parameter int AMM_DATA_LEN   = AMM_NUM_REGS-1;
parameter int AMM_AWIDTH     = $clog2(AMM_NUM_REGS) + 1;
parameter int AST_DWIDTH     = 64; // bits
parameter int STR_LEN        = 12; // bytes
parameter int BITS_PER_SYMB  = 8;
parameter int BITS_IN_ASCII  = 7;
parameter int SYMB_IN_AMM    = AMM_DWIDTH / BITS_PER_SYMB;
// somehow ceil == floor, so +1
parameter int DW_MAX_PACKET_LEN = $ceil( 1514 * 8 / AST_DWIDTH ) + 1; // in dwords
parameter int DW_MIN_PACKET_LEN = $ceil(   60 * 8 / AST_DWIDTH ) + 1; //
// in bytes
parameter int MAX_PACKET_LEN    = DW_MAX_PACKET_LEN * AST_DWIDTH / BITS_PER_SYMB;
parameter int MIN_PACKET_LEN    = DW_MIN_PACKET_LEN * AST_DWIDTH / BITS_PER_SYMB;
parameter int EMPTY_SIZE        = $clog2(AST_DWIDTH / BITS_PER_SYMB);

logic clk_i;
logic srst_i;

typedef bit [AMM_DWIDTH-1:0] regtype [AMM_NUM_REGS-1:0];
typedef bit [AMM_DWIDTH-1:0] regdata [AMM_DATA_LEN-1:0];

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

endtask


class AMM_Driver;
  virtual avalon_mm_if amm;
  // from generator
  mailbox gen_mbox;
  // to arbiter
  mailbox arb_mbox;
  regtype reg_map;
  
  
  function new( virtual avalon_mm_if amm, mailbox gen_mbox,
                mailbox arb_mbox );
    this.arb_mbox = arb_mbox;  
    this.gen_mbox = gen_mbox; 
    this.amm      = amm;
    // amm init
    this.amm.address   <= '0;
    this.amm.write     <= '0;
    this.amm.writedata <= '0;
    this.amm.read      <= '0;
  endfunction
  
  task pre_write_callback();
    regdata str_from_gen;
    this.gen_mbox.get( str_from_gen );
    this.reg_map[1+:AMM_DATA_LEN] = str_from_gen;
  endtask
  
  task post_write_callback();
    
  endtask
  
  task write_registers();
    int                     cntr;
    
    pre_write_callback();
    
    this.amm.write <= '1;
    for( int i = 1; i < AMM_NUM_REGS; i++ )
      begin
        this.amm.address   <= i[AMM_AWIDTH-1:0];        
        this.amm.writedata <= this.reg_map[i];
        @( posedge clk_i );
      end
    this.amm.write <= '0;
  endtask
  
  task wrk_enable( bit val );    
    this.reg_map[0]     = val;
    this.amm.write     <= '1;
    this.amm.address   <= '0;
    this.amm.writedata <= val;
    @( posedge clk_i );
    this.amm.write     <= '0;
  endtask
  
  task post_read_callback( input regdata read_reg_map );
    this.arb_mbox.put( read_reg_map );
  endtask
  
  task read_regs();
    regdata read_reg_map;
    
    this.amm.read <= '1;
    for( int i = 1; i < AMM_NUM_REGS; i++ )
      begin
        this.amm.address <= i;
        @( posedge clk_i );
        
        do begin
          @( posedge clk_i );
        end
        while( !amm.readdatavalid );
          
        read_reg_map[i-1] = this.amm.readdata;
      end
    this.amm.read <= '0;
    
    post_read_callback( read_reg_map );
    
  endtask
  
  function regtype get_regs();
    return this.reg_map;
  endfunction
  
endclass


class ASTPGen;
  
  mailbox                 ast_mbox;
  mailbox                 ast_arb_mbox;
  mailbox                 amm_gen;
  
  bit                     is_put_key_phrase;
  int                     packet_len;
  bit [BITS_PER_SYMB-1:0] out_packet[$];
  bit [EMPTY_SIZE-1:0]    empty;
  int                     key_phrase_end_idx;
  
  function new( mailbox ast_mbox, mailbox ast_arb_mbox, mailbox amm_gen );
    this.amm_gen = amm_gen;
    this.ast_mbox = ast_mbox;
    this.ast_arb_mbox = ast_arb_mbox;
  endfunction
  
  function void pro_randomize();
    this.is_put_key_phrase  = $urandom_range(1, 0);    
    this.packet_len         = $urandom_range(MAX_PACKET_LEN, MIN_PACKET_LEN);
    
    for( int i = 0; i < packet_len; i++ )
      this.out_packet.push_back( $urandom_range( BITS_IN_ASCII ) );  
      
    this.empty              = $urandom_range(EMPTY_SIZE-1);
    this.key_phrase_end_idx = $urandom_range(this.packet_len-1-empty, STR_LEN-1);
  endfunction
  
  task insert_key_phrase();
    // TAKE STR FROM MAILBOX
    regdata key_phrase;
    this.amm_gen.get( key_phrase );
    if( this.is_put_key_phrase )
      this.out_packet[this.key_phrase_end_idx-:STR_LEN] = key_phrase;
  endtask
  
  task put_ast_data();
    this.insert_key_phrase();
    this.ast_mbox.put( this.out_packet );
    this.ast_mbox.put( this.empty );
  endtask
  
  task run();
    
    this.pro_randomize();
    this.put_ast_data();
  
  endtask
  
endclass

class AMM_Arbiter;
  mailbox    gen_mbox;
  mailbox    amm_mbox;
  AMM_Driver amm_driver;
  
  function new( mailbox gen_mbox, mailbox amm_mbox,
                AMM_Driver amm_driver);
    this.gen_mbox = gen_mbox;
    this.amm_mbox = amm_mbox;
    this.amm_driver = amm_driver;
  endfunction

  task write_registers();
    this.amm_driver.write_registers();
  endtask
  
  task check_data();
    regdata regs_wrote;
    regdata regs_read;
    this.amm_driver.read_regs();
    this.amm_mbox.get( regs_read );
    
    this.gen_mbox.get( regs_wrote );
    
    if( regs_read != regs_wrote )
      begin
        $display("AMM_Arbiter.check_data - read and wrote reg maps are different!");
        $stop();
      end
    else
      begin
        $display("AMM_Arbiter.check_data - registers has been written successfully");
      end
  endtask
  
  task run();
    repeat( 10 )
      begin
        this.write_registers();
        this.check_data();
      end
  endtask
  
endclass


class AMMGen;
  mailbox                 amm_mbox;
  mailbox                 amm_arb_mbox;
  regdata                 key_phrase;
  
  function new( mailbox amm_mbox, mailbox amm_arb_mbox );
    this.amm_mbox     = amm_mbox;
    this.amm_arb_mbox = amm_arb_mbox;
  endfunction

  function regdata rand_key_phrase();
    regdata t_key_phrase;
    bit [SYMB_IN_AMM-1:0][BITS_PER_SYMB-1:0] pack;
    for( int i = 0; i < AMM_DATA_LEN; i++ )
      begin
        for( int j = 0; j < SYMB_IN_AMM; j++ )
          begin
            pack[j] = $urandom_range(2**BITS_IN_ASCII - 1);            
          end
        t_key_phrase[i] = pack;
      end
    return t_key_phrase;
  endfunction
    
  task put_amm_data();
    this.amm_mbox.put( this.key_phrase );
    this.amm_arb_mbox.put( this.key_phrase );
  endtask
  
  task amm_gen();
    repeat( 10 )
      begin
        this.key_phrase = this.rand_key_phrase();
        this.put_amm_data();
      end
  endtask
  
endclass


AMM_Driver  amm_driver;
AMM_Arbiter amm_arbiter;
AMMGen      amm_gen;


mailbox gen2amm_driver = new;
mailbox amm_dr2arb = new;
mailbox gen2amm_arb = new;
mailbox gen2ast_driver = new;
mailbox gen2ast_arb = new;
//  function new( virtual avalon_mm_if amm, mailbox gen_mbox,
//                mailbox arb_mbox );

initial
  begin

    init();     
    fork
      clk_gen();
    join_none
    apply_rst();
    
    $display("Starting testbench!");
// function new( mailbox amm_mbox, mailbox amm_arb_mbox );
    amm_gen = new( gen2amm_driver, gen2amm_arb ); 
//  function new( virtual avalon_mm_if amm, mailbox gen_mbox,
//                mailbox arb_mbox );
    amm_driver = new( amm_master_if, gen2amm_driver, amm_dr2arb ); 
//function new( mailbox gen_mbox, mailbox amm_mbox,
//              AMM_Driver amm_driver);    
    amm_arbiter = new( gen2amm_arb, amm_dr2arb, amm_driver );
    
    fork 
      amm_gen.amm_gen();
      amm_arbiter.run();
    join
    $display("Everything is OK!");
    $stop();
    
  end


endmodule
