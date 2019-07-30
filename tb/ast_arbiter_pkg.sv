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
    join_none

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
    $display("AST_Arbiter.check_data - read successfully");
  endtask
  
  task run( int num = 1 );
    repeat( num )
      this.check_data();
  endtask
  
endclass

endpackage
