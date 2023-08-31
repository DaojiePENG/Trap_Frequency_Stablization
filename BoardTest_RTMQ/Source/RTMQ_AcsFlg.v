module RTMQ_AcsFlg(clk, alu_out, f_read, f_wrt_alu, f_wrt_ihi, f_wrt_ilo);
/*描述：根据alu_out中寄存器地址位的值给出读写信号*/
parameter ADDR = 0;

`include "RTMQ_Header.v"

input                clk;           // System clock
input  [W_ALU-1 : 0] alu_out;       // ALU output bus
output               f_read;        // Register read flag
output               f_wrt_alu;     // Register write flag, A channel
output               f_wrt_ihi;     // Register write flag, I channel, higher segment
output               f_wrt_ilo;     // Register write flag, I channel, lower segment

// --- Unpack ALU bus ---
wire [W_REG-1 : 0] alu_res;
wire [W_REG-1 : 0] alu_msk;
wire [W_ADR-1 : 0] alu_rda;
wire [W_ADR-1 : 0] alu_r0a;
wire [W_ADR-1 : 0] alu_r1a;
wire [W_REG-1 : 0] imm_res;
wire [W_ADR-1 : 0] imm_rda;
wire               imm_seg;
assign {alu_res, alu_msk, alu_rda, alu_r0a, alu_r1a,
        imm_res, imm_rda, imm_seg} = alu_out;

reg  f_read = 0;
reg  f_wrt_alu = 0;
reg  f_wrt_ihi = 0;
reg  f_wrt_ilo = 0;
always @ (posedge clk)
/*
  功能：当alu总线上的地址位alu_r0a等于该寄存器被分配的地址ADDR时起作用。
  1.ADDR=r0,r1时给出f_read，进行读操作。下面类似，给出相应的信号；
  2.ADDR=rd时alu型写
  3.ADDR=imm_rda时为立即数的写，根据imm_seg选择高低位
*/
begin
  f_read <= (alu_r0a == ADDR) | (alu_r1a == ADDR);
  f_wrt_alu <= (alu_rda == ADDR);
  f_wrt_ihi <= (imm_rda == ADDR) & ~imm_seg;
  f_wrt_ilo <= (imm_rda == ADDR) &  imm_seg;
end

endmodule
