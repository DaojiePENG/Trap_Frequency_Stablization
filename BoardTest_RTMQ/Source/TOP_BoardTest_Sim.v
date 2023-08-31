`timescale 1ns / 1ps

module TOP_BoardTest_RTMQ_Sim();

// ------ Configuration ----------

`include "RTMQ_Peripheral.v"

// ------ Test Bench ----------

parameter ClkPrd = 10;
reg clk = 0;
reg dds_clk = 0;
always #(ClkPrd / 2) clk = ~clk;
always #(ClkPrd / 4) dds_clk = ~dds_clk;

reg  f_cfg = 0;
reg  [W_REG-1 : 0] cfg_ins = 0;
reg  master_rsm = 0;

initial begin
  #5   master_rsm = 1;
  #10  master_rsm = 0;
//  #155 f_cfg = 1;
//       cfg_ins = 32'h970185CA;
  #10  f_cfg = 0;
       cfg_ins = 0;
end

// --- Unpack ALU bus ---
wire [W_REG-1 : 0] alu_res;
wire [W_REG-1 : 0] alu_msk;
wire [W_ADR-1 : 0] alu_rda;
wire [W_ADR-1 : 0] alu_r0a;
wire [W_ADR-1 : 0] alu_r1a;
wire [W_REG-1 : 0] imm_res;
wire [W_ADR-1 : 0] imm_rda;
wire               imm_seg;
assign {alu_res, alu_msk, alu_rda, alu_r0a, alu_r1a,
        imm_res, imm_rda, imm_seg} = alu_out;

// ------ Core ------

wire [W_ALU-1 : 0] alu_out;
wire [W_BUS-1 : 0] regfile;
wire [W_REG-1 : 0] if_adr;
wire [W_REG-1 : 0] if_ins;
wire               f_ftc;
wire               f_hld;
wire               f_rsm;
// wire               f_cfg;
// wire [W_REG-1 : 0] cfg_ins;

Core_RTMQ
  CORE(.clk(clk), .alu_out(alu_out), .regfile(regfile),
       .if_adr(if_adr), .if_ins(if_ins), .f_ftc(f_ftc),
       .f_hld(f_hld), .f_rsm(f_rsm),
       .f_cfg(f_cfg), .cfg_ins(cfg_ins));

// ------ Main Memory ------

wire [W_REG-1 : 0] adr_dat;
wire [W_REG-1 : 0] mem_dat;
wire [W_REG-1 : 0] d_wrt;
wire               f_wrt;

RTMQ_GPRegister #(.ADDR(R_ADR))      // Main memory data address register
  RADR(.clk(clk), .alu_out(alu_out), .reg_out(adr_dat), .f_trg());

RTMQ_GPRegister #(.ADDR(R_DAT))      // Main memory data write register
  RDAT(.clk(clk), .alu_out(alu_out), .reg_out(d_wrt), .f_trg(f_wrt));

RTMQ_MainMem
  MMEM(.clk(clk), .adr_a(if_adr), .dat_a(if_ins), .en_a(f_ftc),
       .adr_b(adr_dat), .dat_b(mem_dat), .din_b(d_wrt), .we_b(f_wrt));

//RTMQ_Mem
//  MMEM(.addra(if_adr),  .clka(clk), .dina(32'h0), .douta(if_ins), .ena(f_ftc), .wea(1'b0),
//       .addrb(adr_dat), .clkb(clk), .dinb(d_wrt), .doutb(mem_dat), .web(f_wrt));

// ------ Return Address Stack ------

wire [W_REG-1 : 0] ret_stk;
RTMQ_Stack #(.ADDR(R_RTS), .N_DPT(N_RTS))
  SRET(.clk(clk), .alu_out(alu_out), .stk_out(ret_stk));

// ------ Data Stack ------

wire [W_REG-1 : 0] dat_stk;
RTMQ_Stack_BRAM #(.ADDR(R_STK), .N_DPT(N_STK))
  SDAT(.clk(clk), .alu_out(alu_out), .stk_out(dat_stk));

// ------ UART Interface ------

// RTMQ_UART
//   UART(.clk(clk), .alu_out(alu_out), .cfg_ins(cfg_ins), .f_cfg(f_cfg), .uart_rx(uart_rx), .uart_tx(uart_tx));

// RTMQ_USBInterface
//   UART(.clk(clk), .alu_out(alu_out), .cfg_ins(cfg_ins), .f_cfg(f_cfg),
//        .usb_dat(usb_dat), .usb_rxf(usb_rxf),
//        .usb_txe(usb_txe), .usb_rdn(usb_rdn), .usb_wrn(usb_wrn));

// ------ Multiplier ------

wire [W_REG-1 : 0] reg_mul;
wire [W_REG-1 : 0] reg_muh;
wire [W_REG-1 : 0] d_opa;
wire [W_REG-1 : 0] d_opb;

RTMQ_GPRegister #(.ADDR(R_MUL))
  ROPA(.clk(clk), .alu_out(alu_out), .reg_out(d_opa), .f_trg());

RTMQ_GPRegister #(.ADDR(R_MUH))
  ROPB(.clk(clk), .alu_out(alu_out), .reg_out(d_opb), .f_trg());

