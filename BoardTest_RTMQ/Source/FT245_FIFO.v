module FT245_FIFO(clk, bus, rxf, txe, rdn, wrn, txd, flg, snt, rxd, rcv);

parameter RxBCnt = 5;
parameter TxBCnt = 2;
parameter ClkFrq = 200000000;

localparam TimOut = ClkFrq / 100;
localparam RxW = RxBCnt * 8;
localparam TxW = TxBCnt * 8;
localparam sW = 5;

input  clk;
inout  [7 : 0] bus;
input  rxf;
input  txe;
output rdn;
output wrn;
input  [TxW-1 : 0] txd;
input  flg;
output snt;
output [RxW-1 : 0] rxd;
output rcv;

wire [sW-1 : 0] sRead;
wire [sW-1 : 0] sRdnH;
wire [sW-1 : 0] sWrnL;
wire [sW-1 : 0] sWrnH;

generate
if (ClkFrq == 250000000)
begin
  assign sRead = 8;
  assign sRdnH = 13;
  assign sWrnL = 4; 
  assign sWrnH = 15; 
end
if (ClkFrq == 200000000)
begin
  assign sRead = 5;
  assign sRdnH = 8;
  assign sWrnL = 2; 
  assign sWrnH = 11; 
end
else if (ClkFrq == 100000000)
begin
  assign sRead = 3;
  assign sRdnH = 4;
  assign sWrnL = 1;
  assign sWrnH = 6;
end
else if (ClkFrq == 50000000)
begin
  assign sRead = 2;
  assign sRdnH = 3;
  assign sWrnL = 1;
  assign sWrnH = 3;
end
endgenerate

reg [21 : 0] tim_out = 0;
reg [sW-1 : 0] tx_sta = 0;
reg [sW-1 : 0] rx_sta = 0;
reg [3 : 0] tx_cnt = 0;
reg [3 : 0] rx_cnt = 0;
reg [TxW+7 : 0] txd_buf = 0;
reg [RxW-1 : 0] rxd_buf = 0;
(* IOB = "TRUE" *) reg [7 : 0] txd_iob_b0 = 0;
(* IOB = "TRUE" *) reg [7 : 0] rxd_iob_b0 = 0;
(* srl_style = "register" *) reg [7 : 0] txd_iob_b1 = 0;
(* srl_style = "register" *) reg [7 : 0] rxd_iob_b1 = 0;
(* srl_style = "register" *) reg [7 : 0] txd_iob_b2 = 0;
(* srl_style = "register" *) reg [7 : 0] rxd_iob_b2 = 0;
reg [RxW-1 : 0] rxd = 0;
reg snt = 0;
reg rcv = 0;
reg rxf_buf = 0;
reg txe_buf = 0;
reg new_tx = 0;
reg new_rx = 0;
reg brk = 0;
wire rdn;
wire wrn;
wire bsy_tx;
wire bsy_rx;
wire f_tx = new_tx & ~bsy_tx;
wire f_rx = new_rx & ~bsy_rx;
wire d_tx = txe_buf & bsy_tx & wrn;
wire d_rx = rxf_buf & bsy_rx;
wire frcv = (rx_cnt == RxBCnt);

assign bus = bsy_tx ? txd_iob_b0 : 8'bz;

SRFlag #("rst", 0) BSYT(clk, f_tx, d_tx, bsy_tx);
SRFlag #("rst", 0) BSYR(clk, f_rx, d_rx, bsy_rx);
SRFlag #("set", 1) FWRN(clk, tx_sta == sWrnH, bsy_tx & (tx_sta == sWrnL), wrn);
SRFlag #("set", 1) FRDN(clk, rx_sta == sRdnH, f_rx, rdn);

always @ (posedge clk)
begin
  {txd_iob_b0, txd_iob_b1, txd_iob_b2} <= {txd_iob_b1, txd_iob_b2, txd_buf[TxW+7 : TxW]};
  {rxd_iob_b0, rxd_iob_b1, rxd_iob_b2} <= {rxd_iob_b1, rxd_iob_b2, bus};
  if (bsy_rx | bsy_tx | brk) tim_out <= 0; else tim_out <= tim_out + 1;
  brk <= (tim_out == TimOut);
  rxf_buf <= rxf;
  txe_buf <= txe;
  new_tx <= ~((tx_cnt == 0) | txe_buf | bsy_rx | new_rx);
  new_rx <= ~((tx_cnt >  0) | rxf_buf | bsy_tx | new_tx); 
  if (flg) txd_buf <= {8'b0, txd}; else if (f_tx) txd_buf <= {txd_buf, 8'b0};
  if (flg) tx_cnt <= TxBCnt; else if (brk) tx_cnt <= 0; else tx_cnt <= tx_cnt - f_tx;
  if (f_tx) tx_sta <= 0; else tx_sta <= tx_sta + bsy_tx;
  snt <= d_tx & (tx_cnt == 0);
  if (f_rx) rx_sta <= 0; else rx_sta <= rx_sta + bsy_rx;
  if (rx_sta == sRead) rxd_buf <= {rxd_buf, rxd_iob_b0};
  if (brk | frcv) rx_cnt <= 0; else rx_cnt <= rx_cnt + d_rx;
  rcv <= frcv;
  if (frcv) rxd <= rxd_buf;
end

endmodule
