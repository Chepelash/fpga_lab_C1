package ast_arbiter_pkg;

import tb_parameters_pkg::*;
import ast_src_driver_pkg::*;
import ast_sink_driver_pkg::*;

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
  
  task automatic compare_data( int num, bit only_ch );
    
    int cntr;
    
    bit [AST_DWIDTH-1:0] out_packet_gen[$];
    bit [EMPTY_SIZE-1:0] empty_gen;
    bit                  channel_gen;
    
    bit [AST_DWIDTH-1:0] out_packet_sink[$];
    bit [EMPTY_SIZE-1:0] empty_sink;
    bit                  channel_sink;
    
    while( cntr < num )
      begin
        cntr += 1;
        
        out_packet_gen = {};
        empty_gen = 0;
        channel_gen = 0;
        
        out_packet_sink = {};
        empty_sink = 0;
        channel_sink = 0;
        
        this.from_gen.get( out_packet_gen );
        this.from_gen.get( empty_gen );
        this.from_gen.get( channel_gen );
        
        if( ( only_ch == 1 ) && ( channel_gen == 0 ) )
          continue;
        else
          begin
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
            if( ( channel_sink != channel_gen ) && ( only_ch == 0 ) )
              begin
                $display("AstArbiter.check_data - channel mismatch");
                $display("Channel read = %d; channel generated = %d", channel_sink, channel_gen);
                $stop();
              end
            $display("AST_Arbiter.check_data - read successfully");
          end
        
        
      end   
    
    endtask
    
  task automatic check_data( int num, bit only_ch );
    fork
      this.ast_src.send_data( num );      
      this.ast_sink.read_data( num );
    join_none
    this.compare_data( num, only_ch );
    

  endtask
  
  task automatic run( int num = 1, bit only_ch = 0 );
    this.check_data( num, only_ch );
  endtask
  
endclass

endpackage
