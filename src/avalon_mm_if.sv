interface avalon_mm_if;

logic        waitrequest;
logic [3:0]  address;
logic        write;
logic [31:0] writedata;
logic        read;
logic [31:0] readdata;
logic        readdatavalid;

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
