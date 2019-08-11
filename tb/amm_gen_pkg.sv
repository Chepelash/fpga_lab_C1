package amm_gen_pkg;

import tb_parameters_pkg::*;

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
  
  function regdata put_hello_world();
    regdata t_key_phrase;
    bit [SYMB_IN_AMM-1:0][BITS_PER_SYMB-1:0] pack;
    string hello_world = "hello,world!";
    int cntr;
    for( int i = 0; i < AMM_DATA_LEN; i++ )
      begin
        for( int j = 0; j < SYMB_IN_AMM; j++ )
          begin
            pack[j] = hello_world[cntr++];            
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
        this.ast_gen_mbox.put( this.key_phrase );
      end
  endtask
  
  task amm_gen( int num = 1 );
    repeat( num )
      begin
        this.key_phrase = this.rand_key_phrase();
//        this.key_phrase = this.put_hello_world();
        this.put_amm_data();
      end
  endtask
  
endclass

endpackage
