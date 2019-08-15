package ast_sink_driver_pkg;

import tb_parameters_pkg::*;

class AstSinkDriver;
  mailbox to_arb;
  virtual avalon_st_if asink;
  
  function new( mailbox to_arb, virtual avalon_st_if ast_sink_if );
    this.to_arb = to_arb;
    this.asink  = ast_sink_if;
    
//    this.asink.ready <= '1;
    fork
      this.random_ready();
    join_none
  endfunction
  
  task random_ready();
    int ticks;
    bit not_ready;
    forever
      begin
        not_ready = $urandom_range(1);
        ticks = $urandom_range(100, 1);
        if( not_ready )
          begin
            this.asink.ready <= '0;
            do begin
              @( posedge this.asink.clk_i );
            end
              while( --ticks );
          end
        else
          begin
            this.asink.ready <= '1;
            do begin
              @( posedge this.asink.clk_i );
            end
              while( --ticks );
          end
      end
  endtask
  
  task read_data();
    bit [AST_DWIDTH-1:0] out_packet[$];
    bit [EMPTY_SIZE-1:0] empty;
    bit                  channel;
    int                  cntr;
    bit                  done;
    
    cntr = 0;
    done = 0;

    do begin
        @( posedge this.asink.clk_i );  
    end
      while( !this.asink.valid );
      
    while( !done )
      begin : while_read
        if( this.asink.valid && this.asink.ready )
          begin
            if( ( cntr == 0 ) && !this.asink.startofpacket )
              begin
                $display("AstSinkDriver.read_data - no startofpacket signal");
                $stop();
              end
            cntr += 1;
            out_packet.push_back( this.asink.data );
            if( this.asink.endofpacket )
              begin
                done    = 1;
                empty   = this.asink.empty;
                channel = this.asink.channel;
              end
            else
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
