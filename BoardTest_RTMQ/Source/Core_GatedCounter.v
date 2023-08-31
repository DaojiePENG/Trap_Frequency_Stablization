module Core_GatedCounter(clk, in, rst, smp, out);

parameter W_CTR = 8;

input                clk;
input                in;
input                rst;
input                smp;
output [W_CTR-1 : 0] out;

reg  [W_CTR-1 : 0] cnt = 0;
reg  [W_CTR-1 : 0] out = 0;
wire ovf = (cnt == (1 << W_CTR) - 1);
always @ (posedge clk) if (rst) cnt <= 0; else cnt <= cnt + (in & ~ovf);
always @ (posedge clk) if (smp) out <= cnt;

endmodule
