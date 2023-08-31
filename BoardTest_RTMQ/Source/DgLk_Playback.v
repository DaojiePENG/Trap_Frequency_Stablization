module DgLk_Playback(clk, alu_out, ctrl, pbk_out);

parameter R_PBK = 0;               // Playback data input register
parameter R_TUN = 0;               // Output tune register

`include "RTMQ_Peripheral.v"

input                clk;          // System clock
input  [W_ALU-1 : 0] alu_out;      // ALU output bus
input  [ 4      : 0] ctrl;         // Playback control flags
output [W_PBK-1 : 0] pbk_out;      // Playback output

wire p_ena;
wire tun_upd;
wire w_rst;
wire r_rst;
assign {p_ena, tun_upd, r_rst, w_rst} = ctrl;

// ------ Interface Registers ------

wire [W_PBK-1 : 0] d_inp;           // Sample input
wire               f_inp;           // Input flag
RTMQ_GPRegister #(.ADDR(R_PBK))
  RPBK(.clk(clk), .alu_out(alu_out), .reg_out(d_inp), .f_trg(f_inp));

wire [W_REG-1 : 0] d_tun;
wire [W_APB-1 : 0] d_adr;
wire [ 7      : 0] w_pha;
wire [ 7      : 0] w_amp;
assign {d_adr, w_pha, w_amp} = d_tun;

RTMQ_GPRegister #(.ADDR(R_TUN))
  RTUN(.clk(clk), .alu_out(alu_out), .reg_out(d_tun), .f_trg());

// ------ Playback Control ------

reg  [W_APB-1 : 0] w_ptr = 0;
reg  [W_APB-1 : 0] r_ptr = 0;
reg  [W_PBK-1 : 0] w_dat = 0;
wire [W_PBK-1 : 0] r_dat;

reg  f_cyc = 0;
always @ (posedge clk)
begin
  f_cyc <= (r_ptr == w_ptr - 2);
  if (w_rst) w_ptr <= 0;
  else w_ptr <= w_ptr + f_inp;
  if (r_rst) r_ptr <= d_adr;
  else if (f_cyc) r_ptr <= 0;
  else r_ptr <= r_ptr + p_ena;
end

// ------ Output Tune ------

reg  [W_PBK-1 : 0] pbk_buf = 0;
reg  [W_PBK-1 : 0] pbk_out = 0;

reg  [ 7      : 0] d_amp = 0;
reg  [ 8      : 0] fct_amp = 0;
reg  [ 7      : 0] d_pha = 0;
reg  [ 7      : 0] pha_pl0 = 0;
reg  [ 7      : 0] pha_pl1 = 0;
reg  [ 7      : 0] pha_pl2 = 0;
wire [ 7      : 0] t_amp;
wire [ 7      : 0] t_pha;
wire [ 7      : 0] res_amp;
assign {t_amp, t_pha} = pbk_buf;

always @ (posedge clk)
begin
  if (tun_upd)
  begin
    {d_pha, d_amp} <= {w_pha, w_amp};
    fct_amp <= w_amp + 1;
  end
  else {d_pha, d_amp, fct_amp} <= {d_pha, d_amp, fct_amp};
  pbk_buf <= r_dat;
  pha_pl0 <= t_pha;
  pha_pl1 <= pha_pl0 + d_pha;
  pha_pl2 <= pha_pl1;
  if (p_ena) pbk_out <= {res_amp, pha_pl2};
  else pbk_out <= {d_amp, d_pha};
end

DgLk_Mult8x8
  MULT(.CLK(clk), .A(fct_amp), .B(t_amp), .P(res_amp));

DgLk_BlockRAM #(.DW(W_PBK), .AW(W_APB))
  PMEM(.clk(clk), .w_ena(f_inp), .w_addr(w_ptr), .w_data(d_inp), .r_addr(r_ptr), .r_data(r_dat));

endmodule
