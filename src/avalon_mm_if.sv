interface avalon_mm_if #(
  parameter DWIDTH = 32,
  parameter AWIDTH = 2
);

logic              waitrequest;
logic [AWIDTH-1:0] address;
logic              write;
logic [DWIDTH-1:0] writedata;
logic              read;
logic [DWIDTH-1:0] readdata;
logic              readdatavalid;

modport slave ( 
  input address, 
  input write, 
  input writedata, 
  input read, 
  
  output waitrequest, 
  output readdata, 
  output readdatavalid
);

modport master ( 
  output address, 
  output write, 
  output writedata, 
  output read, 
  
  input  waitrequest, 
  input  readdata, 
  input  readdatavalid
);

endinterface
