module RTMQ_UART(clk, alu_out, cfg_ins, f_cfg, f_tx_done, uart_rx, uart_tx);

`include "RTMQ_Peripheral.v"

input                clk;           // System clock
input  [W_ALU-1 : 0] alu_out;       // ALU output bus
output [W_REG-1 : 0] cfg_ins;       // Configuration instruction
output               f_cfg;         // Configuration override flag
output               f_tx_done;     // Tx finish flag

input                uart_rx;       // UART Rx line
output               uart_tx;       // UART Tx line

wire [W_REG-1 : 0] d_txd;           // Frame to send
wire               f_snd;           // Frame send flag
RTMQ_GPRegister #(.ADDR(R_URT))
/*
  功能：通过该通用寄存器给串口提供发送数据
*/
  RURT(.clk(clk), .alu_out(alu_out), .reg_out(d_txd), .f_trg(f_snd));

UART_Tx #(.N_BYT(W_REG / 8), .W_BAU(8), .N_STB(1))
  UTXD(.clk(clk), .baud(F_CLK / F_BDR), .dat(d_txd), .f_snd(f_snd), .f_fin(f_tx_done), .uart_txd(uart_tx));

localparam W_CFG = W_REG + 8;
wire [W_CFG-1 : 0] dat_rx;
reg  [W_REG-1 : 0] cfg_ins = I_NOP;
reg                f_cfg = 0; 
wire               f_rcv;

UART_Rx #(.N_BYT(W_CFG / 8), .W_BAU(8), .S_TOT(17))
  URCV(.clk(clk), .baud(F_CLK / F_BDR), .dat(dat_rx), .f_fin(f_rcv), .f_tot(), .uart_rxd(uart_rx));

always @ (posedge clk)
if (f_rcv)
// 1.若接收完成，将接收到的结果低32位赋给cfg_ins；第33位赋值给配置标志位f_cfg
begin
  cfg_ins <= dat_rx[W_REG-1 : 0];
  f_cfg <= dat_rx[W_REG];
end
else
begin
  cfg_ins <= I_NOP;
  f_cfg <= f_cfg;
end

endmodule
