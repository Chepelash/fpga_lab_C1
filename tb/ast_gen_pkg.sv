package ast_gen_pkg;

import tb_parameters_pkg::*;

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

endpackage
