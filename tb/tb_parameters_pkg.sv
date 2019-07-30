package tb_parameters_pkg;

parameter int CLK_T          = 60;
parameter int AMM_DWIDTH     = 32; // bits
parameter int AMM_NUM_REGS   = 4;
parameter int AMM_DATA_LEN   = AMM_NUM_REGS-1;
parameter int AMM_AWIDTH     = $clog2(AMM_NUM_REGS) + 1;
parameter int AST_DWIDTH     = 64; // bits
parameter int STR_LEN        = 12; // bytes
parameter int BITS_PER_SYMB  = 8;
parameter int BITS_IN_ASCII  = 7;
parameter int SYMB_IN_AMM    = AMM_DWIDTH / BITS_PER_SYMB;
parameter int SYMB_IN_AST    = AST_DWIDTH / BITS_PER_SYMB;
// somehow ceil == floor, so +1
parameter int DW_MAX_PACKET_LEN = $ceil( 1514 * 8 / AST_DWIDTH ) + 1; // in dwords
parameter int DW_MIN_PACKET_LEN = $ceil(   60 * 8 / AST_DWIDTH ) + 1; //
// in bytes
parameter int MAX_PACKET_LEN    = DW_MAX_PACKET_LEN * AST_DWIDTH / BITS_PER_SYMB;
parameter int MIN_PACKET_LEN    = DW_MIN_PACKET_LEN * AST_DWIDTH / BITS_PER_SYMB;
parameter int EMPTY_SIZE        = $clog2(AST_DWIDTH / BITS_PER_SYMB);

typedef bit [AMM_DWIDTH-1:0] regtype [AMM_NUM_REGS-1:0];
typedef bit [AMM_DWIDTH-1:0] regdata [AMM_DATA_LEN-1:0];

endpackage
