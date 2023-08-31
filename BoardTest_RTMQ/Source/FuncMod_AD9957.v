module FuncMod_AD9957(clk, alu_out, reg_cmn,
                      cdds, syn_clk, pda_clk,
                      prof, io_upd, io_rst, m_rst, tx_en, pdat);

parameter ADDR = 0;
parameter ADDR_DBG = 0;

`include "RTMQ_Peripheral.v"

input  clk;                        // System clock
input  [W_ALU-1 : 0] alu_out;      // ALU output bus
output [W_REG-1 : 0] reg_cmn;      // Clock phase monitor
input  [ 9      : 0] cdds;         // DDS control signals
input                syn_clk;      // SYNC_CLK
input                pda_clk;      // PDCLK
output [ 2      : 0] prof;         // Profile
output               io_upd;       // I/O update
output               io_rst;       // I/O reset
output               m_rst;        // Master reset
output               tx_en;        // Tx enable
output [W_PBK-1 : 0] pdat;         // Parallel data

wire          w_ioup;
wire [ 2 : 0] w_prof;
wire          w_mrst;
wire          w_iors;
wire          w_wrst;
wire          w_rrst;
wire          w_pben;
wire          w_txen;
wire          p_syn;
wire          p_pdc;
assign {w_txen, w_pben, w_rrst, w_wrst, w_iors, w_mrst, w_prof, w_ioup} = cdds;

wire [W_PBK-1 : 0] pbk_out;
DgLk_Playback #(.ADDR(ADDR))
  PLBK(.clk(clk), .alu_out(alu_out), .ctrl({w_pben, w_rrst, w_wrst}), .pbk_out(pbk_out));


(* srl_style = "register" *) reg          io_upd_b1 = 0;
(* srl_style = "register" *) reg          io_upd_b0 = 0;
(* srl_style = "register" *) reg          io_upd = 0;
(* srl_style = "register" *) reg [ 2 : 0] prof_b1 = 0;
(* srl_style = "register" *) reg [ 2 : 0] prof_b0 = 0;
(* srl_style = "register" *) reg [ 2 : 0] prof = 0;
(* srl_style = "register" *) reg [W_PBK-1 : 0] pdat_b1 = 0;
(* srl_style = "register" *) reg [W_PBK-1 : 0] pdat_b0 = 0;
(* srl_style = "register" *) reg [W_PBK-1 : 0] pdat = 0;

always @(posedge clk)
begin
  {io_upd, io_upd_b0, io_upd_b1} <= {io_upd_b0, io_upd_b1, w_ioup};
  {prof, prof_b0, prof_b1} <= {prof_b0, prof_b1, w_prof};
  {pdat, pdat_b0, pdat_b1} <= {pdat_b0, pdat_b1, pbk_out};
end

reg m_rst = 0;
reg io_rst = 0;
reg tx_en = 0;
always @(posedge clk)
begin
  m_rst <= w_mrst;
  io_rst <= w_iors;
  tx_en <= w_txen;
end

// ------ DEBUG: Clock Monitor ------

wire f_rst;
RTMQ_AcsFlg #(.ADDR(ADDR_DBG))
  FACS(.clk(clk), .alu_out(alu_out), .f_read(), .f_wrt_alu(),
       .f_wrt_ihi(), .f_wrt_ilo(f_rst));

Dbg_ClkMon #(.W_CNT(16))
  CMON(.clk(clk), .rst(f_rst), .in_syn(syn_clk), .in_pdc(pda_clk), .cnt(reg_cmn));

endmodule
