`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: SUSTech
// Engineer: Daojie.PENG@outlook.com
// 
// Create Date: 2023å¹?3æœ?3æ—?00:40:56
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

module FOL_Filter16_tb;

   // Inputs
   reg i_clkp;
   reg i_rstn;
   reg signed [15:0] i_filter;

   // Outputs
   wire signed [31:0] o_filter;
   reg [15:0] i_a0=10000;

   // Instantiate the Unit Under Test (UUT)
   FOL_Filter16 #(.n(15))uut (
      .i_clkp       (i_clkp    ), 
      .i_rstn         (i_rstn      ), 
      .i_a0            (i_a0         ),
      //.a1_wire            (a1_wire         ),
      .i_filter     (i_filter  ), 
      .o_filter    (o_filter )
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
      $readmemh("D:/BaiduSyncdisk/FPGA_Lib/000_Projects/00_BASIC_modules/FOL_Filter/Source/wave_datahex.txt" , mem);
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
      file = $fopen("D:/BaiduSyncdisk/FPGA_Lib/000_Projects/00_BASIC_modules/FOL_Filter/Source/wave_filtered.txt" , "w");
   end

   // write data was filtered by fir to txt file 
   always @(posedge i_clkp) begin
      $fdisplay(file , o_filter);
   end

   always @(posedge i_clkp) begin
      $display("data out (%d)------> : %d ," , cnt, o_filter);
      cnt = cnt + 1;
      /**/
      if (cnt%500==0) 
          begin
            i_a0=i_a0+1000;
          end
      
      if (cnt == nnn) begin
         #20 $fclose(file);
         i_rstn = 0;
         #20 $stop;
      end

   end
   
endmodule


