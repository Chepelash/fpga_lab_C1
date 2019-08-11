module control_register #(
  parameter REG_WIDTH    = 32,
  parameter REG_DEPTH    = 4,
  parameter PAT_WIDTH    = REG_DEPTH - 1,
  parameter PAT_SIZE     = PAT_WIDTH * REG_WIDTH,
  parameter BIT_PER_SYMB = 8  
)(
  input                       clk_i,
  input                       srst_i,
  
  avalon_mm_if.slave          amm_slave_if,
  
  output logic [0:PAT_SIZE-1] pattern_o,
  output logic                wrken_o
);

localparam SYMB_IN_REG = REG_WIDTH / BIT_PER_SYMB;
localparam BITS_IN_PAT = REG_WIDTH * PAT_WIDTH;

// register map
/*
  0x0 - control register;
  0x1 - 0-3 key symbols;
  0x2 - 7-4 key symbols;
  0x3 - 11-8 key symbols.
----------------------------
0x0
  31:1 - Reserved;
  0    - Enable ( 1 -- ON, 0 -- OFF )  
*/
logic [REG_WIDTH-1:0] reg_map [REG_DEPTH-1:0] ;
logic [REG_WIDTH-1:0] reg_data [PAT_WIDTH-1:0];

// pattern assign to key symbols
//generate
//  genvar i;
//  for( i = PAT_WIDTH; i > 0; i-- )
//    begin : pattern_assign
//      assign pattern_o[REG_WIDTH*(i-1):REG_WIDTH*i-1] = reg_map[i];
//    end  
//endgenerate

logic [PAT_SIZE-1:0] pattern;

generate
  genvar i, j, m;
  for( j = 0; j < PAT_WIDTH; j++ )
    begin : pattern_assign
      for( i = 0; i < SYMB_IN_REG; i++ ) 
        begin : doing_patterns
          assign pattern_o[j*REG_WIDTH+i*BIT_PER_SYMB+:BIT_PER_SYMB] = reg_map[REG_DEPTH-j-1][REG_WIDTH-(i+1)*BIT_PER_SYMB+:BIT_PER_SYMB];
        end
    end  
//  j = 0;
//  for( i = 0; i < PAT_SIZE; i += REG_WIDTH )
//    begin : pattern_assign
//      pattern[i+:REG_WIDTH] = 
//    end
//  for( m = 0; m < BITS_IN_PAT; m = m + BIT_PER_SYMB )
//    begin : pattern_reorder
//      assign pattern_o[m+:BIT_PER_SYMB] = pattern[BITS_IN_PAT-m-BIT_PER_SYMB+:BIT_PER_SYMB];
//    end
endgenerate

// wrken = reg_map[0][0]
assign wrken_o = reg_map[0][0];

// reg_map control
// writing
always_ff @( posedge clk_i )
  begin
    if( srst_i )
      begin
        reg_map       <= '{default: '1};
        reg_map[0][0] <= '0;
      end

    else
      begin
        if( amm_slave_if.write )
          reg_map[amm_slave_if.address] <= amm_slave_if.writedata;         
      end
  end


// reading
assign amm_slave_if.readdatavalid = amm_slave_if.read;
assign amm_slave_if.readdata      = reg_map[amm_slave_if.address];

// waitrequest
assign amm_slave_if.waitrequest = '0;


endmodule