RTMQ_Multiplier
  MULT(.CLK(clk), .A(d_opa), .B(d_opb), .P({reg_muh, reg_mul}));

// ------ General Purpose Registers ------

wire [N_GPR*W_REG-1 : 0] gpr_bus_out;

genvar i;
generate
for (i = 0; i < N_GPR; i = i + 1)
begin: GPRS
  
  RTMQ_GPRegister #(.ADDR(R_GPR + i))
    iGPR(.clk(clk), .alu_out(alu_out), .reg_out(gpr_bus_out[W_REG*(i+1)-1 : W_REG*i]), .f_trg());

end
endgenerate

// ------ LED ------

wire [W_REG-1 : 0] reg_led;
// assign LED = {reg_led[6:0], locked};

RTMQ_GPRegister #(.ADDR(R_LED))
  RLED(.clk(clk), .alu_out(alu_out), .reg_out(reg_led), .f_trg());

// ------ TTL ------

wire [W_REG-1 : 0] reg_ttl;
// reg  [15      : 0] reg_ttl_iob = 0;
// always @ (posedge clk) reg_ttl_iob <= reg_ttl[15:0];

// assign {IO_J20, IO_J21} = reg_ttl_iob;
// assign IO_SMA = reg_ttl[0];

RTMQ_GPRegister #(.ADDR(R_TTL))
  RTTL(.clk(clk), .alu_out(alu_out), .reg_out(reg_ttl), .f_trg());

// ------ SPI Master ------

wire [ 3 : 0] LMK_SPI;
wire [ 3 : 0] ROM_SPI;
wire [ 3 : 0] AT0_SPI;
wire [ 3 : 0] AT1_SPI;

wire csb;
wire sclk;
wire mosi;
wire miso;
wire spi_done;
wire [W_REG-1 : 0] reg_sdat;
wire [W_REG-1 : 0] reg_sctl;
wire [ 2      : 0] slv_adr;

DgLk_SPIMaster #(.R_SDA(R_SDAT), .R_SCT(R_SCTL))
  SPIM(.clk(clk), .alu_out(alu_out), .reg_sdat(reg_sdat), .reg_sctl(reg_sctl), .slv_adr(slv_adr),
       .f_spi_done(spi_done), .csb(csb), .sclk(sclk), .mosi(mosi), .miso(miso));

DgLk_SPIMultiplexer
  SMUX(.clk(clk), .slv_adr(slv_adr), .csb(csb), .sclk(sclk), .mosi(mosi), .miso(miso),
       .lmk(LMK_SPI), .rom(ROM_SPI), .atn0(AT0_SPI), .atn1(AT1_SPI),
       .i_hold(i_hold), .i_csb(i_csb), .i_sclk(i_sclk), .i_mosi(i_mosi));


// ------ DAC ------

// FuncMod_DAC #(R_AIO0)
//   FDA0(.clk(clk), .alu_out(alu_out), .smp(DA0_SMP), .dat(DA0_DAT));

// FuncMod_DAC #(R_AIO1)
//   FDA1(.clk(clk), .alu_out(alu_out), .smp(DA1_SMP), .dat(DA1_DAT));

// ------ ADC ------

wire [W_REG-1 : 0] reg_aio0;
wire [W_REG-1 : 0] reg_aio1;

// FuncMod_ADC FAD0(.clk(clk), .reg_aio(reg_aio0), .adc_smp(AD0_SMP), .adc_in(AD0_DAT));
// FuncMod_ADC FAD1(.clk(clk), .reg_aio(reg_aio1), .adc_smp(AD1_SMP), .adc_in(AD1_DAT));

wire [W_REG-1 : 0] reg_cadc;
// assign {AD1_CFG, AD0_CFG} = reg_cadc[7:0];

RTMQ_GPRegister #(.ADDR(R_CADC))
  CADC(.clk(clk), .alu_out(alu_out), .reg_out(reg_cadc), .f_trg());

// ------ DDS ------

wire DS0_MARST, DS0_IORST, DS0_IOUPD;
wire DS0_SYNCLK;
wire DS0_OSK;
wire [ 3 : 0] DS0_SPI;
wire [ 2 : 0] DS0_PROF;
wire DS0_TXEN;
wire DS0_PDCLK;
wire [ 1 : 0] DS0_F;
wire [15 : 0] DS0_PD;
wire DS1_MARST, DS1_IORST, DS1_IOUPD;
wire DS1_SYNCLK;
wire DS1_OSK;
wire [ 3 : 0] DS1_SPI;
wire [ 2 : 0] DS1_PROF;
wire DS1_TXEN;
wire DS1_PDCLK;
wire [ 1 : 0] DS1_F;
wire [15 : 0] DS1_PD;



wire [W_REG-1 : 0] reg_cdds;
RTMQ_GPRegister #(.ADDR(R_CDDS))
  CDDS(.clk(clk), .alu_out(alu_out), .reg_out(reg_cdds), .f_trg());

