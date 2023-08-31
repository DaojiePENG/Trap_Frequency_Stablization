`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: SUSTech
// Engineer: Daojie.PENG@outlook.com
// 
// Create Date: 2023年3月16日21:23:56
// Design Name: 
// Module Name: FOL_Filter16_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module IIR_Filter16_tb;

   parameter N_order=4;
   parameter Width=16;
   
   // Inputs
   reg i_clkp;
   reg i_rstn;

   parameter i_a0=30000;
   // 设定滤波器系数a
   reg [Width-1:0] a3=0;
   reg [Width-1:0] a2=0;
   reg [Width-1:0] a1=0;
   reg [Width-1:0] a0=i_a0;

   parameter b0_reg=65536/2-i_a0;
   // 设定滤波器系数b
   reg [Width-1:0] b3=0;
   reg [Width-1:0] b2=0;
   reg [Width-1:0] b1=0;
   reg [Width-1:0] b0=b0_reg;

   wire [Width*N_order-1:0] i_factor_a={a3,a2,a1,a0};
   wire [Width*N_order-1:0] i_factor_b={b3,b2,b1,b0};
   reg signed [15:0] i_filter;

   // Outputs
   wire signed [Width-1:0] o_filter;
 

   // Instantiate the Unit Under Test (UUT)
   IIR_Filter16 #(.N_order(N_order))uut (
      .i_clkp        (i_clkp     ), 
      .i_rstn        (i_rstn     ), 
      .i_factor_a    (i_factor_a ),
      .i_factor_b    (i_factor_b ),
      .i_filter      (i_filter   ), 
      .o_filter      (o_filter   )
   );

   // define reset time
   initial begin
      i_rstn = 0;
      #15;
      i_rstn = 1;
   end

   // define clock
   initial begin
      i_clkp = 0;
      forever #10 i_clkp = ~i_clkp; 
   end

parameter nnn = 2500;
   // define a ram store input signal
   reg signed[15:0] mem[nnn:0];
   // read data from disk
   initial begin
      $readmemh("D:/BaiduSyncdisk/FPGA_Lib/000_Projects/00_BASIC_modules/IIR_Filter/Source/wave_datahex3.txt" , mem);
   end

   // send data to filter
   integer i=0;
   initial begin
      #15;
      for(i = 0 ; i < nnn ; i = i+1) begin
         i_filter = mem[i];
         #20;
      end   
   end

   // write data to txt File
   integer file;
   integer cnt=0;
   initial begin
      file = $fopen("D:/BaiduSyncdisk/FPGA_Lib/000_Projects/00_BASIC_modules/IIR_Filter/Source/wave_filtered.txt" , "w");
   end

   // write data was filtered by fir to txt file 
   always @(posedge i_clkp) begin
      $fdisplay(file , o_filter);
   end

   always @(posedge i_clkp) begin
      $display("data out (%d)------> : %d ," , cnt, o_filter);
      cnt = cnt + 1;
      /*
      if (cnt%500==0) 
          begin
            i_a0=i_a0+1000;
          end
      */
      if (cnt == nnn) begin
         #20 $fclose(file);
         i_rstn = 0;
         #20 $stop;
      end

   end
   
endmodule


