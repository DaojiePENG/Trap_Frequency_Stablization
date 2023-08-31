`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: SUSTech
// Engineer: Daojie.PENG@outlook.com
// 
// Create Date: 2022/12/15 15:44:48
// Design Name: 
// Module Name: PID_16
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// 2023年4月28日14:28:19-处理有符号数负数移位成-1的问题，有符号数默认负向取整，在迭代算法中要谨慎处理。
// 2023年4月28日16:29:10-处理限幅问题，声明了有符号数比较
// 2023年5月10日17:17:18-将限幅提炼成模块
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

module PID_16 #(
    parameter Width = 16,
    parameter Shift = 5, // 移位数量寄存器的位宽，可以移位的范围为：N=2^Shift
    parameter Stage = 1 // 添加流水线默认为1，添加流水线为0即可
    )(
    input wire                          i_clkp,
    input wire                          i_rstn,
    input wire  [Width-1:0]             i_rt,       // 目标信号
    input wire  [Width-1:0]             i_yt,       // 实际信号
    input wire  [Width-1:0]             i_k0,       // 增量法PID参数，i_k0
    input wire  [Width-1:0]             i_k1,       // 增量法PID参数，i_k1
    input wire  [Width-1:0]             i_k2,       // 增量法PID参数，i_k2
    input wire  [Shift-1:0]             i_shift,    // 输出结果右位移位数，用于缩放
    input wire  signed [Width*2-1:0]    i_min,      // PID允许输出的最小值
    input wire  signed [Width*2-1:0]    i_max,      // PID允许输出的最大值
        
    output wire [Width*2-1:0]  o_ut // 误差调节信号
    );

// ------ input pipeline stage1: inner 1 stage------
reg [Width-1:0] rt_reg, yt_reg;
always @ (posedge i_clkp or negedge i_rstn)
    begin
        if (!i_rstn) 
            begin
                rt_reg<=0;
                yt_reg<=0;
            end
        else 
            begin
                rt_reg<=i_rt;
                yt_reg<=i_yt;
            end
    end

// ------ subtracter pipelin stage2: inner 1 stage --------
wire [Width-1:0] et0_wire;
wire [Width-1:0] yt_conv_wire=~yt_reg+1; // complement code of yt_reg
Full_Ahead_2Adder #(.Width(Width)) full_subtracter(
    /**/
    .i_clkp     (i_clkp         ),
    .i_rstn     (i_rstn         ),
    .i_c        (1'b0           ),
    .i_a        (rt_reg         ),
    .i_b        (yt_conv_wire   ),
    .o_d        (et0_wire       ),
    .o_c        (),
    .o_gm       (),
    .o_pm       ()
    );

// 生成缓存et_0,et1_reg,o_et_2的寄存器
reg [Width-1:0] et1_reg,et2_reg;
always @ (posedge i_clkp or negedge i_rstn)
    begin
    if (!i_rstn) 
        begin
            et1_reg<=0;
            et2_reg<=0;
        end
    else 
        begin
            et1_reg<=et0_wire;
            et2_reg<=et1_reg;
        end
    end

// --- 乘法器 pipeline stage3: inner 7 stages ---
wire [Width*2-1:0] mult0_wire,mult1_wire,mult2_wire;
Booth_Multiplier16 #(.Width(Width), .Stage(Stage)) booth_multiplier0(
    .i_clkp             (i_clkp     ),
    .i_rstn             (i_rstn     ),
    .i_multa            (et0_wire   ),// Multiplicand 
    .i_multb            (i_k0       ),// Multiplier

    .o_product          (mult0_wire )
    );
Booth_Multiplier16 #(.Width(Width), .Stage(Stage)) booth_multiplier1(
    .i_clkp             (i_clkp     ),
    .i_rstn             (i_rstn     ),
    .i_multa            (et1_reg    ),// Multiplicand 
    .i_multb            (i_k1       ),// Multiplier

    .o_product          (mult1_wire )
    );
Booth_Multiplier16 #(.Width(Width), .Stage(Stage)) booth_multiplier2(
    .i_clkp             (i_clkp     ),
    .i_rstn             (i_rstn     ),
    .i_multa            (et2_reg    ),// Multiplicand 
    .i_multb            (i_k2       ),// Multiplier

    .o_product          (mult2_wire )
    );

// --- 加法器 stage4: inner 2 stages---
wire [Width*2-1:0] add0_wire,add1_wire;
Full_Ahead_3Adder #(.Width(Width*2), .Stage(Stage)) full_adder3_0(
    .i_clkp     (i_clkp         ),
    .i_rstn     (i_rstn         ),
    //.i_c        (1'b0           ),
    .i_z        (mult0_wire     ),
    .i_a        (mult1_wire     ), // 被加??
    .i_b        (mult2_wire     ), // 加数
    .o_d        (add0_wire      ), // 
    .o_c        (),
    .o_gm       (),
    .o_pm       ()
    );

// --- 加法器 stage5: inner 1 stage---
reg [Width*2-1:0] out_last2_reg;
Full_Ahead_2Adder #(.Width(Width*2), .Stage(0)) full_adder_0(
    .i_clkp     (i_clkp         ),
    .i_rstn     (i_rstn         ),
    .i_c        (1'b0           ),
    .i_a        (out_last2_reg  ), // 加数2
    .i_b        (add0_wire      ), // 加数3
    .o_d        (add1_wire      ), // 和;
    .o_c        (),
    .o_gm       (),
    .o_pm       ()
    );
// --- 输出寄存器 stage6 : inner 1 stage---

always @ (posedge i_clkp or negedge i_rstn)
    begin
    if (!i_rstn) 
        begin
            out_last2_reg<=0;
        end
    else 
        begin
            out_last2_reg<=add1_wire;
        end
        
    end
// Out 1. 根据需要对输出结果进行移位缩放操作
// assign o_ut=out_last2_reg; // 上两次次以的结果作为输出

wire [Shift-1:0] shift_rwire;
pipelineto #(.Width(Shift), .Stage(Stage*7)) inst_pipelinetoshort(// 为了对齐i_shift与最终结果的流水线（事实上i_shift一般不会动态变化，不过还是设置好）
    .i_clkp(i_clkp), .i_rstn(i_rstn),// 没数错的话应该是7级流水线，乘法器5级，3加器1级，最后加法器时延1级。真的用到了不对的话再调整。
    .i_a(i_shift),
    .o_a(shift_rwire));

wire [Width*4-1:0] long_wire={{(Width*2){out_last2_reg[Width*2-1]}},out_last2_reg};// 将结果有符号拓展到64位准备输出连接
wire [Width*2-1:0] short_wire;// 由于涉及比较，偷个懒，这里声明一下是有符号数，不自己再写模块了; 比较模块内部解决，不必声明了
Shift_Connecter #(.L_width(Width*4),.S_width(Width*2),.Stage(1),.Shift_word(Shift)) inst_shift_connecter(
    .i_clkp(i_clkp), .i_rstn(i_rstn),
    .i_long(long_wire),// 先将结果拓展为64位，然后通过Shift来选择连接位数
    .i_shift(shift_rwire),
    .o_short(short_wire));

// Out 2. 根据需要对PID进行限幅操作
Amplitude_Limit #(.Width(Width*2), .Stage(1)) limit_out(
    .i_clkp     (i_clkp     ),
    .i_rstn     (i_rstn     ),
    .i_data     (short_wire ),
    .i_min      (i_min      ),
    .i_max      (i_max      ),

    .o_data     (o_ut)
);
// assign o_ut=short_reg;// out_last2_reg
endmodule
/*
module Amplitude_Limit #(
    parameter Width = 16*2,
    parameter Stage = 0
    )(
    input  wire                     i_clkp  ,
    input  wire                     i_rstn  ,
    input  wire signed [Width-1:0]  i_data  ,// 输入数据
    input  wire signed [Width-1:0]  i_min   ,// 最小限幅
    input  wire signed [Width-1:0]  i_max   ,// 最大限幅

    output wire [Width-1:0]         o_data   // 限幅输出
);
wire signed [Width-1:0] data_wire=i_data; // 输入数据信号，后续可能会用来添加成流水线
reg  [Width-1:0] data_reg;
always @ (posedge i_clkp or negedge i_rstn)
    begin// 注：这里的有符号数比较采用了编译器自带的模块，注意参与比较的数声明要匹配。
        if (!i_rstn | i_min>=i_max)
            begin// 如果限制的最小值比最大值大，输出全0; 如果重置，输出全0
                data_reg<={(Width){1'b0}};
            end
        else if (i_min=={(Width){1'b0}}&i_max=={(Width){1'b0}})
            begin// 默认寄存器值为0，当最低和最高限制都为0时，说明没有设置限幅，直接输出
                data_reg<=data_wire;
            end
        
        else
            begin// 有限幅设置，按照限幅设置，超出则拉回
                if (data_wire<i_min)
                    begin
                        data_reg<=i_min; 
                    end
                else if (data_wire>i_max)
                    begin
                        data_reg<=i_max;
                    end
                else
                    begin
                        data_reg<=data_wire;
                    end 
            end
    end
// 将限幅后的结果输出，可以通过Stage选择是否插入流水线
pipelineto #(.Width(Width), .Stage(Stage)) pipeto_final(
    .i_clkp(i_clkp), .i_rstn(i_rstn),
    .i_a(data_reg),
    .o_a(o_data));
endmodule
*/