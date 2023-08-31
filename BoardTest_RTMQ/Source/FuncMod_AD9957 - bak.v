module FuncMod_AD9957(clk, fclk, alu_out, reg_syc, reg_pdc,
                      cdds, clk_pol, syn_clk, pda_clk,
                      prof, io_upd, io_rst, m_rst, tx_en, pdat);

parameter ADDR = 0;
parameter ADDR_DBG = 0;

`include "RTMQ_Peripheral.v"

input  clk;                        // System clock
input  fclk;                       // Fast output clock
input  [W_ALU-1 : 0] alu_out;      // ALU output bus
output [W_REG-1 : 0] reg_syc;      // SYNC_CLK monitor
output [W_REG-1 : 0] reg_pdc;      // PDCLK monitor
input  [ 9      : 0] cdds;         // DDS control signals
input  [ 1      : 0] clk_pol;      // Clock polarization: {POL_SYN, POL_PDC}
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
wire [ 2 : 0] w_pctl;
wire          w_txen;
wire          p_syn;
wire          p_pdc;
assign {w_txen, w_pctl, w_iors, w_mrst, w_prof, w_ioup} = cdds;
assign {p_syn, p_pdc} = clk_pol;

wire [W_PBK-1 : 0] pbk_out;
DgLk_Playback #(.ADDR(ADDR))
  PLBK(.clk(clk), .alu_out(alu_out), .ctrl(w_pctl), .pbk_out(pbk_out));

(* srl_style = "register" *) reg [ 3 : 0] buf_syn = 0;
(* srl_style = "register" *) reg [ 3 : 0] buf_pdc = 0;
reg          syn = 0;
reg          pdc = 0;
always @(posedge fclk)
begin
  {syn, buf_syn} <= {buf_syn, syn_clk} ^ {1'b0, p_syn, 3'b0};
  {pdc, buf_pdc} <= {buf_pdc, pda_clk} ^ {1'b0, p_pdc, 3'b0};
end

(* srl_style = "register" *) reg          io_upd_b2 = 0;
(* srl_style = "register" *) reg          io_upd_b1 = 0;
(* srl_style = "register" *) reg          io_upd_b0 = 0;
(* srl_style = "register" *) reg          io_upd = 0;
(* srl_style = "register" *) reg [ 2 : 0] prof_b2 = 0;
(* srl_style = "register" *) reg [ 2 : 0] prof_b1 = 0;
(* srl_style = "register" *) reg [ 2 : 0] prof_b0 = 0;
(* srl_style = "register" *) reg [ 2 : 0] prof = 0;
(* srl_style = "register" *) reg [15 : 0] pdat_b2 = 0;
(* srl_style = "register" *) reg [15 : 0] pdat_b1 = 0;
(* srl_style = "register" *) reg [15 : 0] pdat_b0 = 0;
(* srl_style = "register" *) reg [15 : 0] pdat = 0;

always @(posedge fclk)
begin
  if (syn) {io_upd_b2, prof_b2} <= {w_ioup, w_prof};
  else {io_upd_b2, prof_b2} <= {io_upd_b2, prof_b2};
  if (pdc) pdat_b2 <= pbk_out; else pdat_b2 <= pdat_b2;
  {io_upd, io_upd_b0, io_upd_b1} <= {io_upd_b0, io_upd_b1, io_upd_b2};
  {prof, prof_b0, prof_b1} <= {prof_b0, prof_b1, prof_b2};
  {pdat, pdat_b0, pdat_b1} <= {pdat_b0, pdat_b1, pdat_b2};
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

Dbg_ClkMon #(.W_CNT(8))
  MSYC(.clk(clk), .rst(f_rst), .smp(buf_syn[1:0]), .cnt(reg_syc));

Dbg_ClkMon #(.W_CNT(8))
  MPDC(.clk(clk), .rst(f_rst), .smp(buf_pdc[1:0]), .cnt(reg_pdc));

endmodule
