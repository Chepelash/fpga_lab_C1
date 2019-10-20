module fifo #(
  parameter DWIDTH = 8,
  parameter AWIDTH = 4,
  parameter SWIDTH = 1
)(
  input                     clk_i,
  input                     srst_i,
  
  input                     rd_i,
  input                     wr_i,
  input        [DWIDTH-1:0] wrdata_i,
  // modification
  /*
    if shift > 1 - skip some values in read phase
  */
  input        [SWIDTH-1:0] shift_i,
  // end modification
  output logic              empty_o,
  output logic              full_o,
  output logic [DWIDTH-1:0] rddata_o
);

// write pointers
logic [AWIDTH-1:0] wrpntr;
logic [AWIDTH-1:0] wrpntr_next;
logic [AWIDTH-1:0] wrpntr_succ;

// read pointers
logic [AWIDTH-1:0] rdpntr;
logic [AWIDTH-1:0] rdpntr_next;
logic [AWIDTH-1:0] rdpntr_succ;

// status signals
logic full;
logic full_next;
logic empty;
logic empty_next;
logic wren;

logic [AWIDTH-1:0] shift;


(* ramstyle = "M10K, no_rw_check" *) logic [DWIDTH-1:0] mem [2**AWIDTH-1:0];

assign wren    = wr_i & ( ~full );
assign full_o  = full;
assign empty_o = empty;

always_comb
  begin
    shift = '0 + shift_i;
  end

// reading mechanism
always_ff @( posedge clk_i )
  begin
    rddata_o <= mem[rdpntr];
  end
//assign rddata_o = mem[rdpntr];

// writing mechanism
always_ff @( posedge clk_i )
  begin
    if( wren )
      mem[wrpntr] <= wrdata_i;
  end


always_ff @( posedge clk_i )
  begin
    if( srst_i )
      begin
        wrpntr <= '0;
        rdpntr <= '0;
        full   <= '0;
        empty  <= '1;
      end
    else
      begin
        wrpntr <= wrpntr_next;
        rdpntr <= rdpntr_next;
        full   <= full_next;
        empty  <= empty_next;
      end
  end

always_comb
  begin
    //
    wrpntr_succ = wrpntr + 1'b1;
    rdpntr_succ = rdpntr + shift;
    //
    wrpntr_next = wrpntr;
    rdpntr_next = rdpntr;
    full_next   = full;
    empty_next  = empty;
    case ( {wr_i, rd_i} )
      // reading
      2'b01: begin 
        if( ~empty )
          begin
            rdpntr_next = rdpntr_succ;
            full_next   = '0;
            if( rdpntr_succ == wrpntr )
              empty_next = '1;
          end
      end
      // writing
      2'b10: begin 
        if( ~full )
          begin
            wrpntr_next = wrpntr_succ;
            empty_next  = '0;
            if( wrpntr_succ == rdpntr )
              full_next = '1;
          end
      end
      // reading and writing
      2'b11: begin
        wrpntr_next = wrpntr_succ;
        rdpntr_next = rdpntr_succ;
      end
      
      default: begin
        // no operation
      end
    endcase
  end

endmodule
