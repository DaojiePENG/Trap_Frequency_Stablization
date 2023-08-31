module RTMQ_InputSR(clk, alu_out, reg_isr, dat_in, f_load);
/*
描述：
  写入-在f_load信号的作用下将输入的N_SRL个字数据写入缓存dat_buf中;
  读出-在f_rrq信号的作用下将缓存dat_buf中数据的最低位字读出为reg_isr
*/

parameter ADDR = 0;                 // Register address
parameter N_SRL = 6;                // Register length in words

`include "RTMQ_Peripheral.v"

localparam W_ISR = W_REG * N_SRL;

input                clk;           // System clock
input  [W_ALU-1 : 0] alu_out;       // ALU output bus
output [W_REG-1 : 0] reg_isr;       // Output to regfile
input  [W_ISR-1 : 0] dat_in;        // Data load port
input                f_load;        // Data load flag

reg  [W_ISR-1 : 0] dat_buf = 0;
// 0.缓存的低位是位移寄存器的输出
assign reg_isr = dat_buf[W_REG-1 : 0];

wire f_rrq;
RTMQ_AcsFlg #(.ADDR(ADDR))
  FACS(.clk(clk), .alu_out(alu_out), .f_read(f_rrq), .f_wrt_alu(),
       .f_wrt_ihi(), .f_wrt_ilo());

always @ (posedge clk)
if (f_load)
  // 1.装载信号的话，将输入的数据存到缓存其中
  dat_buf <= dat_in;
else if (f_rrq)
  // 2.读取信号的话，将缓存中的数据向低位移位
  dat_buf <= dat_buf >> W_REG;
else
  // 2.其它情况保持不变
  dat_buf <= dat_buf;

endmodule
