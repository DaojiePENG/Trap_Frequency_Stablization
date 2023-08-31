module DgLk_Playback(clk, alu_out, ctrl, pbk_out);

parameter ADDR = 0;

`include "RTMQ_Peripheral.v"

input                clk;          // System clock
input  [W_ALU-1 : 0] alu_out;      // ALU output bus
input  [ 2      : 0] ctrl;         // Playback control flags
output [W_PBK-1 : 0] pbk_out;      // Playback output

wire p_ena;
wire w_rst_w;
wire r_rst_w;
assign {p_ena, r_rst_w, w_rst_w} = ctrl;

wire [W_PBK-1 : 0] d_inp;           // Sample input
wire               f_inp;           // Input flag
RTMQ_GPRegister #(.ADDR(ADDR))
  RINP(.clk(clk), .alu_out(alu_out), .reg_out(d_inp), .f_trg(f_inp));

reg  [W_APB-1 : 0] w_ptr = 0;
reg  [W_APB-1 : 0] r_ptr = 0;
reg  [W_PBK-1 : 0] w_dat = 0;
wire [W_PBK-1 : 0] r_dat;
reg  [W_PBK-1 : 0] pbk_out = 0;
reg  [W_PBK-1 : 0] pbk_buf = 0;

reg  w_rst = 0;
reg  r_rst = 0;
always @ (posedge clk)
begin
  w_rst <= w_rst_w;
  r_rst <= r_rst_w | (r_ptr == w_ptr - 2);
  pbk_buf <= r_dat;
  pbk_out <= pbk_buf;
  if (w_rst) w_ptr <= 0;
  else w_ptr <= w_ptr + f_inp;
  if (r_rst) r_ptr <= 0;
  else r_ptr <= r_ptr + p_ena;
end

DgLk_BlockRAM #(.DW(W_PBK), .AW(W_APB))
  PMEM(.clk(clk), .w_ena(f_inp), .w_addr(w_ptr), .w_data(d_inp), .r_addr(r_ptr), .r_data(r_dat));

endmodule
