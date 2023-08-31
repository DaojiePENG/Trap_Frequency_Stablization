module RTMQ_Stack_BRAM(clk, alu_out, stk_out);
/*
  描述：这种堆栈与RTMQ_Stack的不同在于，如果只读取的话不会破坏数据；另一个读完高位就会补零。
  好像用起来也没有太大不同...
*/
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
// clk    : /'''\.../'''\.../'''\.../'''\.../'''\.../'''\.../'''\.../  # system clock
// alu_r*a: |  STK  |  ---  |  ---  |  ---  |  ---  |  ---  |  ---  |  # operand address
// *_rda  : |  ---  |  ---  |  STK  |  ---  |  ---  |  ---  |  ---  |  # RD address
// res/msk: |  ---  |  ---  |  ---  |  NEW  |  ---  |  ---  |  ---  |  # ALU output
// f_pop  : |  ---  |   1   |  ---  |  ---  |  ---  |  ---  |  ---  |  # stack pop flag
// f_psh  : |  ---  |  ---  |  ---  |  ---  |   1   |  ---  |  ---  |  # stack push flag
// p_top_*: |  ---  |  ---  |  -1   |  ---  |  ---  |  +1   |  ---  |  # stack top pointer
// d_psh  : |  ---  |  ---  |  ---  |  ---  |  NEW  |  ---  |  ---  |  # data input
// stk_out: |  1ST  |  1ST  |  1ST  |  2ND  |  2ND  |  2ND  |  NEW  |  # stack output

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
  RINP(.clk(clk), .alu_out(alu_out), .reg_out(d_psh), .f_trg(f_psh));

reg  [W_REG-1 : 0] p_top_r = 32'hFFFFFFFF;
reg  [W_REG-1 : 0] p_top_w = 0;

always @ (posedge clk)
/*
  功能：内存出栈和入栈
    1.出栈，栈顶部-1；栈底部-1；
    2.入栈，栈顶部+1；栈底部+1；
    3.保持，两者都保持不变
*/
if (f_pop)
begin
  p_top_r <= p_top_r - 1;
  p_top_w <= p_top_w - 1;
end
else if (f_psh)
begin
  p_top_r <= p_top_r + 1;
  p_top_w <= p_top_w + 1;
end
else {p_top_r, p_top_w} <= {p_top_r, p_top_w};

reg  [W_REG-1 : 0] mem_stk [0 : N_DPT-1];
reg  [W_REG-1 : 0] stk_out = 0;

always @ (posedge clk)
/*
  功能： 堆栈输出始终为p_top_r指向的内存地址；在入栈是入栈到p_top_w指向的内存地址
*/
begin
  stk_out <= mem_stk[p_top_r];
  if (f_psh) mem_stk[p_top_w] <= d_psh;
end

endmodule
