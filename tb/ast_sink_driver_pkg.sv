package ast_sink_driver_pkg;

import tb_parameters_pkg::*;

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
      @( posedge this.asink.clk_i );
      
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
            @( posedge this.asink.clk_i );
          end
        else
          begin : not_valid
            @( posedge this.asink.clk_i );
          end   : not_valid
      end   : while_read
    
    
    this.to_arb.put( out_packet );
    this.to_arb.put( empty );
    this.to_arb.put( channel );
    
  endtask
  
endclass

endpackage
