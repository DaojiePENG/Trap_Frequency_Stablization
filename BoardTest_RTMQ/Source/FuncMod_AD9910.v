module FuncMod_AD9910(clk, alu_out, reg_cmn,
                      cdds, syn_clk, pda_clk,
                      prof, io_upd, io_rst, m_rst, tx_en, pdat, pf);
/*
功能：由cdds控制信号决定芯片
工作的Profile、输入输出的更新io_upd、重置io_rst、主机的重置m_rst、传输使能tx_en、并行数据及其目标的输出；
*/
parameter R_PBK = 0;
parameter R_TUN = 0;
parameter R_DBG = 0;

`include "RTMQ_Peripheral.v"

input  clk;                            // System clock
input  [W_ALU-1 : 0] alu_out;          // ALU output bus
output [W_REG-1 : 0] reg_cmn;          // Clock phase monitor
input  [12      : 0] cdds;             // DDS control signals
input                syn_clk;          // SYNC_CLK
input                pda_clk;          // PDCLK
output [ 2      : 0] prof;             // Profile
output               io_upd;           // I/O update
output               io_rst;           // I/O reset
output               m_rst;            // Master reset
output               tx_en;            // Tx enable
output [W_PBK-1 : 0] pdat;             // Parallel data
output [ 1      : 0] pf;               // Parallel data destination

wire [ 7 : 0] w_dds_ctl;               // {io_rst[7], m_rst[6], io_upd[5], prof[4:2], pf[1:0]}
wire [ 3 : 0] w_pbk_ctl;               // {p_ena, tun_upd, r_rst, w_rst}
wire          w_txen;
assign {w_txen, w_pbk_ctl, w_dds_ctl} = cdds;

wire [W_PBK-1 : 0] pbk_out;
DgLk_Playback #(.R_PBK(R_PBK), .R_TUN(R_TUN))
  PLBK(.clk(clk), .alu_out(alu_out), .ctrl(w_pbk_ctl), .pbk_out(pbk_out));

// Pipeline delay: 10, determined by manual calibration
//   such that switching between DDS & AWG modes is smooth
RTMQ_MultiReg #(.W_BUS(7), .N_STG(10))
  PPLN(.clk(clk), .inp({w_txen, w_dds_ctl[5:0]}), 
       .out({tx_en, io_upd, prof, pf}));

reg  [W_PBK-1 : 0] pdat = 0;
reg  io_rst = 0;
reg  m_rst = 0;
always @ (posedge clk) pdat <= pbk_out;
always @ (posedge clk) io_rst <= w_dds_ctl[7];
always @ (posedge clk) m_rst <= w_dds_ctl[6];

// ------ DEBUG: Clock Monitor ------

wire f_rst;
RTMQ_AcsFlg #(.ADDR(R_DBG))
  FACS(.clk(clk), .alu_out(alu_out), .f_read(), .f_wrt_alu(),
       .f_wrt_ihi(), .f_wrt_ilo(f_rst));

Dbg_ClkMon #(.W_CNT(16))
  CMON(.clk(clk), .rst(f_rst), .in_syn(syn_clk), .in_pdc(pda_clk), .cnt(reg_cmn));

endmodule
