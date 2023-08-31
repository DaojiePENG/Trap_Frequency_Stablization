`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: SUSTech
// Engineer: Daojie.PENG@qq.com
// 
// Create Date: 2022/09/15 20:42:18
// Design Name: half adder
// Module Name: half_adder
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


module half_adder(
    input  wire i_a, // augend
    input  wire i_b, // addend

    output wire o_d, // sum out
    output wire o_c  // carray out
    );
    assign o_d = i_a ^ i_b;
    assign o_c = i_a & i_b;
endmodule


//////////////////////////////////////////////////////////////////////////////////
// Company: SUSTech
// Engineer: Daojie.PENG@qq.com
// 
// Create Date: 2022/09/15 20:46:40
// Design Name: full adder
// Module Name: full_adder
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


module full_adder(
    input  wire i_a, // augend
    input  wire i_b, // addend
    input  wire i_c, // carry in

    output wire o_d, // sum out
    output wire o_c  // carray out
    );
    assign o_d  = i_a ^ i_b ^ i_c;
    //assign o_c = (i_a & i_b) | (i_a & i_c) | (i_b & i_c);
    assign o_c =i_a & i_b | i_c & (i_a ^ i_b);
endmodule


//////////////////////////////////////////////////////////////////////////////////
// Company: SUSTech
// Engineer: Daojie.PENG@outlook.com
// 
// Create Date: 2022/12/16 16:32:20
// Design Name: 
// Module Name: full_adder5to3
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


module full_adder5to3(
    input   wire  i_0   ,// data1
    input   wire  i_1   ,// data2
    input   wire  i_2   ,// data3
    input   wire  i_3   ,// data4
    input   wire  i_c   ,// carray in

    output  wire  o_d   ,// data out
    output  wire  o_c1  ,// carray out1
    output  wire  o_c2   // carray out2
    );
    wire s_temp = i_0^i_1^i_2^i_3;
    assign o_d  = i_c^s_temp;
    assign o_c1  = (i_c&s_temp) | ~(s_temp | ~((i_0&i_1) | (i_2&i_3)));
    assign o_c2 = (i_0|i_1) & (i_2|i_3);
endmodule


//////////////////////////////////////////////////////////////////////////////////
// Company: SUSTech
// Engineer: Daojie.PENG@outlook.com
// 
// Create Date: 2023/03/18 2:12:24
// Design Name: 
// Module Name: pipelineto
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: pipeline several stages from input to output
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


// pure line, input 1 ouput 1, for easy pipeline
module pipelineto #(
    parameter Width=32,
    parameter Stage=0)(// stages of pipeline
    input               i_clkp  , 
    input               i_rstn  , 
    input  [Width-1:0]  i_a     ,// input data

    output [Width-1:0]  o_a      // pipelined data
    );

    wire [Width-1:0] a_wire; // middle wire for i_a
    generate// generate pipeline satges for finnal outputs
        if (Stage==0)// no pipeline
            begin
                assign a_wire=i_a;
            end
        else if (Stage>0)
            begin
                reg [Width*Stage-1:0] a_buffer_reg; // Stage-th reg for pieplining i_a
                always @ (posedge i_clkp or negedge i_rstn)
                    begin// Satge-th pipelines for i_a
                        if (!i_rstn) 
                            begin
                                a_buffer_reg<=0;
                            end
                        else 
                            begin
                                a_buffer_reg<={ a_buffer_reg, i_a}; // add new i_a to LSB
                            end
                    end
                assign a_wire=a_buffer_reg[Width*Stage-1:Width*(Stage-1)];// line MSB to output 
            end
    endgenerate

    assign o_a=a_wire;// 将输入的数据不做任何处理直接连接输出
endmodule

// carray save adder, input 2 ouput 2
module add2to2_encoder #(
    parameter Width=32,
    parameter Stage=0)(
    input               i_clkp  , 
    input               i_rstn  , 
    input  [Width-1:0]  i_a     , // data1
    input  [Width-1:0]  i_b     , // data2

    output [Width-1:0]  o_d     , // data out
    output [Width-1:0]  o_c       // carry out
    );
    wire [Width-1:0] d_wire,c_wire; // 进位保留加法结果；
    generate// 1.输入三个加数，输出二个结果；
        genvar i;
        for (i = 0; i < Width; i = i + 1)
            begin: add2to2_gene
                half_adder uut(
                .i_a    (i_a[i]       ),
                .i_b    (i_b[i]       ),

                .o_d    (d_wire[i]    ),
                .o_c    (c_wire[i]    )// it is 1 bit higher than o_d
                );
            end
    endgenerate
    wire [Width-1:0] d1_wire,c1_wire; // 流水线后的进位保留加法结果；
    pipelineto #(.Width(Width*2), .Stage(Stage)) lineto_1(// possible pipeline for final results
      .i_clkp(i_clkp), .i_rstn(i_rstn), 
      .i_a({d_wire,c_wire}), .o_a({d1_wire,c1_wire}));

    assign o_d=d1_wire;
    assign o_c=c1_wire;
endmodule

// carray save adder, input 3 ouput 2
module add3to2_encoder #(
    parameter Width=32,
    parameter Stage=0)(
    input               i_clkp  , 
    input               i_rstn  , 
    input  [Width-1:0]  i_a     ,// data1
    input  [Width-1:0]  i_b     ,// data2
    input  [Width-1:0]  i_c     ,

    output [Width-1:0]  o_d     , // data out
    output [Width-1:0]  o_c       // carry out
    );
    wire [Width-1:0] d_wire,c_wire; // 进位保留加法结果；
    generate// 1.输入三个加数，输出二个结果；
        genvar i;
        for (i = 0; i < Width; i = i + 1)
            begin: add3to2_gene
                full_adder uut(
                .i_a    (i_a[i]       ),// data1
                .i_b    (i_b[i]       ),// data2
                .i_c    (i_c[i]       ),

                .o_d    (d_wire[i]    ),
                .o_c    (c_wire[i]    ) // it is 1 bit higher than o_d
                );
            end
    endgenerate
    wire [Width-1:0] d1_wire,c1_wire; // 流水线后的进位保留加法结果；
    pipelineto #(.Width(Width*2), .Stage(Stage)) lineto_1(// possible pipeline for final results
      .i_clkp(i_clkp), .i_rstn(i_rstn), 
      .i_a({d_wire,c_wire}), .o_a({d1_wire,c1_wire}));

    assign o_d=d1_wire;
    assign o_c=c1_wire;
endmodule

// adder 4 inputs to 2 outputs
module add4to2_encoder #(
    parameter Width=32,
    parameter Stage=0)(
    input  wire                 i_clkp  , 
    input  wire                 i_rstn  ,
    input  wire                 i_c     ,
    input  wire [Width-1:0]     i_y     , // data1
    input  wire [Width-1:0]     i_z     , // data2
    input  wire [Width-1:0]     i_a     , // data3
    input  wire [Width-1:0]     i_b     , // data4

    output wire [Width-1:0]     o_d     , // data out
    output wire [Width-1:0]     o_c       // carry out
    );

    wire [Width-1:0] d_wire,c_wire;
    wire [Width:0] c2_wire; // 进位保留加法结果；
    assign c2_wire[0]=i_c;
    generate// 1.输入四个加数，输出三个结果；
        genvar i;
        for (i = 0; i < Width; i = i + 1)
            begin: full_adder4_gene
            full_adder5to3 uut(
                .i_0    (i_y[i]         ),// data1
                .i_1    (i_z[i]         ),// data2
                .i_2    (i_a[i]         ),// data3
                .i_3    (i_b[i]         ),// data4
                .i_c    (c2_wire[i]   ),// c2_wire is only for inner cascade conection

                .o_d    (d_wire[i]      ),
                .o_c1   (c_wire[i]      ),
                .o_c2   (c2_wire[i+1]     ) // c2_wire is only for inner cascade conection
                );
/*
            if (i==0) 
                begin
                    full_adder5to3 uut(
                    .i_0    (i_y[i]         ),// data1
                    .i_1    (i_z[i]         ),// data2
                    .i_2    (i_a[i]         ),// data3
                    .i_3    (i_b[i]         ),// data4
                    .i_c    (i_c            ),

                    .o_d    (d_wire[i]      ),
                    .o_c1   (c_wire[i]      ),// it is 1 bit higher than o_d
                    .o_c2   (c2_wire[i]     ) // c2_wire is only for inner cascade conection
                    );
                end
            else 
                begin
                    full_adder5to3 uut(
                    .i_0    (i_y[i]         ),// data1
                    .i_1    (i_z[i]         ),// data2
                    .i_2    (i_a[i]         ),// data3
                    .i_3    (i_b[i]         ),// data4
                    .i_c    (c2_wire[i-1]   ),// c2_wire is only for inner cascade conection

                    .o_d    (d_wire[i]      ),
                    .o_c1   (c_wire[i]      ),
                    .o_c2   (c2_wire[i]     ) // c2_wire is only for inner cascade conection
                    );
                end*/
            end
            
    endgenerate
    wire [Width-1:0] d1_wire,c1_wire; // 流水线后的进位保留加法结果；
    pipelineto #(.Width(Width*2), .Stage(Stage)) lineto_1(// possible pipeline for final results
      .i_clkp(i_clkp), .i_rstn(i_rstn), 
      .i_a({d_wire,c_wire}), .o_a({d1_wire,c1_wire}));
    assign o_d=d1_wire;
    assign o_c=c1_wire;
endmodule

//////////////////////////////////////////////////////////////////////////////////
// Company: SUSTech
// Engineer: Daojie.PENG@outlook.com
// 
// Create Date: 2023年5月10日17:50:05
// Design Name: 
// Module Name: Amplitude_Limit
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Amplitude_Limit
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module Amplitude_Limit #(
    parameter Width = 16*2,
    parameter Stage = 0
    )(
    input  wire                     i_clkp  ,
    input  wire                     i_rstn  ,
    input  wire signed [Width-1:0]  i_data  ,// 输入数据，由于涉及比较，偷个懒，这里声明一下是有符号数，不自己再写模块了;
    input  wire signed [Width-1:0]  i_min   ,// 最小限幅，由于涉及比较，偷个懒，这里声明一下是有符号数，不自己再写模块了;
    input  wire signed [Width-1:0]  i_max   ,// 最大限幅，由于涉及比较，偷个懒，这里声明一下是有符号数，不自己再写模块了;

    output wire [Width-1:0]         o_data   // 限幅输出
    );
wire signed [Width-1:0] data_wire=i_data; // 输入数据信号，后续可能会用来添加成流水线
reg  [Width-1:0] data_reg;
always @ (posedge i_clkp or negedge i_rstn)
    begin// 注：这里的有符号数比较采用了编译器自带的模块，注意参与比较的数声明要匹配。
        if (!i_rstn | i_min>i_max)
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
// 将限幅后的结果输出，可以通过Stage选择输出是否插入流水线
pipelineto #(.Width(Width), .Stage(Stage)) pipeto_final(
    .i_clkp(i_clkp), .i_rstn(i_rstn),
    .i_a(data_reg),
    .o_a(o_data));
endmodule