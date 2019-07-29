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
parameter int SYMB_IN_AST    = AST_DWIDTH / BITS_PER_SYMB;
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
    int cntr;
    
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


        while( !amm.readdatavalid ) 
          @( posedge clk_i );
          
        read_reg_map[i-1] = this.amm.readdata;
      end
    this.amm.read <= '0;
    
    post_read_callback( read_reg_map );
    
  endtask
  
  function regtype get_regs();
    return this.reg_map;
  endfunction
  
endclass


class AMM_Arbiter;
  mailbox    gen_mbox;
  mailbox    amm_mbox;
  AMM_Driver amm_driver;
  
  function new( mailbox gen_mbox, mailbox amm_mbox,
                AMM_Driver amm_driver);
    this.gen_mbox   = gen_mbox;
    this.amm_mbox   = amm_mbox;
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
  
  task run( int num = 1 );
    repeat( num )
      begin
        this.write_registers();
        this.check_data();
      end
  endtask
  
endclass


class AMMGen;
  mailbox                 amm_mbox;
  mailbox                 amm_arb_mbox;
  mailbox                 ast_gen_mbox;
  
  regdata                 key_phrase;
  
  function new( mailbox amm_mbox, mailbox amm_arb_mbox,
                mailbox ast_gen_mbox );
    this.amm_mbox     = amm_mbox;
    this.amm_arb_mbox = amm_arb_mbox;
    this.ast_gen_mbox = ast_gen_mbox;
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
  
  task to_ast_gen(int num = 1);
    repeat( num )
      begin
        bit [AMM_DWIDTH*AMM_DATA_LEN-1:0] t_reg;

        for( int i = 0; i < AMM_DATA_LEN; i++ )
          begin
            for( int j = 0; j < SYMB_IN_AMM; j++ )
              t_reg[i*AMM_DWIDTH+BITS_PER_SYMB*j+:BITS_PER_SYMB] = this.key_phrase[AMM_DATA_LEN-1-i][BITS_PER_SYMB*j+:BITS_PER_SYMB];
          end

        this.ast_gen_mbox.put( t_reg );
      end
  endtask
  
  task amm_gen( int num = 1 );
    repeat( num )
      begin
        this.key_phrase = this.rand_key_phrase();
        this.put_amm_data();
      end
  endtask
  
endclass



class ASTPGen;
  
  mailbox              ast_mbox;
  mailbox              ast_arb_mbox;
  mailbox              amm_gen;
  
  bit                  is_put_key_phrase;
  int                  packet_len;
  int                  packet_len_dw;
  bit [AST_DWIDTH-1:0] out_packet[$];
  bit [EMPTY_SIZE-1:0] empty;
  int                  key_phrase_end_idx;
  int                  key_phrase_end_byte;
  int                  key_phrase_end_dw;
  
  function new( mailbox ast_mbox, mailbox ast_arb_mbox, mailbox amm_gen );
    this.amm_gen = amm_gen;
    this.ast_mbox = ast_mbox;
    this.ast_arb_mbox = ast_arb_mbox;
  endfunction
  
  function void pro_randomize();
    bit [BITS_PER_SYMB-1:0] [SYMB_IN_AST-1:0] packet;
    
    this.out_packet = {};
    
    this.is_put_key_phrase  = $urandom_range(1, 0);    
    //$ceil( 1514 * 8 / AST_DWIDTH ) + 1;
    this.packet_len_dw      = $urandom_range(DW_MAX_PACKET_LEN, DW_MIN_PACKET_LEN);
    this.packet_len         = packet_len_dw * AST_DWIDTH / BITS_PER_SYMB;
    
    for( int i = 0; i < this.packet_len; i++ )
      begin
        packet[i % 8] = $urandom_range( 2**BITS_IN_ASCII-1 );
        if( ( ( i + 1 ) % 8 ) == 0 )
          this.out_packet.push_back( packet );
      end

    this.empty               = $urandom_range(EMPTY_SIZE-1);
    this.key_phrase_end_byte = $urandom_range(SYMB_IN_AST, 1);
    this.key_phrase_end_dw   = $urandom_range(packet_len_dw-1, 1);
    if( this.key_phrase_end_dw == 1 )
      begin
      //                                                   index
        if( ( SYMB_IN_AST + this.key_phrase_end_byte ) < ( SYMB_IN_AMM * AMM_DATA_LEN - 1 ) )
          begin
            this.key_phrase_end_byte += (SYMB_IN_AMM * AMM_DATA_LEN - 1 - 
                                         SYMB_IN_AST - this.key_phrase_end_byte);
          end
      end
  endfunction
  
  task insert_key_phrase();
    // TAKE STR FROM MAILBOX
    bit [AMM_DWIDTH*AMM_DATA_LEN-1:0] t_reg;
    int dw_ind;
    int byte_ind;
    
    this.amm_gen.get( t_reg );

    if( this.is_put_key_phrase )
      begin
        dw_ind = this.key_phrase_end_dw;
        byte_ind = this.key_phrase_end_byte;

        for( int i = 0; i < STR_LEN; i++ )
          begin
            this.out_packet[dw_ind][BITS_PER_SYMB*byte_ind-1-:BITS_PER_SYMB] = t_reg[BITS_PER_SYMB*STR_LEN-1-BITS_PER_SYMB*i-:BITS_PER_SYMB];
            if( byte_ind == 1 )
              begin
                byte_ind = SYMB_IN_AST;
                dw_ind += 1;
              end
            else
              byte_ind -= 1;
            
          end

      end
  endtask
  
  task put_ast_data();
    this.insert_key_phrase();
    this.ast_mbox.put( this.out_packet );
    this.ast_mbox.put( this.empty );
    
    this.ast_arb_mbox.put( this.out_packet );
    this.ast_arb_mbox.put( this.empty );
    this.ast_arb_mbox.put( this.is_put_key_phrase );
  endtask
  
  task run( int num = 1 );
    repeat( num )
      begin
        this.pro_randomize();
        this.put_ast_data();
      end
  endtask
  
