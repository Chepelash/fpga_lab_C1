package amm_driver_pkg;

import tb_parameters_pkg::*;

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
        @( posedge amm.clk_i );
      end
    this.amm.write <= '0;
  endtask
  
  task wrk_enable( bit val );    
    this.reg_map[0]     = val;
    this.amm.write     <= '1;
    this.amm.address   <= '0;
    this.amm.writedata <= val;
    @( posedge amm.clk_i );
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
        @( posedge amm.clk_i );


        while( !amm.readdatavalid ) 
          @( posedge amm.clk_i );
          
        read_reg_map[i-1] = this.amm.readdata;
      end
    this.amm.read <= '0;
    
    post_read_callback( read_reg_map );
    
  endtask
  
  function regtype get_regs();
    return this.reg_map;
  endfunction
  
endclass


endpackage
