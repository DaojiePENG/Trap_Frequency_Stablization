module RTMQ_Stack(clk, alu_out, stk_out);

parameter ADDR = 0;                 // Address of this register
parameter N_DPT = 10;               // Depth of stack in number of words

`include "RTMQ_Peripheral.v"

input                clk;           // System clock
input  [W_ALU-1 : 0] alu_out;       // ALU output bus
output [W_REG-1 : 0] stk_out;       // Data output

// ------ Timing Diagram ------
//
// STK: Stack address            1ST: Top element
// 2ND: Second-to-top element    NEW: New value
//
// clk    : /'''\.../'''\.../'''\.../'''\.../'''\.../'''\.../  # system clock
// alu_r*a: |  STK  |  ---  |  ---  |  ---  |  ---  |  ---  |  # operand address
// *_rda  : |  ---  |  ---  |  STK  |  ---  |  ---  |  ---  |  # RD address
// res/msk: |  ---  |  ---  |  ---  |  NEW  |  ---  |  ---  |  # ALU output
// f_pop  : |  ---  |   1   |  ---  |  ---  |  ---  |  ---  |  # stack pop flag
// f_psh  : |  ---  |  ---  |  ---  |  ---  |   1   |  ---  |  # stack push flag
// d_psh  : |  ---  |  ---  |  ---  |  ---  |  NEW  |  ---  |  # data input
// stk_out: |  1ST  |  1ST  |  2ND  |  2ND  |  2ND  |  NEW  |  # stack output

wire [W_REG-1 : 0] d_psh;           // Data to be pushed into the stack
wire               f_psh;           // Push flag
wire               f_pop;           // Pop flag

RTMQ_AcsFlg #(.ADDR(ADDR))
/*
  功能：通过通道来进行读操作
*/
  FACS(.clk(clk), .alu_out(alu_out), .f_read(f_pop), .f_wrt_alu(),
       .f_wrt_ihi(), .f_wrt_ilo());

RTMQ_GPRegister #(.ADDR(ADDR))      // Stack input register
/*
  功能：通过通用寄存器来进行写入操作
*/
  RINP(.clk(clk), .alu_out(alu_out), .reg_out(d_psh), .f_trg(f_psh));// 向堆栈中写入数据

reg  [N_DPT*W_REG-1 : 0] stk = 0;
always @ (posedge clk)
/*
  功能：堆栈的入栈和出栈
    1.泵出，堆栈高位补零，低位舍弃
    2.泵入，堆栈高位抛弃，低位入值d_psh
*/
if (f_pop)                          // Pop has higher priority, but do avoid conflict.
  stk <= {{(W_REG){1'b0}}, stk[N_DPT*W_REG-1 : W_REG]};
else if (f_psh)
  stk <= {stk[(N_DPT-1)*W_REG-1 : 0], d_psh};

assign stk_out = stk[W_REG-1 : 0];

endmodule
