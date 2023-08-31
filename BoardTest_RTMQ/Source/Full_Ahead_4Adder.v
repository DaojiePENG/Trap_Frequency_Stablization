`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: SUSTech
// Engineer: Daojie.PENG@outlook.com
// 
// Create Date: 2022/12/15 12:45:59
// Design Name: 
// Module Name: Full_4Adder_P3
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: i_a full adder for Width bits, o_d=i_a+i_b.
//              it has 3 pipeline stages 
// Dependencies: Full_2Adder_P0, full_adder5to3
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module Full_Ahead_4Adder #(
    parameter Width = 32,// 位宽，改参数可根据实际需求调整，可为： 4, 8, 16, 32
    parameter Stage = 0)( 
    input  wire             i_clkp  ,
    input  wire             i_rstn  ,
    input  wire             i_c     , // 前一位的进位
    input  wire [Width-1:0] i_y     , // 加数0
    input  wire [Width-1:0] i_z     , // 加数1
    input  wire [Width-1:0] i_a     , // 加数2
    input  wire [Width-1:0] i_b     , // 加数3

    output wire [Width-1:0] o_d     , // 和
    output wire             o_c     , // 进位
    output wire             o_gm    , // generater of MSB
    output wire             o_pm      // propagater of MSB
    );
/*
设计思路：
    1.首先用进位保留的加法器，以输入的四个数赋值给5to3加法编码器的进位c、数据y、数据z、数据a、数据b五个接口；
    该操作会生成三个结果，数据位串和两个进位串，数据串低阶进位串用于最终结果计算，高阶进位用于位拓展级联，
    这样在多级加法中可以避免加法器的行波进位链导致的时延问题；
    2.将数据位串和低位补一位0的进位串用全加器相加得到最终结果；
    3.更高级的进位串用于级联舍弃
    时序：与P0的不同之处在于最后使用的全加器含三级流水线，且输入添加了一级流水线；
*/
wire [Width-1:0] encoded_d_wire, encoded_c_wire;
add4to2_encoder #(.Width(Width),.Stage(Stage)) encode4to2(// encode 4 inputs to two outputs
    .i_clkp     (i_clkp ),
    .i_rstn     (i_rstn ),
    .i_c        (i_c    ),
    .i_y        (i_y    ),
    .i_z        (i_z    ),
    .i_a        (i_a    ),
    .i_b        (i_b    ),
    .o_d        (encoded_d_wire),
    .o_c        (encoded_c_wire) 
);

wire [Width-1:0] d_wire;
wire c_wire, gm_wire, pm_wire;
Full_Ahead_2Adder #(.Width(Width),.Stage(0)) full_adder_final(// 3.输入两个加数，输出一个结果。
    .i_clkp     (i_clkp                             ),
    .i_rstn     (i_rstn                             ),
    .i_c        (1'b0                               ),
    .i_a        (encoded_d_wire[Width-1:0]          ), // 被加数
    .i_b        ({encoded_c_wire[Width-2:0], 1'b0}  ), // 加数
    .o_d        (d_wire                             ), // 和
    .o_c        (c_wire                             ), // 进位
    .o_gm       (gm_wire                            ),
    .o_pm       (pm_wire                            )
    );
pipelineto  #(.Width(Width+3),.Stage(Stage)) lineto_output(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a({d_wire, c_wire, gm_wire,    pm_wire }),
  .o_a({o_d,    o_c,    o_gm,       o_pm    })
  );
//assign o_d = d_out_wire;
//assign o_c = c_out_wire; 
endmodule
