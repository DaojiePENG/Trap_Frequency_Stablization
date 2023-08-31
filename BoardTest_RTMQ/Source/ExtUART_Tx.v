module ExtUART_Tx(clk, baud, dat, f_snd, f_fin, exu_txd);

parameter N_SEG = 2;                              // Number of segments to be sent
parameter N_DMF = 4;                              // Number of data mini-frames per segment
parameter N_SMF = 1;                              // Number of stop mini-frames per segment (min: 1)
parameter W_BUS = 4;                              // Width of TxD bus
parameter W_BAU = 8;                              // Width of baud counter

localparam W_DAT = N_DMF * W_BUS * N_SEG;         // Width of input data
localparam N_FRM = (1 + N_DMF + N_SMF) * N_SEG;   // Number of total mini-frames per transaction
localparam W_BUF = N_FRM * W_BUS;                 // Width of Tx buffer
localparam W_CFR = $clog2(N_FRM + 1);             // Width of mini-frame counter

input                clk;                         // System clock
input  [W_BAU-1 : 0] baud;                        // Baud count (clock divider, min: 2)
input  [W_DAT-1 : 0] dat;                         // Data to be sent
input                f_snd;                       // Send flag (one-cycle positive pulse)
output               f_fin;                       // Finish flag (one-cycle positive pulse)
output [W_BUS-1 : 0] exu_txd;                     // TxD bus

// ------ Output Buffering ------

reg  [W_BUS-1 : 0] txd_buf = {{W_BUS{1'b1}}};     // Buffer register for TxD
reg  [W_BUS-1 : 0] txd_iob = {{W_BUS{1'b1}}};     // IOB register for TxD
assign exu_txd = txd_iob;
always @ (posedge clk) txd_iob <= txd_buf;

// ------ State Registers & Flags ------

reg  [W_BUF-1 : 0] dat_buf = 0;                   // TxD data buffer
reg  [W_BAU-1 : 0] ctr_bau = 0;                   // Baud counter
reg  [W_CFR-1 : 0] ctr_frm = 0;                   // Mini-frame counter

reg  f_tck = 0;                                   // Baud counter tick
reg  f_fin = 0;                                   // Finish flag
wire f_bsy;                                       // Busy state flag
wire w_fin = f_bsy & (ctr_frm == 0) & f_tck;

SRFlag #(.Pri("rst"), .PUS(0))
  FBSY(.clk(clk), .set(f_snd), .rst(w_fin), .flg(f_bsy));

// ------ Baud Generation ------

always @ (posedge clk) f_tck <= f_bsy & (ctr_bau == 2);
always @ (posedge clk)
if (f_snd | f_tck)
  ctr_bau <= baud;
else
  ctr_bau <= ctr_bau - 1;

// ------ Buffers, Counters & Output ------

localparam WS = (1 + N_DMF + N_SMF) * W_BUS;
localparam WD = N_DMF * W_BUS;

wire [W_BUF-1 : 0] t_buf;

genvar i;
generate
  for (i = 0; i < N_SEG; i = i + 1)
  begin

    assign t_buf[WS*(i+1)-1 : WS*i] = {{(W_BUS*N_SMF){1'b1}}, dat[WD*(N_SEG-i)-1 : WD*(N_SEG-i-1)], {W_BUS{1'b0}}};

  end
endgenerate

always @ (posedge clk)
if (f_snd)
begin
  {dat_buf, txd_buf} <= {t_buf, {W_BUS{1'b1}}};
  ctr_frm <= N_FRM;
end
else if (f_tck)
begin
  {dat_buf, txd_buf} <= {{W_BUS{1'b1}}, dat_buf};
  ctr_frm <= ctr_frm - 1;
end
else {dat_buf, txd_buf, ctr_frm} <= {dat_buf, txd_buf, ctr_frm};

always @ (posedge clk) f_fin <= w_fin;

endmodule
