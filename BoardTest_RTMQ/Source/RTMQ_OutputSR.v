module RTMQ_OutputSR(clk, alu_out, dat_out);
/*
描述：在f_inp信号的作用下，将通用寄存器中写入的一个字数据d_inp移位添加到输出dat_out的高位
*/
parameter ADDR = 0;                 // Register address
parameter N_SRL = 6;                // Register length in words

`include "RTMQ_Peripheral.v"

localparam W_OSR = W_REG * N_SRL;

input                clk;           // System clock
input  [W_ALU-1 : 0] alu_out;       // ALU output bus
output [W_OSR-1 : 0] dat_out;       // Data output

wire [W_REG-1 : 0] d_inp;           // Data to be pushed into the shift register
wire               f_inp;           // Input flag

RTMQ_GPRegister #(.ADDR(ADDR))      // Register input
  RINP(.clk(clk), .alu_out(alu_out), .reg_out(d_inp), .f_trg(f_inp));

reg  [W_OSR-1 : 0] dat_out = 0;
always @ (posedge clk)
if (f_inp)
  dat_out <= {d_inp, dat_out[W_OSR-1 : W_REG]};
else
  dat_out <= dat_out;

endmodule