wire [W_REG-1 : 0] reg_cpbk;
RTMQ_GPRegister #(.ADDR(R_CPBK))
  CPBK(.clk(clk), .alu_out(alu_out), .reg_out(reg_cpbk), .f_trg());

wire [W_REG-1 : 0] reg_sda0;
wire [W_REG-1 : 0] reg_sct0;
wire ds0_spi_done;
DgLk_SPIMaster #(.R_SDA(R_SDA0), .R_SCT(R_SCT0))
  SDS0(.clk(clk), .alu_out(alu_out), .reg_sdat(reg_sda0), .reg_sctl(reg_sct0), .slv_adr(),
       .f_spi_done(ds0_spi_done), .csb(DS0_SPI[0]), .sclk(DS0_SPI[1]), .mosi(DS0_SPI[2]), .miso(DS0_SPI[3]));

wire [W_REG-1 : 0] reg_sda1;
wire [W_REG-1 : 0] reg_sct1;
wire ds1_spi_done;
DgLk_SPIMaster #(.R_SDA(R_SDA1), .R_SCT(R_SCT1))
  SDS1(.clk(clk), .alu_out(alu_out), .reg_sdat(reg_sda1), .reg_sctl(reg_sct1), .slv_adr(),
       .f_spi_done(ds1_spi_done), .csb(DS1_SPI[0]), .sclk(DS1_SPI[1]), .mosi(DS1_SPI[2]), .miso(DS1_SPI[3]));

wire [W_REG-1 : 0] reg_cmn0;
wire [12      : 0] d_cds0 = {reg_cpbk[21:20], reg_cpbk[2:0], reg_cdds[22:20], reg_cdds[4:0]};
FuncMod_AD9910 #(.R_PBK(R_PBK0), .R_TUN(R_TUN0), .R_DBG(R_CMN0))
  FDS0(.clk(clk), .alu_out(alu_out), .reg_cmn(reg_cmn0), .cdds(d_cds0),
       .syn_clk(DS0_SYNCLK), .pda_clk(DS0_PDCLK), .prof(DS0_PROF), .io_upd(DS0_IOUPD),
       .io_rst(DS0_IORST), .m_rst(DS0_MARST), .tx_en(DS0_TXEN), .pdat(DS0_PD), .pf(DS0_F));

wire [W_REG-1 : 0] reg_cmn1;
wire [12      : 0] d_cds1 = {reg_cpbk[24:23], reg_cpbk[7:5], reg_cdds[25:23], reg_cdds[9:5]};
FuncMod_AD9910 #(.R_PBK(R_PBK1), .R_TUN(R_TUN1), .R_DBG(R_CMN1))
  FDS1(.clk(clk), .alu_out(alu_out), .reg_cmn(reg_cmn1), .cdds(d_cds1),
       .syn_clk(DS1_SYNCLK), .pda_clk(DS1_PDCLK), .prof(DS1_PROF), .io_upd(DS1_IOUPD),
       .io_rst(DS1_IORST), .m_rst(DS1_MARST), .tx_en(DS1_TXEN), .pdat(DS1_PD), .pf(DS1_F));

// ------ Gated Counter Array ------

wire [ 7 : 0] IO_J20;

wire [N_CTR*W_REG-1 : 0] reg_ctr;
RTMQ_GatedCounterArray
  GCTA(.clk(clk), .alu_out(alu_out), .pulse(IO_J20), .reg_ctr(reg_ctr));

// ------ Trigger Manager ------

wire [W_REG-1 : 0] trg_chn;
wire               f_trig;
RTMQ_TrigMgr
  TRIG(.clk(clk), .alu_out(alu_out), .trg_chn(trg_chn), .f_hld(f_hld), .f_trig(f_trig));

assign trg_chn = 0;

// ------ DUT: ExtUART ------

wire [ 7 : 0] IO_J21;
wire [ 7 : 0] IO_J22;

wire [W_REG-1 : 0] reg_exu;
wire               exu_rxdn;
wire               exu_txdn;

RTMQ_ExtUART #(.ADDR_DAT(R_DUTI), .ADDR_CFG(R_DUTC))
  UART2(.clk(clk), .alu_out(alu_out), .reg_exu(reg_exu),
        .f_exu_rxdn(exu_rxdn), .f_exu_txdn(exu_txdn),
        .exu_rx(IO_J21), .exu_tx(IO_J22));

//---------------------------



// ------ Conclude: RegFile ------

wire [W_REG-1 : 0] nil = 0;
assign regfile = {
  reg_cpbk,
  reg_cdds,
  reg_ctr,
  reg_cmn1,
  reg_cmn0,
  reg_sct1,
  reg_sda1,
  reg_sct0,
  reg_sda0,
  reg_cadc,
  reg_aio1,
  reg_aio0,
  reg_ttl,
  reg_sctl,
  reg_sdat,
  reg_led,
  gpr_bus_out,
  nil,      // DUT
  reg_exu,  // DUT
  nil,
  reg_muh,
  reg_mul,
  cfg_ins,
  dat_stk,
  ret_stk,
  mem_dat,
  adr_dat,
  {N_ACR{nil}}
};

// ------ Conclude: RESUME ------

assign f_rsm = master_rsm;

endmodule
