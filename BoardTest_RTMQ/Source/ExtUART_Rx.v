module ExtUART_Rx(clk, baud, dat, f_fin, f_tot, exu_rxd);

parameter N_SEG = 2;                              // Number of segments to receive
parameter N_DMF = 4;                              // Number of data mini-frames per segment
parameter W_BUS = 4;                              // Width of RxD bus
parameter W_BAU = 8;                              // Width of baud counter
parameter S_TOT = 17;                             // Timeout scale

localparam W_SEG = N_DMF * W_BUS;                 // Width of segment
localparam W_DAT = W_SEG * N_SEG;                 // Width of received data

input                clk;                         // System clock
input  [W_BAU-1 : 0] baud;                        // Baud count (clock divider, min: 2)
output [W_DAT-1 : 0] dat;                         // Data received
output               f_fin;                       // Finish flag (one-cycle positive pulse)
output               f_tot;                       // Timeout flag (one-cycle positive pulse)
                                                  //   If required number of bytes are not yet received, 
                                                  //     then after (<baud> << S_TOT) clock cycles since last byte receive,
                                                  //     <f_tot> is asserted.
input  [W_BUS-1 : 0] exu_rxd;                     // RxD bus

// ------ Input Buffering ------

reg  [W_BUS-1 : 0] rxd_iob = {{W_BUS{1'b1}}};     // IOB register for RxD
always @ (posedge clk) rxd_iob <= exu_rxd;

// ------ State Registers & Flags ------

reg  [W_DAT-1 : 0] dat = 0;                       // RxD data output
reg  [W_DAT-1 : 0] dat_buf = 0;                   // RxD data buffer
reg  [N_SEG-1 : 0] ctr_seg = 1;                   // Segment counter
reg  [W_BAU-1 : 0] bau_buf = 2;                   // Baud count buffer

reg  f_fin = 0;                                   // Finish flag
reg  f_tot = 0;                                   // Timeout flag
reg  f_tot_pre = 0;
wire w_tot;                                       // Segment receive timeout signal
wire f_bsy;                                       // Busy state flag
wire f_rcv;                                       // Segment receive flag
reg  f_rcv_dly;
wire w_fin = f_bsy & ctr_seg[0] & f_rcv_dly;

SRFlag #(.Pri("rst"), .PUS(0))
  FBSY(.clk(clk), .set(~rxd_iob[0]), .rst(w_fin | w_tot), .flg(f_bsy));

always @ (posedge clk) f_rcv_dly <= f_rcv;
always @ (posedge clk)
if (~f_bsy)
  bau_buf <= baud;
else
  bau_buf <= bau_buf;

// ------ Input Buffering & Counting ------

wire [W_SEG-1 : 0] seg;
ExtUART_Rx_Seg #(.N_DMF(N_DMF), .W_BUS(W_BUS), .W_BAU(W_BAU), .S_TOT(S_TOT))
  SRCV(.clk(clk), .baud(bau_buf), .seg(seg), .f_fin(f_rcv), .f_tot(w_tot), .rxd(rxd_iob));

always @ (posedge clk)
if (f_rcv)
  dat_buf <= {dat_buf, seg};
else if (f_tot_pre)
  dat_buf <= 0;
else
  dat_buf <= dat_buf;

always @ (posedge clk)
if (f_rcv)
  ctr_seg <= {ctr_seg, ctr_seg[N_SEG-1]};
else if (f_tot_pre)
  ctr_seg <= 1;
else
  ctr_seg <= ctr_seg;

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


module ExtUART_Rx_Seg(clk, baud, seg, f_fin, f_tot, rxd);

parameter N_DMF = 4;                              // Number of data mini-frames per segment
parameter W_BUS = 4;                              // Width of RxD bus
parameter W_BAU = 8;                              // Width of baud counter
parameter S_TOT = 17;                             // Timeout scale

localparam W_SEG = N_DMF * W_BUS;                 // Width of segment
localparam W_CTT = W_BAU + S_TOT + 1;             // Width of timeout counter

input                clk;                         // System clock
input  [W_BAU-1 : 0] baud;                        // Baud count (clock divider)
output [W_SEG-1 : 0] seg;                         // Segment received
output               f_fin;                       // Finish flag (one-cycle positive pulse)
output               f_tot;                       // Timeout flag (one-cycle positive pulse)
                                                  //   After (<baud> << S_TOT) clock cycles since last byte receive,
                                                  //     <f_tot> is asserted.
input  [W_BUS-1 : 0] rxd;                         // RxD bus

// ------ State Registers & Flags ------

reg  [W_SEG-1 : 0] seg = 0;                       // Segment received
reg  [W_SEG-1 : 0] seg_buf = 0;                   // RxD data buffer
reg  [N_DMF+1 : 0] ctr_frm = 1;                   // Mini-frame counter
reg  [W_BAU-1 : 0] ctr_bau = 0;                   // Baud counter
reg  [W_CTT-1 : 0] ctr_tot = 0;                   // Timeout counter
reg  [W_BUS-1 : 0] rxd_buf = {{W_BUS{1'b1}}};     // Buffer register for RxD
reg  [W_BUS-1 : 0] d_cfm = 0;                     // Sampling result of current mini-frame

localparam W_CSP = W_BAU * W_BUS;                 // Total width of bit sampling counters
reg  [W_CSP-1 : 0] ctr_smp = 0;                   // Bit sampling counters

reg  f_tck = 0;                                   // Baud counter tick
reg  f_fin = 0;                                   // Finish flag
reg  f_tot = 0;                                   // Timeout flag
wire f_bsy;                                       // Busy state flag
wire w_fin = f_bsy & ctr_frm[N_DMF+1] & (((ctr_smp[W_BAU-1 : 0] == (baud >> 1) - 1) & rxd_buf[0]) | f_tck);

SRFlag #(.Pri("rst"), .PUS(0))
  FBSY(.clk(clk), .set(~rxd[0]), .rst(w_fin), .flg(f_bsy));

// ------ Baud Generation ------

always @ (posedge clk) f_tck <= f_bsy & (ctr_bau == 2);
always @ (posedge clk)
if (~f_bsy | f_tck)
  ctr_bau <= baud;
else
  ctr_bau <= ctr_bau - 1;

// ------ Input Sampling ------

genvar i;
generate
  for (i = 0; i < W_BUS; i = i + 1)
  begin

    always @ (posedge clk) d_cfm[i] <= (ctr_smp[W_BAU*(i+1)-1 : W_BAU*i] >= (baud >> 1));
    always @ (posedge clk)
    if (f_tck)
      ctr_smp[W_BAU*(i+1)-1 : W_BAU*i] <= 0;
    else
      ctr_smp[W_BAU*(i+1)-1 : W_BAU*i] <= ctr_smp[W_BAU*(i+1)-1 : W_BAU*i] + rxd_buf[i];

  end
endgenerate

reg  tck_dly = 0;
always @ (posedge clk)
begin
  rxd_buf <= rxd;
  tck_dly <= f_tck;
  if (tck_dly)
    seg_buf <= {d_cfm, seg_buf[W_SEG-1 : W_BUS]};
  else seg_buf <= seg_buf;
  if (~f_bsy)
    ctr_frm <= 1;
  else if (f_tck)
    ctr_frm <= ctr_frm << 1;
  else ctr_frm <= ctr_frm;
end

// ------ Output Behavior ------

reg  fin_dly = 0;
always @ (posedge clk) {f_fin, fin_dly} <= {fin_dly, w_fin};
always @ (posedge clk)
if (fin_dly)
  seg <= seg_buf;
else
  seg <= seg;

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
