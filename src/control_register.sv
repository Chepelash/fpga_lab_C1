module control_register #(
  parameter REG_WIDTH = 32,
  parameter REG_DEPTH = 4,
  parameter PAT_WIDTH = REG_DEPTH - 1
)(
  input                        clk_i,
  input                        srst_i,
  
  avalon_mm_if.slave           amm_slave_if,
  
  output logic [REG_WIDTH-1:0] pattern_o [PAT_WIDTH-1:0],
  output logic                 wrken_o
);

//localparam PAT_WIDTH = REG_DEPTH - 1;


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
logic [REG_WIDTH-1:0] reg_map [REG_DEPTH-1:0];

// avalon-mm siglans reassign
logic [REG_DEPTH-1:0]  address_i;
logic                  write_i;
logic [REG_WIDTH-1:0] writedata_i;
logic                  read_i;
logic                  waitrequest_o;
logic [REG_WIDTH-1:0] readdata_o; 
logic                  readdatavalid_o;

assign address_i   = amm_slave_if.address;
assign write_i     = amm_slave_if.write;
assign writedata_i = amm_slave_if.writedata;
assign read_i      = amm_slave_if.read;

assign amm_slave_if.waitrequest   = waitrequest_o;
assign amm_slave_if.readdata      = readdata_o; 
assign amm_slave_if.readdatavalid = readdatavalid_o;

// pattern assign to key symbols
generate
  genvar i;
  for( i = PAT_WIDTH; i > 0; i-- )
    begin : pattern_assign
      assign pattern_o[i-1] = reg_map[i];
    end  
endgenerate


// wrken = reg_map[0][0]
assign wrken_o = reg_map[0][0];


// reg_map control
always_ff @( posedge clk_i )
  begin
    if( srst_i )
      reg_map <= '{default: '1};
    else
      begin : main_else
        // reading and writing to reg_map via avalon mm slave
        case( { read_i, write_i } )
          2'b10: begin // read
            readdata_o      <= reg_map[address_i];
            readdatavalid_o <= '1;
          end
          
          2'b01: begin // write
            reg_map[address_i] <= writedata_i;            
            readdatavalid_o    <= '0;
          end
          
          2'b11: begin // read/write
            // data writing
            reg_map[address_i] <= writedata_i;        
            // data reading
            readdata_o         <= reg_map[address_i]; 
            readdatavalid_o    <= '1;
          end
          
          default: begin // no op
            readdatavalid_o <= '0;
          end
        endcase
      end   : main_else
  end




endmodule
