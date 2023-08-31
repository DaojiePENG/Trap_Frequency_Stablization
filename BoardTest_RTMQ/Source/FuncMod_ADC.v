module FuncMod_ADC(clk, reg_aio, adc_smp, adc_in);

`include "RTMQ_Peripheral.v"

input  clk;                     // System clock
output [W_REG-1 : 0] reg_aio;   // Data output
input  adc_smp;                 // ADC sample clock
input  [W_AIO-1 : 0] adc_in;    // ADC sample data

wire e_smp;
EdgeIdfr #("pos") ESMP(clk, adc_smp, e_smp);

reg  smp_dly = 0;
reg  [W_AIO-1 : 0] adc_buf = 0;
reg  [W_AIO-1 : 0] reg_aio = 0;
always @ (posedge clk)
begin
  smp_dly <= e_smp;
  adc_buf <= adc_in;
  if (smp_dly) reg_aio <= adc_buf;
end

endmodule
