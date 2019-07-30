package amm_arbiter_pkg;

import tb_parameters_pkg::*;
import amm_driver_pkg::*;

class AMM_Arbiter;
  mailbox    gen_mbox;
  mailbox    amm_mbox;
  AMM_Driver amm_driver;
  logic clk_i;
  
  function new( mailbox gen_mbox, mailbox amm_mbox,
                AMM_Driver amm_driver);
    this.clk_i = clk_i;
    this.gen_mbox   = gen_mbox;
    this.amm_mbox   = amm_mbox;
    this.amm_driver = amm_driver;
  endfunction

  task write_registers();
    this.amm_driver.write_registers();
  endtask
  
  task check_data();
    regdata regs_wrote;
    regdata regs_read;
    this.amm_driver.read_regs();
    this.amm_mbox.get( regs_read );
    
    this.gen_mbox.get( regs_wrote );
    
    if( regs_read != regs_wrote )
      begin
        $display("AMM_Arbiter.check_data - read and wrote reg maps are different!");
        $stop();
      end
    else
      begin
        $display("AMM_Arbiter.check_data - registers has been written successfully");
      end
  endtask
  
  task run( int num = 1 );
    repeat( num )
      begin
        this.write_registers();
        this.check_data();
      end
  endtask
  
endclass

endpackage
