module DgLk_BlockRAM(clk, w_ena, w_addr, w_data, r_addr, r_data);

parameter DW = 40;
parameter AW = 16;

localparam Len = 1 << AW;

input  clk;
input  w_ena;
input  [AW-1 : 0] w_addr;
input  [DW-1 : 0] w_data;
input  [AW-1 : 0] r_addr;
output [DW-1 : 0] r_data;

reg [DW-1 : 0] ram [0 : Len-1];
reg [DW-1 : 0] r_data = 0;
always @ (posedge clk) if (w_ena) ram[w_addr] <= w_data;
always @ (posedge clk) r_data <= ram[r_addr];

endmodule
