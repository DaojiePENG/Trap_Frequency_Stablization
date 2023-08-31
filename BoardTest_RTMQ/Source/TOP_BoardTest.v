module TOP_BoardTest(

// Primary
    XCLK, SYSCLK_P, SYSCLK_N, SW,
    LED, IO_SMA,
    LMK_SPI, ROM_SPI,

// FT2232H
    FT_ST, FT_AD, FT_AC, FT_BD, FT_BC,

// DDS
    AT0_SPI, AT1_SPI,

    DS0_MARST, DS0_IORST, DS0_IOUPD,
    DS0_SYNCLK, DS0_OSK, DS0_SPI, DS0_PROF,
    DS0_TXEN, DS0_PDCLK, DS0_F, DS0_PD,

    DS1_MARST, DS1_IORST, DS1_IOUPD,
    DS1_SYNCLK, DS1_OSK, DS1_SPI, DS1_PROF, 
    DS1_TXEN, DS1_PDCLK, DS1_F, DS1_PD,

// DAC
    DA0_SMP, DA0_DAT, DA1_SMP, DA1_DAT,

// ADC
    DPOT_SPI,
    AD0_SMP, AD0_OFL, AD0_CFG, AD0_DAT,
    AD1_SMP, AD1_OFL, AD1_CFG, AD1_DAT,

// GPIO
    IO_TR, IO_OE, IO_J15, IO_J16, IO_J17, IO_J18, IO_J20,
    IO_J21, IO_J22  // DUT
);

// ------ I/O Definition ----------

// Primary
input  XCLK, SYSCLK_P, SYSCLK_N, SW;
(* IOB = "TRUE" *) input  IO_SMA;
                   output [ 7 : 0] LED;
(* IOB = "TRUE" *) inout  [ 3 : 0] LMK_SPI;
(* IOB = "TRUE" *) inout  [ 3 : 0] ROM_SPI;

// FT2232H
                   input  FT_ST;
                   inout  [ 7 : 0] FT_AD;
                   inout  [ 7 : 0] FT_AC;
                   inout  [ 7 : 0] FT_BD;
                   inout  [ 7 : 0] FT_BC;

// DDS
                   inout  [ 3 : 0] AT0_SPI;
                   inout  [ 3 : 0] AT1_SPI;
(* IOB = "TRUE" *) output DS0_MARST, DS0_IORST, DS0_IOUPD;
(* IOB = "TRUE" *) input  DS0_SYNCLK;
                   output DS0_OSK;
(* IOB = "TRUE" *) inout  [ 3 : 0] DS0_SPI;
(* IOB = "TRUE" *) output [ 2 : 0] DS0_PROF;
(* IOB = "TRUE" *) output DS0_TXEN;
(* IOB = "TRUE" *) input  DS0_PDCLK;
(* IOB = "TRUE" *) output [ 1 : 0] DS0_F;
(* IOB = "TRUE" *) output [15 : 0] DS0_PD;
(* IOB = "TRUE" *) output DS1_MARST, DS1_IORST, DS1_IOUPD;
(* IOB = "TRUE" *) input  DS1_SYNCLK;
                   output DS1_OSK;
(* IOB = "TRUE" *) inout  [ 3 : 0] DS1_SPI;
(* IOB = "TRUE" *) output [ 2 : 0] DS1_PROF;
(* IOB = "TRUE" *) output DS1_TXEN;
(* IOB = "TRUE" *) input  DS1_PDCLK;
(* IOB = "TRUE" *) output [ 1 : 0] DS1_F;
(* IOB = "TRUE" *) output [15 : 0] DS1_PD;

// DAC
(* IOB = "TRUE" *) output DA0_SMP;
(* IOB = "TRUE" *) output [15 : 0] DA0_DAT;
(* IOB = "TRUE" *) output DA1_SMP;
(* IOB = "TRUE" *) output [15 : 0] DA1_DAT;

// ADC
                   output [ 2 : 0] DPOT_SPI;
                   input  AD0_SMP, AD0_OFL;
(* IOB = "TRUE" *) output [ 3 : 0] AD0_CFG;
(* IOB = "TRUE" *) input  [15 : 0] AD0_DAT;
                   input  AD1_SMP, AD1_OFL;
