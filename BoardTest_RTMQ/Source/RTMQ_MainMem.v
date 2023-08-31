module RTMQ_MainMem(clk, adr_a, dat_a, en_a, adr_b, dat_b, din_b, we_b);

`include "RTMQ_Peripheral.v"

input                clk;              // System clock
input  [W_REG-1 : 0] adr_a;            // Address of A port (IF side)
output [W_REG-1 : 0] dat_a;            // Data output of A port
input                en_a;             // Clock enable of A port

input  [W_REG-1 : 0] adr_b;            // Address of B port (Data side)
output [W_REG-1 : 0] dat_b;            // Data output of B port
input  [W_REG-1 : 0] din_b;            // Data input of B port
input                we_b;             // Write flag of B port

reg  [W_REG-1 : 0] mem [0 : N_MEM-1];  // Main memory

// ------ Simulation ------
initial begin
  $readmemh("C:/FPGA_Lib/20230416_DigiLock/BoardTest_RTMQ/ins_mem.txt", mem);
end

// ------ A Port ------
// Latency: adr_a --> dat_a, 3 cycles

reg  [W_REG-1 : 0] lat_a = 0;          // Memory latch
reg  [W_REG-1 : 0] ppl_a = 0;          // Pipeline
reg  [W_REG-1 : 0] dat_a = 0;          // Output register
always @ (posedge clk) if (en_a)
begin
  lat_a <= mem[adr_a];
  ppl_a <= lat_a;
  dat_a <= ppl_a;
end
else {dat_a, ppl_a, lat_a} <= {dat_a, ppl_a, lat_a};

// ------ B Port ------

reg  [W_REG-1 : 0] lat_b = 0;          // Memory latch
reg  [W_REG-1 : 0] ppl_b = 0;          // Pipeline
reg  [W_REG-1 : 0] dat_b = 0;          // Output register
always @ (posedge clk)
begin
  lat_b <= mem[adr_b];
  ppl_b <= lat_b;
  dat_b <= ppl_b;
  if (we_b) mem[adr_b] <= din_b;
end

endmodule
