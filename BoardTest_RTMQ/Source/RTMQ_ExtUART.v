module RTMQ_ExtUART(clk, alu_out, reg_exu, f_exu_rxdn, f_exu_txdn, exu_rx, exu_tx);

parameter ADDR_DAT = 0;
parameter ADDR_CFG = 0;

`include "RTMQ_Peripheral.v"

input                clk;           // System clock
input  [W_ALU-1 : 0] alu_out;       // ALU output bus
output [W_REG-1 : 0] reg_exu;       // Rx data output

output               f_exu_rxdn;    // ExtUART Rx finish flag
output               f_exu_txdn;    // ExtUART Tx finish flag

input  [ 7      : 0] exu_rx;        // ExtUART Rx line
output [ 7      : 0] exu_tx;        // ExtUART Tx line

wire [W_REG-1 : 0] d_txd;           // Frame to send
wire               f_snd;           // Frame send flag
RTMQ_GPRegister #(.ADDR(ADDR_DAT))
  RURT(.clk(clk), .alu_out(alu_out), .reg_out(d_txd), .f_trg(f_snd));

wire [W_REG-1 : 0] d_cfg;
RTMQ_GPRegister #(.ADDR(ADDR_CFG))
  RCFG(.clk(clk), .alu_out(alu_out), .reg_out(d_cfg), .f_trg());

ExtUART_Tx #(.N_SEG(1), .N_DMF(4), .N_SMF(1), .W_BUS(8), .W_BAU(8))
  EUTX(.clk(clk), .baud(d_cfg[15:0]), .dat(d_txd), .f_snd(f_snd), .f_fin(f_exu_txdn), .exu_txd(exu_tx));

ExtUART_Rx #(.N_SEG(1), .N_DMF(4), .W_BUS(8), .W_BAU(8), .S_TOT(17))
  EURX(.clk(clk), .baud(d_cfg[31:16]), .dat(reg_exu), .f_fin(f_exu_rxdn), .f_tot(), .exu_rxd(exu_rx));

endmodule
