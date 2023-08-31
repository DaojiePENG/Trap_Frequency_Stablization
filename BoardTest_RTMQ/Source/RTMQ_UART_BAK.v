module RTMQ_UART(clk, alu_out, cfg_ins, f_cfg, uart_rx, uart_tx);

`include "RTMQ_Peripheral.v"

input                clk;           // System clock
input  [W_ALU-1 : 0] alu_out;       // ALU output bus
output [W_REG-1 : 0] cfg_ins;       // Configuration instruction
output               f_cfg;         // Configuration override flag

input                uart_rx;       // UART Rx line
output               uart_tx;       // UART Tx line

wire [W_REG-1 : 0] d_txd;           // Frame to send
wire               f_snd;           // Frame send flag
RTMQ_GPRegister #(.ADDR(R_URT))
  RURT(.clk(clk), .alu_out(alu_out), .reg_out(d_txd), .f_trg(f_snd));

UART_Tx #(.Len(W_REG / 8), .Baud(F_CLK / F_BDR), .StopBit(1))
  UTXD(.clk(clk), .start(f_snd), .str(d_txd), .out(uart_tx), .sent());

localparam W_CFG = W_REG + 8;
wire [W_CFG-1 : 0] dat_rx;
reg  [W_REG-1 : 0] cfg_ins = I_NOP;
reg                f_cfg = 0; 
wire               f_rcv;

UART_Rx #(.Len(W_CFG / 8), .Baud(F_CLK / F_BDR))
  URCV(.clk(clk), .in(uart_rx), .str(dat_rx), .recv(f_rcv));

always @ (posedge clk)
if (f_rcv)
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
