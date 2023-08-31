`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: SUSTech
// Engineer: Daojie.PENG@outlook.com
// 
// Create Date: 2023/2/24 16:14:58
// Design Name: 
// Module Name: Shift_Connecter
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Shift_word connecter
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
/*
register function descriptions:
|====================================================== xxxxx[31:0] ===========================================================|
[31:24]| ------------ | ------------ | ------------ | ------------ | ------------ | ------------ | ------------ | ------------ |
[23:16]| ------------ | ------------ | ------------ | ------------ | ------------ | ------------ | ------------ | ------------ |
[15:8 ]| ------------ | ------------ | ------------ | ------------ | ------------ | ------------ | ------------ | ------------ |
[7 :0 ]| ------------ | ------------ | ------------ | ------------ | ------------ | ------------ | ------------ | ------------ |
*/

module Shift_Connecter #(
  parameter L_width=32, // 输入的长信号宽度
  parameter S_width=16, // 输出的短信号宽度
  parameter Stage = 0, // 流水线，默认不添加，可选1
  parameter Shift_word=4)  // 错位连接信号宽度
  (
    input  wire                   i_clkp    ,
    input  wire                   i_rstn    ,
    input  wire  [L_width-1:0]    i_long    , // 被连接的长信号
    input  wire  [Shift_word-1:0] i_shift   , // 要错位连接的信号位数
    output wire  [S_width-1:0]    o_short     // 要连接的短信号
  );

localparam D_word=L_width-S_width;       // 两段连线的接口数量差值，也就是可以错位连接的数量
wire [S_width-1 : 0] tmp_wire [0 : D_word-1]; // 提供D_WRD个短信号长度的值供选择

genvar i;
generate
  for (i = 0; i < D_word; i = i + 1)
  begin
    assign tmp_wire[i] = i_long[S_width+i-1 : i]; // 将long信号打包成内存格式，以供short信号片选连接
  end
endgenerate

wire [S_width-1:0] temp_rwire;
pipelineto #(.Width(S_width), .Stage(Stage)) inst_pipelineto(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a(tmp_wire[i_shift]),
  .o_a(temp_rwire));
assign o_short = temp_rwire;            // 根据输入的shift_n选择要移位的数据进行输出

endmodule