package ast_src_driver_pkg;

import tb_parameters_pkg::*;

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
        
//        if( !this.asrc.ready )
//          begin
//            while( !this.asrc.ready )
//              @( posedge this.asrc.clk_i );
//          end
//        else
//          @( posedge this.asrc.clk_i );
        do begin
          @( posedge this.asrc.clk_i );
        end
          while( !this.asrc.ready );
      end
    
    this.asrc.valid       <= '0;
    this.asrc.endofpacket <= '0;
  endtask
  
endclass

endpackage
