module DgLk_SPIMultiplexer(clk, slv_adr,
                           csb, sclk, mosi, miso,
                           lmk, rom, atn0, atn1,
                           i_hold, i_csb, i_sclk, i_mosi);

`include "RTMQ_Peripheral.v"

localparam IDLE = {1'b0, SPI_CPOL, 1'b1};

input  clk;                    // System clock
input  [ 1 : 0] slv_adr;       // Target slave address
input  csb;
input  sclk;
input  mosi;
output miso;

inout  [ 3 : 0] lmk;
inout  [ 3 : 0] rom;
inout  [ 3 : 0] atn0;
inout  [ 3 : 0] atn1;

// LMK Initializer
input  i_hold;
input  i_csb;
input  i_sclk;
input  i_mosi;

reg  [ 2 : 0] lmk_buf  = IDLE;
reg  [ 2 : 0] rom_buf  = IDLE;
reg  [ 2 : 0] atn0_buf = IDLE;
reg  [ 2 : 0] atn1_buf = IDLE;

assign lmk  = i_hold ? {1'bz, i_mosi, i_sclk, i_csb} : {1'bz, lmk_buf};
assign rom  = {1'bz,  rom_buf};
assign atn0 = {1'bz, atn0_buf};
assign atn1 = {1'bz, atn1_buf};

reg  miso = 0;
wire [ 2 : 0] bus = {mosi, sclk, csb};
wire [ 3 : 0] inp = {atn1[3], atn0[3], rom[3], lmk[3]};

always @ (posedge clk)
begin
  if (slv_adr == SA_LMK ) lmk_buf  <= bus; else lmk_buf  <= IDLE;
  if (slv_adr == SA_ROM ) rom_buf  <= bus; else rom_buf  <= IDLE;
  if (slv_adr == SA_ATN0) atn0_buf <= bus; else atn0_buf <= IDLE;
  if (slv_adr == SA_ATN1) atn1_buf <= bus; else atn1_buf <= IDLE;
  miso <= inp[slv_adr];
end

endmodule
