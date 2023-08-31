module FuncMod_DAC(clk, alu_out, smp, dat);

parameter ADDR = 0;

`include "RTMQ_Peripheral.v"

input  clk;                        // System clock
input  [W_ALU-1 : 0] alu_out;      // ALU output bus
output smp;                        // DAC sample clock
output [W_AIO-1 : 0] dat;          // DAC sample data

reg  [W_AIO-1 : 0] dat = 0;
wire [W_REG-1 : 0] reg_out;
wire               f_smp;          // Sample valid flag
RTMQ_GPRegister #(.ADDR(ADDR))
  RDAC(.clk(clk), .alu_out(alu_out), .reg_out(reg_out), .f_trg(f_smp));

reg  [ 1 : 0] f_dly = 0;
reg           smp = 0;
always @ (posedge clk) 
begin
  f_dly <= {f_dly[0], f_smp};
  smp <= f_dly[0] | f_dly[1];
  dat <= reg_out[W_AIO-1 : 0];
end

endmodule
