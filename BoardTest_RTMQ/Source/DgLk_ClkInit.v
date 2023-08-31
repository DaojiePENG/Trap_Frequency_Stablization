module DgLk_ClkInit(clk, hold, csb, sclk, mosi);

parameter AdrWid = 8;
parameter ScrLen = 1;
parameter IniScr = "";

localparam Len = 1 << AdrWid;
localparam DatWid = 24;
localparam DlyWid = 5;
localparam ClkDiv = 1 << (DlyWid - 1);

input  clk;
output hold;
output csb;
output sclk;
output mosi;

reg [AdrWid-1 : 0] adr = 0;
reg hold = 1;
wire spi_snt;
always @ (posedge clk) adr <= adr + (spi_snt & hold);
always @ (posedge clk) hold <= (adr < ScrLen);

reg [DatWid-1 : 0] rom [0 : Len-1];
reg [DatWid-1 : 0] dat = 0;
always @ (posedge clk) dat <= rom[adr];

initial begin
  $readmemh(IniScr, rom);
end

reg [DlyWid : 0] dly_cntr = 0;
wire start;
EdgeIdfr #("pos") ESTR(clk, dly_cntr[DlyWid] & hold, start);
always @ (posedge clk) 
  if (spi_snt) dly_cntr <= 0;
  else dly_cntr <= dly_cntr + {{DlyWid{1'b0}}, ~dly_cntr[DlyWid]};

Core_SPIMaster #(.W_DAT(DatWid), .W_CNT(8))
  SPIM(.clk(clk), .dat_mosi(dat), .dat_miso(),
       .cpol(1), .cpha(1), .clk_div(ClkDiv), .bit_cnt(DatWid),
       .f_snd(start), .f_fin(spi_snt), .miso_ltn(0), .mosi_cnt(0), .bus_dir(),
       .csb(csb), .sclk(sclk), .mosi(mosi), .miso(0));

endmodule