endclass


class AstSrcDriver;
  
  mailbox gen_mbox;  
  virtual avalon_st_if asrc;
  
  function new( mailbox gen_mbox, virtual avalon_st_if a_src );
    this.asrc     = a_src;
    this.gen_mbox = gen_mbox;
    
    this.asrc.channel       <= '0; 
    this.asrc.data          <= '0; 
    this.asrc.valid         <= '0; 
    this.asrc.startofpacket <= '0; 
    this.asrc.endofpacket   <= '0; 
    this.asrc.empty         <= '0;
  endfunction
  
  task send_data();
    bit [AST_DWIDTH-1:0] out_packet[$];
    bit [EMPTY_SIZE-1:0] empty;
    
    this.gen_mbox.get( out_packet );
    this.gen_mbox.get( empty );
    
    this.asrc.valid <= '1;
    for( int i = 0; i < out_packet.size(); i++ )
      begin
        
        this.asrc.data <= out_packet[i];
        
        if( i == 0 )
          begin
            this.asrc.empty         <= '0;
            this.asrc.endofpacket   <= '0;
            this.asrc.startofpacket <= '1;
          end
        else if( i == ( out_packet.size() - 1 ) )
          begin
            this.asrc.empty <= empty;
            this.asrc.endofpacket <= '1;            
          end
        else
          begin
            this.asrc.startofpacket <= '0;
            this.asrc.endofpacket   <= '0;
          end
        
        if( !this.asrc.ready )
          begin
            while( !this.asrc.ready )
              @( posedge clk_i );
          end
        else
          @( posedge clk_i );
      end
    
    this.asrc.valid       <= '0;
    this.asrc.endofpacket <= '0;
  endtask
  
endclass


class AstSinkDriver;
  mailbox to_arb;
  virtual avalon_st_if asink;
  
  function new( mailbox to_arb, virtual avalon_st_if ast_sink_if );
    this.to_arb = to_arb;
    this.asink  = ast_sink_if;
    
    this.asink.ready <= '1;
  endfunction
  
  task read_data();
    bit [AST_DWIDTH-1:0] out_packet[$];
    bit [EMPTY_SIZE-1:0] empty;
    bit                  channel;
    int                  cntr;
    bit                  done;
    
    cntr = 0;
    done = 0;
    while( !this.asink.valid )
      @( posedge clk_i );
      
    while( !done )
      begin : while_read
        if( this.asink.valid )
          begin
            if( ( cntr == 0 ) && !this.asink.startofpacket )
              begin
                $display("AstSinkDriver.read_data - no startofpacket signal");
                $stop();
              end
            if( this.asink.endofpacket )
              begin
                done    = 1;
                empty   = this.asink.empty;
                channel = this.asink.channel;
              end
            cntr += 1;
            out_packet.push_back( this.asink.data );
            @( posedge clk_i );
          end
        else
          begin : not_valid
            @( posedge clk_i );
          end   : not_valid
      end   : while_read
    
    
    this.to_arb.put( out_packet );
    this.to_arb.put( empty );
    this.to_arb.put( channel );
    
  endtask
  