(* IOB = "TRUE" *) output [ 3 : 0] AD1_CFG;
(* IOB = "TRUE" *) input  [15 : 0] AD1_DAT;

// GPIO
                   output [ 5 : 0] IO_TR;
                   output [ 5 : 0] IO_OE;
(* IOB = "TRUE" *) output [ 7 : 0] IO_J15;
(* IOB = "TRUE" *) output [ 7 : 0] IO_J16;
(* IOB = "TRUE" *) output [ 7 : 0] IO_J17;
(* IOB = "TRUE" *) output [ 7 : 0] IO_J18;
(* IOB = "TRUE" *) input  [ 7 : 0] IO_J20;

(* IOB = "TRUE" *) input  [ 7 : 0] IO_J21;  // DUT
(* IOB = "TRUE" *) output [ 7 : 0] IO_J22;  // DUT


// ------ Configuration ----------

`include "RTMQ_Peripheral.v"

// ------ I/O Assignment ----------

// Primary

// FT2232H
// wire [7 : 0] usb_dat = FT_AD;
// wire usb_rxf = FT_AC[0];
// wire usb_txe = FT_AC[1];
// wire usb_rdn;
// wire usb_wrn;
// assign FT_AC[2] = usb_rdn;
// assign FT_AC[3] = usb_wrn;

wire uart_rx = FT_AD[0];
wire uart_tx;
assign FT_AD[1] = uart_tx;

assign FT_BD = 8'bz;
assign FT_BC = 8'bz;

// GPIO
assign IO_TR = 6'b011111; // {J20, J19, ... , J15}, 1 for output, 0 for input.
assign IO_OE = 6'b000000;

// ------ LMK Initialization ----------

wire i_hold;
wire i_csb;
wire i_sclk;
wire i_mosi;
DgLk_ClkInit #(.AdrWid(8), .ScrLen(130), .IniScr("C:/FPGA_Lib/20230416_DigiLock/BoardTest_RTMQ/ROM_Init.txt"))
  CINI(.clk(XCLK), .hold(i_hold), .csb(i_csb), .sclk(i_sclk), .mosi(i_mosi));

// ------ Clock Generation ----------

wire clk, clk_50, clk_45, clk_35, clk_25;
wire locked;
DgLk_RefClk REFC(.clk_in1_p(SYSCLK_P), .clk_in1_n(SYSCLK_N),
                 .rclk(clk), .clk_50(clk_50), .clk_45(clk_45), .clk_35(clk_35), .clk_25(clk_25), .reset(i_hold), .locked(locked));
//DgLk_RefClk REFC(.clk_in1(XCLK),
//                 .rclk(clk), .reset(i_hold), .locked(locked));

// ------ Core ------

wire [W_ALU-1 : 0] alu_out;
wire [W_BUS-1 : 0] regfile;
wire [W_REG-1 : 0] if_adr;
wire [W_REG-1 : 0] if_ins;
wire               f_ftc;
wire               f_rsm;
wire               f_hld;
wire               f_cfg;
wire [W_REG-1 : 0] cfg_ins;
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

wire uart_tx_done;
RTMQ_UART
  UART(.clk(clk), .alu_out(alu_out),
       .cfg_ins(cfg_ins), .f_cfg(f_cfg), .f_tx_done(uart_tx_done),
       .uart_rx(uart_rx), .uart_tx(uart_tx));

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

// --- 64bit Combined Tausworthe Generator ---

wire [W_REG-1 : 0] reg_rnd;
RTMQ_RandGen
  RAND(.clk(clk), .reg_rnd(reg_rnd));

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
assign LED = {reg_led[6:0], locked};
RTMQ_GPRegister #(.ADDR(R_LED))
  RLED(.clk(clk), .alu_out(alu_out), .reg_out(reg_led), .f_trg());

// ------ TTL ------

wire               ttl_upd;
wire [W_REG-1 : 0] reg_ttl;
reg  [W_REG-1 : 0] reg_ttl_ppl = 0;
reg  [W_REG-1 : 0] reg_ttl_iob = 0;
always @ (posedge clk) if (ttl_upd) reg_ttl_ppl <= reg_ttl;
always @ (posedge clk) reg_ttl_iob <= reg_ttl_ppl;

assign {IO_J18, IO_J17, IO_J16, IO_J15} = reg_ttl_iob;

RTMQ_GPRegister #(.ADDR(R_TTL))
  RTTL(.clk(clk), .alu_out(alu_out), .reg_out(reg_ttl), .f_trg(ttl_upd));

// ------ SPI Master ------

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

//FuncMod_DAC #(R_AIO0)
  //FDA0(.clk(clk), .alu_out(alu_out), .smp(DA0_SMP), .dat(DA0_DAT));
  //FDA0(.clk(clk), .alu_out(alu_out), .smp(), .dat());

//FuncMod_DAC #(R_AIO1) // 2023年7月13日22:08:51，用于保持输出数，无意义
  //FDA1(.clk(clk), .alu_out(alu_out), .smp(DA1_SMP), .dat(DA1_DAT));

// ------ ADC ------

wire [W_REG-1 : 0] reg_aio0;
wire [W_REG-1 : 0] reg_aio1;
FuncMod_ADC FAD0(.clk(clk), .reg_aio(reg_aio0), .adc_smp(AD0_SMP), .adc_in(AD0_DAT));
FuncMod_ADC FAD1(.clk(clk), .reg_aio(reg_aio1), .adc_smp(AD1_SMP), .adc_in(AD1_DAT));

wire [W_REG-1 : 0] reg_cadc;
assign {AD1_CFG, AD0_CFG} = reg_cadc[7:0];
RTMQ_GPRegister #(.ADDR(R_CADC))
  CADC(.clk(clk), .alu_out(alu_out), .reg_out(reg_cadc), .f_trg());

// ------ DDS ------
/*
|==================================================== reg_cdds[31:0] ==========================================================|
[31:24]| ------------ | ------------ | ------------ | ------------ | ------------ | ------------ | ---io_rst1-- | ---m_rst1--- |
[23:16]| ---update1-- | ---io_rst0-- | ---m_rst0--- | --update0--- | ----------------------shift_n1(4)------------------------ |
[15:8 ]| ----------------------shift_n0(4)------------------------ | ------------ | ------------ | -------profile sel(3)------ |
[7 :0 ]| profile1 sel | ------parallel dest1------- | -------------profile sel(3)--------------- | ------parallel dest0------- |
*/
wire [W_REG-1 : 0] reg_cdds;// DDS的控制字
RTMQ_GPRegister #(.ADDR(R_CDDS))
  CDDS(.clk(clk), .alu_out(alu_out), .reg_out(reg_cdds), .f_trg());
/*
|==================================================== reg_cpbk[31:0] ==========================================================|
[31:24]| ------------ | ------------ | ------------ | ------------ | ------------ | ------------ | ------------ | ----tx_en1-- |
[23:16]| ---p_ena1--- | ------------ | ----tx_en0-- | ---p_ena0--- | ------------ | ------------ | ------------ | ------------ |
[15:8 ]| ------------ | ------------ | ------------ | ------------ | ------------ | ------------ | ------------ | ------------ |
[7 :0 ]| --tun_upd1-- | ---r_rst1--- | ---w_rst1--- | ------------ | ------------ | --tun_upd0-- | ---r_rst0--- | ---w_rst0--- |
*/
wire [W_REG-1 : 0] reg_cpbk;
RTMQ_GPRegister #(.ADDR(R_CPBK))
  CPBK(.clk(clk), .alu_out(alu_out), .reg_out(reg_cpbk), .f_trg());

wire [W_REG-1 : 0] reg_sda0;
wire [W_REG-1 : 0] reg_sct0;
wire ds0_spi_done;
DgLk_SPIMaster #(.R_SDA(R_SDA0), .R_SCT(R_SCT0))
// 与 DDS0 的SPI通信接口
  SDS0(.clk(clk), .alu_out(alu_out), .reg_sdat(reg_sda0), .reg_sctl(reg_sct0), .slv_adr(),
       .f_spi_done(ds0_spi_done), .csb(DS0_SPI[0]), .sclk(DS0_SPI[1]), .mosi(DS0_SPI[2]), .miso(DS0_SPI[3]));

wire [W_REG-1 : 0] reg_sda1;
wire [W_REG-1 : 0] reg_sct1;
wire ds1_spi_done;
DgLk_SPIMaster #(.R_SDA(R_SDA1), .R_SCT(R_SCT1))
// 与 DDS1 的SPI通信接口。reg_sct1选择了从机的地址，也包括了DDS芯片内部的通信地址控制
  SDS1(.clk(clk), .alu_out(alu_out), .reg_sdat(reg_sda1), .reg_sctl(reg_sct1), .slv_adr(),
       .f_spi_done(ds1_spi_done), .csb(DS1_SPI[0]), .sclk(DS1_SPI[1]), .mosi(DS1_SPI[2]), .miso(DS1_SPI[3]));

wire [W_REG-1 : 0] reg_cmn0;
wire [12      : 0] d_cds0 = {reg_cpbk[21:20], reg_cpbk[2:0], reg_cdds[22:20], reg_cdds[4:0]};
FuncMod_AD9910 #(.R_PBK(R_PBK0), .R_TUN(R_TUN0), .R_DBG(R_CMN0))
/*功能：控制DDS的工作模式、重启、数据更新等*/
  FDS0(.clk(clk), .alu_out(alu_out), .reg_cmn(reg_cmn0), .cdds(d_cds0),
       .syn_clk(DS0_SYNCLK), .pda_clk(DS0_PDCLK), .prof(DS0_PROF), .io_upd(DS0_IOUPD),
       .io_rst(DS0_IORST), .m_rst(DS0_MARST), .tx_en(DS0_TXEN), .pdat(), .pf(DS0_F));

wire [W_REG-1 : 0] reg_cmn1;
wire [12      : 0] d_cds1 = {reg_cpbk[24:23], reg_cpbk[7:5], reg_cdds[25:23], reg_cdds[9:5]};
FuncMod_AD9910 #(.R_PBK(R_PBK1), .R_TUN(R_TUN1), .R_DBG(R_CMN1))
  FDS1(.clk(clk), .alu_out(alu_out), .reg_cmn(reg_cmn1), .cdds(d_cds1),
       .syn_clk(DS1_SYNCLK), .pda_clk(DS1_PDCLK), .prof(DS1_PROF), .io_upd(DS1_IOUPD),
       .io_rst(DS1_IORST), .m_rst(DS1_MARST), .tx_en(DS1_TXEN), .pdat(), .pf(DS1_F));


// ---------------pid0--------------
assign i_rstn=~DS0_IOUPD; // PID复位信号，由DDS更新信号同步提供

wire [W_REG-1 : 0] reg_pid0_k0, reg_pid0_k1, reg_pid0_k2, reg_pid0_ref, reg_pid0_out, reg_pid0_out_bais;// PID input
RTMQ_GPRegister #(.ADDR(R_PID00))// 
  PID0_InputReg0(.clk(clk), .alu_out(alu_out), .reg_out(reg_pid0_k0), .f_trg());
RTMQ_GPRegister #(.ADDR(R_PID01))// 
  PID0_InputReg1(.clk(clk), .alu_out(alu_out), .reg_out(reg_pid0_k1), .f_trg());
RTMQ_GPRegister #(.ADDR(R_PID02))// 
  PID0_InputReg2(.clk(clk), .alu_out(alu_out), .reg_out(reg_pid0_k2), .f_trg());
RTMQ_GPRegister #(.ADDR(R_PID0r))// 
  PID0_InputRegr(.clk(clk), .alu_out(alu_out), .reg_out(reg_pid0_ref), .f_trg());
RTMQ_GPRegister #(.ADDR(R_PID0O))// 
  PID0_OutputRegr(.clk(clk), .alu_out(alu_out), .reg_out(reg_pid0_out_bais), .f_trg());

wire [W_REG-1 : 0] reg_pid0_min, reg_pid0_max;
RTMQ_GPRegister #(.ADDR(R_PIDMin0))// 
  PID0_OutputMin0 (.clk(clk), .alu_out(alu_out), .reg_out(reg_pid0_min), .f_trg());
RTMQ_GPRegister #(.ADDR(R_PIDMax0))// 
  PID0_OutputMax0 (.clk(clk), .alu_out(alu_out), .reg_out(reg_pid0_max), .f_trg());


reg [15:0] reg_aio0_out;// 将AD输出转化为有符号数范围
always @ (posedge clk)
    begin
        reg_aio0_out<=(reg_aio0[15:0]-0'h8000);
    end

wire [31:0] filter0_out;
wire [31:0] reg_filter0_a;
RTMQ_GPRegister #(.ADDR(R_SETA0))// 设置滤波器a参数寄存器
  Filter0_set_reg(.clk(clk), .alu_out(alu_out), .reg_out(reg_filter0_a), .f_trg());
FOL_Filter16 #(.n(15)) filter0 (
//将ADC输出通过有限长滤波器后再给PID
      .i_clkp       (clk              ), 
      .i_rstn       (i_rstn           ), 
      .i_a0         (reg_filter0_a[15:0]),
      .i_filter     (reg_aio0_out     ), 
      .o_filter     (filter0_out      )
   );

wire [3:0] shift_n0=reg_cdds[15:12];//先提供16位可移动吧，现成的寄存器不用添加了
PID_16 #(.Width(16),.Shift(5),.Stage(1)) PID0(
  .i_clkp(clk),.i_rstn(i_rstn),
  .i_rt(reg_pid0_ref[15:0]),.i_yt(filter0_out[15:0]),
  .i_k0(reg_pid0_k0[15:0]),.i_k1(reg_pid0_k1[15:0]),.i_k2(reg_pid0_k2[15:0]),
  .i_shift({1'b0,shift_n0}), .i_min(reg_pid0_min), .i_max(reg_pid0_max),
  .o_ut(reg_pid0_out));

wire [31:0] reg_pid0_out_rwire;
pipelineto #(.Width(32),.Stage(1)) ppl_uut0(
  .i_clkp(clk),.i_rstn(i_rstn),
  .i_a(reg_pid0_out),
  .o_a(reg_pid0_out_rwire));

wire [31:0] u_reg_pid0_out;// 以无符号数的形式进入DDS
Full_Ahead_2Adder #(.Width(32),.Stage(1)) adder_pid2dds0(// 为PID的输出添加偏置
    .i_clkp         (clk         ),
    .i_rstn         (i_rstn         ),
    .i_c            (1'b0           ),// sign(1) + data(15)
    .i_a            (reg_pid0_out_rwire),
    .i_b            (reg_pid0_out_bais),
    .o_d            (u_reg_pid0_out),
    .o_c            (),
    .o_gm           (),
    .o_pm           ()
    );
wire [31:0] u_reg_pid0_out_rwire;
pipelineto #(.Width(32),.Stage(1)) ppl_to_dds0(
  .i_clkp(clk),.i_rstn(i_rstn),
  .i_a(u_reg_pid0_out),
  .o_a(u_reg_pid0_out_rwire));// 将加法结果的低16位直接赋给DDS并行调制（要求偏置为正偏执如32768）
assign DS0_PD=u_reg_pid0_out_rwire[15:0]; // PID 输出的低16位接DDS0的并行输入；
assign DA0_SMP=clk_25; // DA25MHz 刷新率
assign DA0_DAT=reg_aio0[15:0];
assign DA1_DAT=u_reg_pid0_out_rwire[31:16];
// ---------------pid1--------------
wire [W_REG-1 : 0] reg_pid1_k0, reg_pid1_k1, reg_pid1_k2, reg_pid1_ref, reg_pid1_out;// PID input
RTMQ_GPRegister #(.ADDR(R_PID10))// 
  PID1_InputReg0(.clk(clk), .alu_out(alu_out), .reg_out(reg_pid1_k0), .f_trg());
RTMQ_GPRegister #(.ADDR(R_PID11))// 
  PID1_InputReg1(.clk(clk), .alu_out(alu_out), .reg_out(reg_pid1_k1), .f_trg());
RTMQ_GPRegister #(.ADDR(R_PID12))// 
  PID1_InputReg2(.clk(clk), .alu_out(alu_out), .reg_out(reg_pid1_k2), .f_trg());
RTMQ_GPRegister #(.ADDR(R_PID1r))// 
  PID1_InputRegr(.clk(clk), .alu_out(alu_out), .reg_out(reg_pid1_ref), .f_trg());

reg [15:0] reg_aio1_out;// 将AD输出转化为有符号数范围
always @ (posedge clk)
    begin
        reg_aio1_out<=(reg_aio1[15:0]-0'h8000);
    end

wire [31:0] filter1_out;
wire [31:0] reg_filter1_a;
RTMQ_GPRegister #(.ADDR(R_SETA1))// 设置滤波器a参数寄存器
  Filter1_set_reg(.clk(clk), .alu_out(alu_out), .reg_out(reg_filter1_a), .f_trg());


wire [31:0] reg_iir_a0, reg_iir_a1,reg_iir_a2, reg_iir_a3, reg_iir_b0, reg_iir_b1,reg_iir_b2, reg_iir_b3, reg_pid1_out_bais;
RTMQ_GPRegister #(.ADDR(R_IIRA0))// 设置滤波器a参数寄存器
  IIR_Filter1_set_rega0(.clk(clk), .alu_out(alu_out), .reg_out(reg_iir_a0), .f_trg());
RTMQ_GPRegister #(.ADDR(R_IIRA1))// 设置滤波器a参数寄存器
  IIR_Filter1_set_rega1(.clk(clk), .alu_out(alu_out), .reg_out(reg_iir_a1), .f_trg());
RTMQ_GPRegister #(.ADDR(R_IIRA2))// 设置滤波器a参数寄存器
  IIR_Filter1_set_rega2(.clk(clk), .alu_out(alu_out), .reg_out(reg_iir_a2), .f_trg());
RTMQ_GPRegister #(.ADDR(R_IIRA3))// 设置滤波器a参数寄存器
  IIR_Filter1_set_rega3(.clk(clk), .alu_out(alu_out), .reg_out(reg_iir_a3), .f_trg());
RTMQ_GPRegister #(.ADDR(R_IIRB0))// 设置滤波器b参数寄存器
  IIR_Filter1_set_regb0(.clk(clk), .alu_out(alu_out), .reg_out(reg_iir_b0), .f_trg());
RTMQ_GPRegister #(.ADDR(R_IIRB1))// 设置滤波器b参数寄存器
  IIR_Filter1_set_regb1(.clk(clk), .alu_out(alu_out), .reg_out(reg_iir_b1), .f_trg());
RTMQ_GPRegister #(.ADDR(R_IIRB2))// 设置滤波器b参数寄存器
  IIR_Filter1_set_regb2(.clk(clk), .alu_out(alu_out), .reg_out(reg_iir_b2), .f_trg());
RTMQ_GPRegister #(.ADDR(R_IIRB3))// 设置滤波器b参数寄存器
  IIR_Filter1_set_regb3(.clk(clk), .alu_out(alu_out), .reg_out(reg_iir_b3), .f_trg());
RTMQ_GPRegister #(.ADDR(R_PID1O))// 
  PID1_OutputRegr(.clk(clk), .alu_out(alu_out), .reg_out(reg_pid1_out_bais), .f_trg());

wire [W_REG-1 : 0] reg_pid1_min, reg_pid1_max;
RTMQ_GPRegister #(.ADDR(R_PIDMin1))// 
  PID0_OutputMin1(.clk(clk), .alu_out(alu_out), .reg_out(reg_pid1_min), .f_trg());
RTMQ_GPRegister #(.ADDR(R_PIDMax1))// 
  PID0_OutputMax1(.clk(clk), .alu_out(alu_out), .reg_out(reg_pid1_max), .f_trg());



wire [32*4-1:0] factor_a_wire={reg_iir_a3,reg_iir_a2,reg_iir_a1,reg_iir_a0};
wire [32*4-1:0] factor_b_wire={reg_iir_b3,reg_iir_b2,reg_iir_b1,reg_iir_b0};
wire [32*4-1:0] factor_a_rwire, factor_b_rwire;
pipelineto #(.Width(32*8),.Stage(1)) lineto_factor(// 用慢钟对快钟的结果进行一级缓存
  .i_clkp(clk_25), .i_rstn(i_rstn),
  .i_a({factor_a_wire, factor_b_wire}),
  .o_a({factor_a_rwire, factor_b_rwire})
  );
IIR_Filter32 #(.N_order(4), .N_scale(24), .Width(32), .Stage(0)) filter1 (
//将ADC输出通过有限长滤波器后再给PID
      .i_clkp         (clk_25             ), // 滤波器工作频率降低到25MHz
      .i_rstn         (i_rstn             ), 
      .i_factor_a     (factor_a_rwire     ),
      .i_factor_b     (factor_b_rwire     ),
      .i_filter       ({{16{reg_aio1_out[15]}},reg_aio1_out}), 
      .o_filter       (filter1_out        ) 
   );
wire [15:0] filter1_out_rwire;
pipelineto #(.Width(16),.Stage(1)) lineto_pid1(// 用快钟对慢钟的结果进行一级缓存
  .i_clkp(clk), .i_rstn(i_rstn),
  .i_a(filter1_out[15:0]),
  .o_a(filter1_out_rwire)
  );

wire [3:0] shift_n1=reg_cdds[15:12];
PID_16 #(.Width(16),.Shift(5),.Stage(1)) PID1(
  .i_clkp(clk),.i_rstn(i_rstn),
  .i_rt(reg_pid1_ref[15:0]),.i_yt(filter1_out_rwire),
  .i_k0(reg_pid1_k0[15:0]),.i_k1(reg_pid1_k1[15:0]),.i_k2(reg_pid1_k2[15:0]),
  .i_shift(shift_n1), .i_min(reg_pid1_min), .i_max(reg_pid1_max),

  .o_ut(reg_pid1_out));
wire [15:0] reg_pid1_out_rwire;
pipelineto #(.Width(16),.Stage(1)) ppl_uut1(
  .i_clkp(clk),.i_rstn(i_rstn),
  .i_a({reg_pid1_out[31],reg_pid1_out[14:0]}),
  .o_a(reg_pid1_out_rwire));

wire [15:0] u_reg_pid1_out;// 以无符号数的形式进入DDS
Full_Ahead_2Adder #(.Width(16),.Stage(1)) adder_pid2dds1(// 为PID的输出添加偏置
    .i_clkp         (clk         ),
    .i_rstn         (i_rstn         ),
    .i_c            (1'b0           ),// sign(1) + data(15)
    .i_a            (reg_pid1_out_rwire),
    .i_b            ({reg_pid1_out_bais[31],reg_pid1_out_bais[14:0]}),
    .o_d            (u_reg_pid1_out),
    .o_c            (),
    .o_gm           (),
    .o_pm           ()
    );

// assign DS1_PD=u_reg_pid1_out;
assign DS1_PD=u_reg_pid0_out_rwire; // 将PID0的输出同时赋给DDS1，// 调试用
// ------ Gated Counter Array ------

wire [N_CTR*W_REG-1 : 0] reg_ctr;
RTMQ_GatedCounterArray
  GCTA(.clk(clk), .alu_out(alu_out), .pulse(IO_J20), .reg_ctr(reg_ctr));

// ------ Trigger Manager ------

wire [W_REG-1 : 0] trg_chn;
wire               f_trig;
RTMQ_TrigMgr
  TRIG(.clk(clk), .alu_out(alu_out), .trg_chn(trg_chn), .f_hld(f_hld), .f_trig(f_trig));

assign trg_chn = {
  exu_txdn,
  exu_rxdn,
  ds1_spi_done,
  ds0_spi_done,
  spi_done,
  uart_tx_done,
  IO_SMA
};

// ------ DUT: ExtUART ------

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
  filter1_out,
  filter0_out,
  reg_pid1_out, // PID1输出
  reg_pid0_out, // PID0输出

  reg_pid1_max,
  reg_pid1_min,
  reg_pid0_max,
  reg_pid0_min,
  reg_pid1_out_bais,
  reg_pid0_out_bais,
  reg_iir_b3,
  reg_iir_b2,
  reg_iir_b1,
  reg_iir_b0,
  reg_iir_a3,
  reg_iir_a2,
  reg_iir_a1,
  reg_iir_a0,
  reg_filter1_a,     // fitler1 set
  reg_filter0_a,     // fitler0 set
  reg_pid1_ref,    // PID1参考
  reg_pid1_k2,
  reg_pid1_k1,
  reg_pid1_k0,
  reg_pid0_ref,    // PID0参考
  reg_pid0_k2,
  reg_pid0_k1,
  reg_pid0_k0,
  I_NOP,// R_TUN1
  I_NOP,// R_TUN0
  I_NOP,// R_PBK1
  I_NOP,// R_PBK0
  reg_cpbk,// R_CPBK
  reg_cdds,// R_CDDS
  I_NOP,// R_ETRG
  I_NOP,// R_ECTR
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
  reg_rnd,
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

assign f_rsm = f_trig;

endmodule
