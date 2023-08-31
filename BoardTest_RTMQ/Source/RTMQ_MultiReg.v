module RTMQ_MultiReg(clk, inp, out);
/*
功能：N_STG级W_BUS位宽缓存器。
将高位连线输出，低位输入寄存
*/
parameter W_BUS = 1;    // Bus width
parameter N_STG = 2;    // Pipeline stages

input                clk;
input  [W_BUS-1 : 0] inp;
output [W_BUS-1 : 0] out;

localparam W_BUF = (N_STG - 1) * W_BUS;
(* srl_style = "register" *) reg  [W_BUF-1 : 0] ppl = 0;
(* srl_style = "register" *) reg  [W_BUS-1 : 0] out = 0;

always @ (posedge clk) {out, ppl} <= {ppl, inp};

endmodule