endclass


class AstArbiter;
  AstSrcDriver  ast_src;
  AstSinkDriver ast_sink;
  mailbox       from_gen;
  mailbox       from_sink;
  
  function new( AstSrcDriver ast_src, 
                AstSinkDriver ast_sink,
                mailbox from_gen, mailbox from_sink );
    this.ast_sink = ast_sink;
    this.ast_src = ast_src;
    this.from_gen = from_gen;
    this.from_sink = from_sink;
    
  endfunction
  
  task check_data();
    bit [AST_DWIDTH-1:0] out_packet_gen[$];
    bit [EMPTY_SIZE-1:0] empty_gen;
    bit                  channel_gen;
    
    bit [AST_DWIDTH-1:0] out_packet_sink[$];
    bit [EMPTY_SIZE-1:0] empty_sink;
    bit                  channel_sink;
    
    this.from_gen.get( out_packet_gen );
    this.from_gen.get( empty_gen );
    this.from_gen.get( channel_gen );

    fork
      this.ast_src.send_data();
      this.ast_sink.read_data();
    join

    this.from_sink.get( out_packet_sink );
    this.from_sink.get( empty_sink );
    this.from_sink.get( channel_sink );
    
    if( out_packet_sink != out_packet_gen )
      begin
        $display("AstArbiter.check_data - packet mismatch");
        $stop();
      end
    if( empty_sink != empty_gen )
      begin
        $display("AstArbiter.check_data - empty mismatch");
        $stop();
      end
    if( channel_sink != channel_gen )
      begin
        $display("AstArbiter.check_data - channel mismatch");
        $display("Channel read = %d; channel generated = %d", channel_sink, channel_gen);
        $stop();
      end
    $display("AST_Arbiter.chack_data - read successfully");
  endtask
  
  task run( int num = 1 );
    repeat( num )
      this.check_data();
  endtask
  
endclass


task automatic ast_test( AMMGen amm_gen, ASTPGen gen, AstArbiter ast, AMM_Driver amm_driver, int num = 1 );
  
  amm_driver.wrk_enable( 1 );
  amm_gen.to_ast_gen( num );
  gen.run( num );
  ast.run( num );
endtask

task automatic amm_test( AMMGen amm_gen, AMM_Arbiter amm_arbiter, int num = 1 );
  fork 
    amm_gen.amm_gen( num );
    amm_arbiter.run( num );
  join
endtask

AMM_Driver  amm_driver;
AMM_Arbiter amm_arbiter;
AMMGen      amm_gen;

ASTPGen ast_gen;
AstSrcDriver ast_src;
AstSinkDriver ast_sink;
AstArbiter ast_arb;

mailbox gen2amm_driver = new;
mailbox amm_dr2arb = new;
mailbox gen2amm_arb = new;
mailbox gen2ast_driver = new;
mailbox gen2ast_arb = new;
mailbox amm_gen_mbox = new;
mailbox asink2arb = new;


initial
  begin

    init();     
    fork
      clk_gen();
    join_none
    apply_rst();
    
    $display("Starting testbench!");

    ast_gen  = new( gen2ast_driver, gen2ast_arb, amm_gen_mbox );
    ast_src  = new( gen2ast_driver, ast_src_if );
    ast_sink = new( asink2arb, ast_sink_if );
    ast_arb  = new( ast_src, ast_sink, gen2ast_arb, asink2arb );

    amm_gen     = new( gen2amm_driver, gen2amm_arb, amm_gen_mbox );
    amm_driver  = new( amm_master_if, gen2amm_driver, amm_dr2arb );
    amm_arbiter = new( gen2amm_arb, amm_dr2arb, amm_driver );
    
    amm_test( amm_gen, amm_arbiter, 100 );
    
    ast_test( amm_gen, ast_gen, ast_arb, amm_driver, 100 );


    $display("It's fine");
    $stop();
    
  end


endmodule
