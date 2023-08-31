`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: SUSTech
// Engineer: Daojie.PENG@outlook.com
// 
// Create Date: 2023年3月20日04:14:22
// Design Name: 
// Module Name: Full_Ahead_2Adder64
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: carray ahead adder 
//            it has 0 pipeline stage
// Dependencies: full_ahead_adder
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module Full_Ahead_3Adder #(
    parameter Width = 32,// width of the ahead adder, it can be 4, 8, 16, 32, 64.
    parameter Stage = 0)(
    input  wire             i_clkp  ,
    input  wire             i_rstn  ,
    input  wire [Width-1:0] i_z     , // 加数1
    input  wire [Width-1:0] i_a     , // 被加数
    input  wire [Width-1:0] i_b     , // 加数

    output wire [Width-1:0] o_d     , // 和
    output wire             o_c     , // 进位
    output wire             o_gm    , // generater of MSB
    output wire             o_pm      // propagater of MSB
    );
/*
carray look ahead adder
*/
wire [Width-1:0] encoded_d_wire, encoded_c_wire;
add3to2_encoder #(.Width(Width),.Stage(Stage)) encode4to2(// encode 3 inputs to two outputs
    .i_clkp     (i_clkp ),
    .i_rstn     (i_rstn ),
    .i_c        (i_z    ),
    .i_a        (i_a    ),
    .i_b        (i_b    ),
    .o_d        (encoded_d_wire),
    .o_c        (encoded_c_wire) 
);

wire [Width-1:0] d_wire;
wire c_wire;
wire gm_wire, pm_wire;
Full_Ahead_2Adder #(.Width(Width),.Stage(0)) full_add_final(// normally no need for pipeline
    .i_clkp     (i_clkp                             ),
    .i_rstn     (i_rstn                             ),
    .i_c        (1'b0                               ),
    .i_a        (encoded_d_wire                     ),
    .i_b        ({encoded_c_wire[Width-2:0], 1'b0}  ),
    .o_d        (d_wire                             ),
    .o_c        (c_wire                             ),
    .o_gm       (gm_wire                            ),
    .o_pm       (pm_wire                            ) 
);

pipelineto  #(.Width(Width+3),.Stage(Stage)) lineto_output(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a({d_wire, c_wire, gm_wire, pm_wire}),
  .o_a({ o_d,   o_c,    o_gm,    o_pm     })
  );
/*
assign o_d={d_h_wire,d_l_reg};
assign o_c=c_wire;
assign o_gm=gm_h_wire;
assign o_pm=pm_h_wire;
*/
endmodule
