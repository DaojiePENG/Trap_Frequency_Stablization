`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: SUSTech
// Engineer: Daojie.PENG@qq.com
// 
// Create Date: 2023年3月3日00:03:57
// Design Name: 
// Module Name: FOL_Filter16
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: Booth_Multiplier16，FULL_ADDER_X_p0
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// Reference： https://zhuanlan.zhihu.com/p/479717098
//////////////////////////////////////////////////////////////////////////////////

module FOL_Filter16 #(
    parameter Width=16,
    parameter n=15)(
  input  wire               i_clkp     ,
  input  wire               i_rstn       ,
  input  wire        [15:0] i_a0          ,   // unsigned factor a
  //input  wire        [15:0] a1_wire          ,   // unsigned factor a
  input  wire signed [15:0] i_filter   ,

  output wire signed [31:0] o_filter  
  );

reg [15:0] a0_reg, a1_reg;
// First order low-pass digital filter
/*
    y(n)=i_a0*x(n)+(1-i_a0)*y(n-1);
*/
//wire [15:0] a1_wire=0;// unsigned factor 1-a

reg [16-1:0] input_shift_reg; // 十个输入寄存器
always @ (posedge i_clkp or negedge i_rstn)
    begin
        if (!i_rstn) 
            begin
                a0_reg<=0;
                a1_reg<=0;
                input_shift_reg<=0;
            end
        else 
            begin
                a0_reg<=i_a0;
                a1_reg<=65536/2-i_a0;
                input_shift_reg<=i_filter;
            end
    end
//wire [15:0] reg_filter_in=input_shift_reg[10*16-1:(10-1)*16];// 高位作为输出


wire [31:0] mult0_wire, mult1_wire, filter_1_wire;  // 加法器内部有一级流水线完成记录y(n-1)的工作
Booth_Multiplier16 mult0(
    .i_clkp         (i_clkp             ),
    .i_rstn         (i_rstn             ),
    .i_multa        (a0_reg             ),
    .i_multb        (input_shift_reg    ),
    .o_product      (mult0_wire         )
    );
Booth_Multiplier16 mult1(
    .i_clkp         (i_clkp             ),
    .i_rstn         (i_rstn             ),
    .i_multa        (a1_reg             ),
    .i_multb        (o_filter[15:0]     ),
    .o_product      (mult1_wire         )
    );

Full_Ahead_2Adder #(.Width(32)) add0(
    .i_clkp         (i_clkp             ),
    .i_rstn         (i_rstn             ),
    .i_c            (1'b0               ),
    .i_a            (mult0_wire>>>n     ),
    .i_b            (mult1_wire>>>n     ),
    .o_d            (filter_1_wire      ),
    .o_c            (),
    .o_gm           (),
    .o_pm           ()
    );
pipelineto  #(.Width(Width*2),.Stage(1)) lineto_output(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a(filter_1_wire),
  .o_a(o_filter)
  );
//assign o_filter=filter_1_wire;

endmodule

