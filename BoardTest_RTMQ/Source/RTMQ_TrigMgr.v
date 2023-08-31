module RTMQ_TrigMgr(clk, alu_out, trg_chn, f_hld, f_trig);

`include "RTMQ_Peripheral.v"

input                clk;           // System clock
input  [W_ALU-1 : 0] alu_out;       // ALU output bus
input  [W_REG-1 : 0] trg_chn;       // Trigger signal input
input                f_hld;         // Hold state indicator
output               f_trig;        // Trigged flag: to resume hold state

wire [W_REG-1 : 0] e_trg;           // Trigger channel enable
wire               f_arm;           // Trigger arm flag
RTMQ_GPRegister #(.ADDR(R_ETRG))
  ETRG(.clk(clk), .alu_out(alu_out), .reg_out(e_trg), .f_trg(f_arm));

wire f_armed;
wire trg_act;
reg  trg_sta = 0;

always @ (posedge clk) trg_sta <= ((e_trg & trg_chn) > 0) & f_armed;

EdgeIdfr #(.Edg("pos"), .W(1), .PUS(0))
  ESTA(.clk(clk), .sig(trg_sta), .out(trg_act));

SRFlag #(.Pri("set"), .PUS(1'b0))
  FARM(.clk(clk), .set(f_arm), .rst(trg_act), .flg(f_armed));

SRFlag #(.Pri("set"), .PUS(1'b0))
  FTRG(.clk(clk), .set(trg_act), .rst(f_hld), .flg(f_trig));

endmodule
