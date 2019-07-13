module fifo #(
  parameter DWIDTH = 8,
  parameter AWIDTH = 4
)(
  input                     clk_i,
  input                     srst_i,
  
  input                     rd_i,
  input                     wr_i,
  input        [DWIDTH-1:0] wrdata_i,
  
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

assign wren    = wr_i & ( ~full );
assign full_o  = full;
assign empty_o = empty;

ram_memory #(
  .DWIDTH   ( DWIDTH   ),
  .AWIDTH   ( AWIDTH   )
) mem       (
  .clk_i    ( clk_i    ),
  
  .wren_i   ( wren     ),
  .wrpntr_i ( wrpntr   ),
  .data_i   ( wrdata_i ),
  
  .rdpntr_i ( rdpntr   ),
  
  .q_o      ( rddata_o )
);

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
    rdpntr_succ = rdpntr + 1'b1;
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
    endcase
  end

endmodule
