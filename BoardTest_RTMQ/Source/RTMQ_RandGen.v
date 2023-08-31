module RTMQ_RandGen(clk, reg_rnd);

`include "RTMQ_Peripheral.v"

input                clk;              // System clock
output [W_REG-1 : 0] reg_rnd;          // Random number output

localparam I_Z1 = 64'h45D0_00FF_FFF0_05FF;
localparam I_Z2 = 64'hFFFC_BFFF_D800_0680;
localparam I_Z3 = 64'hFFDA_3500_00FE_95FF;

reg  [63      : 0] z1 = I_Z1;
reg  [63      : 0] z2 = I_Z2;
reg  [63      : 0] z3 = I_Z3;
reg  [W_REG-1 : 0] reg_rnd = 0;
always @ (posedge clk)
begin
  z1 <= {z1[39: 1], z1[58:34] ^ z1[63:39]};
  z2 <= {z2[50: 6], z2[44:26] ^ z2[63:45]};
  z3 <= {z3[56: 9], z3[39:24] ^ z3[63:48]};
  reg_rnd <= z1[W_REG-1 : 0] ^ z2[W_REG-1 : 0] ^ z3[W_REG-1 : 0];
end

endmodule
