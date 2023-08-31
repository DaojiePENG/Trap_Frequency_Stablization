module UART_Tx(clk, baud, dat, f_snd, f_fin, uart_txd);

parameter N_BYT = 4;                      // Number of bytes to be sent
parameter W_BAU = 10;                     // Width of baud counter
parameter N_STB = 1;                      // Stop bit (min: 1)

localparam W_DAT = 8 * N_BYT;             // Width of <dat>
localparam W_BUF = (9 + N_STB) * N_BYT;   // Width of Tx buffer
localparam W_CBT = $clog2(W_BUF + 1);     // Width of bit counter

input                clk;                 // System clock
input  [W_BAU-1 : 0] baud;                // Baud count (clock divider, min: 2)
input  [W_DAT-1 : 0] dat;                 // Bytes to be sent
input                f_snd;               // Send flag (one-cycle positive pulse)
output               f_fin;               // Finish flag (one-cycle positive pulse)
output               uart_txd;            // TxD line

// ------ Output Buffering ------

reg  txd_buf = 1'b1;                      // Buffer register for TxD
reg  txd_iob = 1'b1;                      // IOB register for TxD
assign uart_txd = txd_iob;
always @ (posedge clk) txd_iob <= txd_buf;

// ------ State Registers & Flags ------

reg  [W_BUF-1 : 0] dat_buf = 0;           // TxD data buffer
reg  [W_BAU-1 : 0] ctr_bau = 0;           // Baud counter
reg  [W_CBT-1 : 0] ctr_bit = 0;           // Bit counter

reg  f_tck = 0;                           // Baud counter tick
reg  f_fin = 0;                           // Finish flag
wire f_bsy;                               // Busy state flag
wire w_fin = f_bsy & (ctr_bit == 0) & f_tck;

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

wire [W_BUF-1 : 0] t_buf;

genvar i;
generate
  for (i = 0; i < N_BYT; i = i + 1)
  begin

    assign t_buf[(9+N_STB)*(i+1)-1 : (9+N_STB)*i] = {{(N_STB){1'b1}}, dat[8*(N_BYT-i)-1 : 8*(N_BYT-i-1)], 1'b0};

  end
endgenerate

always @ (posedge clk)
if (f_snd) 
begin
  {dat_buf, txd_buf} <= {t_buf, 1'b1};
  ctr_bit <= W_BUF;
end
else if (f_tck)
begin
  {dat_buf, txd_buf} <= {1'b1, dat_buf};
  ctr_bit <= ctr_bit - 1;
end
else {dat_buf, txd_buf, ctr_bit} <= {dat_buf, txd_buf, ctr_bit};

always @ (posedge clk) f_fin <= w_fin;

endmodule
