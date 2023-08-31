module UART_Rx(clk, baud, dat, f_fin, f_tot, uart_rxd);

parameter N_BYT = 4;                      // Number of bytes to receive
parameter W_BAU = 10;                     // Width of baud counter
parameter S_TOT = 17;                     // Timeout scale

localparam W_DAT = 8 * N_BYT;             // Width of <dat>

input                clk;                 // System clock
input  [W_BAU-1 : 0] baud;                // Baud count (clock divider, min: 2)
output [W_DAT-1 : 0] dat;                 // Bytes received
output               f_fin;               // Finish flag (one-cycle positive pulse)
output               f_tot;               // Timeout flag (one-cycle positive pulse)
                                          //   If required number of bytes are not yet received, 
                                          //     then after (<baud> << S_TOT) clock cycles since last byte receive,
                                          //     <f_tot> is asserted.
input                uart_rxd;            // RxD line

// ------ Input Buffering ------

reg  rxd_iob = 1;                         // IOB register for RxD
always @ (posedge clk) rxd_iob <= uart_rxd;

// ------ State Registers & Flags ------

reg  [W_DAT-1 : 0] dat = 0;               // RxD data output
reg  [W_DAT-1 : 0] dat_buf = 0;           // RxD data buffer
reg  [N_BYT-1 : 0] ctr_byt = 1;           // Byte counter
reg  [W_BAU-1 : 0] bau_buf = 2;           // Baud count buffer

reg  f_fin = 0;                           // Finish flag
reg  f_tot = 0;                           // Timeout flag
reg  f_tot_pre = 0;
wire w_tot;                               // Byte receive timeout signal
wire f_bsy;                               // Busy state flag
wire f_rcv;                               // Byte receive flag
reg  f_rcv_dly;
wire w_fin = f_bsy & ctr_byt[0] & f_rcv_dly;

SRFlag #(.Pri("rst"), .PUS(0))
  FBSY(.clk(clk), .set(~rxd_iob), .rst(w_fin | w_tot), .flg(f_bsy));

always @ (posedge clk) f_rcv_dly <= f_rcv;
always @ (posedge clk)
if (~f_bsy)
  bau_buf <= baud;
else
  bau_buf <= bau_buf;

// ------ Input Buffering & Counting ------

wire [ 7 : 0] byt;
UART_Rx_Byte #(.W_BAU(W_BAU), .S_TOT(S_TOT))
  BRCV(.clk(clk), .baud(bau_buf), .dat(byt), .f_fin(f_rcv), .f_tot(w_tot), .rxd(rxd_iob));

always @ (posedge clk)
if (f_rcv)
  dat_buf <= {dat_buf, byt};
else if (f_tot_pre)
  dat_buf <= 0;
else
  dat_buf <= dat_buf;

always @ (posedge clk)
if (f_rcv)
  ctr_byt <= {ctr_byt, ctr_byt[N_BYT-1]};
else if (f_tot_pre)
  ctr_byt <= 1;
else
  ctr_byt <= ctr_byt;

// ------ Output Behavior ------

reg  fin_dly = 0;
always @ (posedge clk)
begin
  {f_fin, fin_dly} <= {fin_dly, w_fin};
  {f_tot, f_tot_pre} <= {f_tot_pre, w_tot & f_bsy};
  if (fin_dly | f_tot_pre)
    dat <= dat_buf;
  else
    dat <= dat;
end

endmodule


// -------------------------------------------------------------------------


module UART_Rx_Byte(clk, baud, dat, f_fin, f_tot, rxd);

parameter W_BAU = 10;                     // Width of baud counter
parameter S_TOT = 17;                     // Timeout scale

localparam W_CTT = W_BAU + S_TOT + 1;     // Width of timeout counter

input                clk;                 // System clock
input  [W_BAU-1 : 0] baud;                // Baud count (clock divider)
output [ 7      : 0] dat;                 // Byte received
output               f_fin;               // Finish flag (one-cycle positive pulse)
output               f_tot;               // Timeout flag (one-cycle positive pulse)
                                          //   After (<baud> << S_TOT) clock cycles since last byte receive,
                                          //     <f_tot> is asserted.
input                rxd;                 // RxD line

// ------ State Registers & Flags ------

reg  [ 7      : 0] dat = 0;               // Byte received
reg  [ 7      : 0] dat_buf = 0;           // RxD data buffer
reg  [ 9      : 0] ctr_bit = 1;           // Bit counter
reg  [W_BAU-1 : 0] ctr_bau = 0;           // Baud counter
reg  [W_BAU-1 : 0] ctr_smp = 0;           // Bit sampling counter
reg  [W_CTT-1 : 0] ctr_tot = 0;           // Timeout counter

reg  rxd_buf = 1;                         // Buffer register for RxD
reg  f_tck = 0;                           // Baud counter tick
reg  d_cbt = 0;                           // Sampling result of current bit
reg  f_fin = 0;                           // Finish flag
reg  f_tot = 0;                           // Timeout flag
wire f_bsy;                               // Busy state flag
wire w_fin = f_bsy & ctr_bit[9] & (((ctr_smp == (baud >> 1) - 1) & rxd_buf) | f_tck);

SRFlag #(.Pri("rst"), .PUS(0))
  FBSY(.clk(clk), .set(~rxd), .rst(w_fin), .flg(f_bsy));

// ------ Baud Generation ------

always @ (posedge clk) f_tck <= f_bsy & (ctr_bau == 2);
always @ (posedge clk)
if (~f_bsy | f_tck)
  ctr_bau <= baud;
else
  ctr_bau <= ctr_bau - 1;

// ------ Input Sampling ------

reg  tck_dly = 0;
always @ (posedge clk)
begin
  d_cbt <= (ctr_smp >= (baud >> 1));
  rxd_buf <= rxd;
  tck_dly <= f_tck;
  if (f_tck)
    ctr_smp <= 0;
  else
    ctr_smp <= ctr_smp + rxd_buf;
  if (tck_dly)
    dat_buf <= {d_cbt, dat_buf[7 : 1]};
  else dat_buf <= dat_buf;
  if (~f_bsy)
    ctr_bit <= 1;
  else if (f_tck)
    ctr_bit <= ctr_bit << 1;
  else ctr_bit <= ctr_bit;
end

// ------ Output Behavior ------

reg  fin_dly = 0;
always @ (posedge clk) {f_fin, fin_dly} <= {fin_dly, w_fin};
always @ (posedge clk)
if (fin_dly)
  dat <= dat_buf;
else
  dat <= dat;

// ------ Timeout Control ------

reg  f_dcr = 0;
always @ (posedge clk)
begin
  f_dcr <= (ctr_tot > 1) & ~f_bsy;
  f_tot <= (ctr_tot == 1);
  if (f_fin)
    ctr_tot <= baud << S_TOT;
  else
    ctr_tot <= ctr_tot - f_dcr;
end

endmodule
