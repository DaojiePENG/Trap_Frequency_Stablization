module RTMQ_USBInterface(clk, alu_out, cfg_ins, f_cfg,
                         usb_dat, usb_rxf, usb_txe, usb_rdn, usb_wrn);

`include "RTMQ_Peripheral.v"

input                clk;           // System clock
input  [W_ALU-1 : 0] alu_out;       // ALU output bus
output [W_REG-1 : 0] cfg_ins;       // Configuration instruction
output               f_cfg;         // Configuration override flag
inout  [ 7      : 0] usb_dat;
input                usb_rxf;
input                usb_txe;
output               usb_rdn;
output               usb_wrn;

wire [W_REG-1 : 0] d_txd;           // Frame to send
wire               f_snd;           // Frame send flag
RTMQ_GPRegister #(.ADDR(R_URT))
  RURT(.clk(clk), .alu_out(alu_out), .reg_out(d_txd), .f_trg(f_snd));

localparam W_CFG = W_REG + 8;
wire [W_CFG-1 : 0] dat_rx;
reg  [W_REG-1 : 0] cfg_ins = I_NOP;
reg                f_cfg = 0; 
wire               f_rcv;

FT245_FIFO #(.RxBCnt(W_CFG / 8), .TxBCnt(W_REG / 8), .ClkFrq(F_CLK))
  FIFO(.clk(clk), .bus(usb_dat), .rxf(usb_rxf), .txe(usb_txe), .rdn(usb_rdn), .wrn(usb_wrn),
       .txd(d_txd), .flg(f_snd), .snt(), .rxd(dat_rx), .rcv(f_rcv));

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
