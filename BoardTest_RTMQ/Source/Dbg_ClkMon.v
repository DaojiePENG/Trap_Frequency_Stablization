module Dbg_ClkMon(clk, rst, in_syn, in_pdc, cnt);
/*
功能：时钟监视器。
具体：待分析
*/
parameter W_CNT = 16;
localparam W_RES = W_CNT * 2;
localparam N_MAX = (1 << W_CNT) - 1;

input                clk;
input                rst;
input                in_syn;
input                in_pdc;
output [W_RES-1 : 0] cnt;

reg  [W_CNT-1 : 0] c_syn = 0;
reg  [W_CNT-1 : 0] c_pdc = 0;
reg  [ 1      : 0] in_buf = 0;
reg  [ 1      : 0] f_cnt = 0;

assign cnt = {c_syn, c_pdc};

always @ (posedge clk)
begin
  in_buf <= {in_syn, in_pdc};
  f_cnt[1] <= in_buf[1] & (c_syn < N_MAX - 1);
  f_cnt[0] <= in_buf[0] & (c_pdc < N_MAX - 1);
end

always @ (posedge clk)
if (rst) {c_syn, c_pdc} <= {{(W_RES){1'b0}}};
else
begin
  // 低位移位赋值；
  c_syn <= c_syn + f_cnt[1];
  c_pdc <= c_pdc + f_cnt[0];
end

endmodule
