`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: SUSTech
// Engineer: Daojie.PENG@qq.com
// 
// Create Date: 2023年3月18日2:13:55
// Design Name: 
// Module Name: booth_multiplier 32 bit
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: booth_r4_encoder, comtree_3to2m
// 
// Revision:
// Revision 0.01 - File Created
// Revision 0.02 - add pipeline choice for design, 2023年3月19日14:13:29
// Revision 0.03 - update encoder4to2, add 'i_c', 2023年3月29日12:17:31
// Additional Comments:
// Reference： https://zhuanlan.zhihu.com/p/127164011?utm_source=wechat_session&utm_medium=social&utm_oi=40876629819392&utm_campaign=shareopn
//////////////////////////////////////////////////////////////////////////////////

module Booth_Multiplier16 #(
/*
功能： 实现32位乘法，总流水线数=Stage*3+adder_pipe, default adder_pipe=1;
*/
  parameter Width = 16,// can not be changed
  parameter Stage = 1)(// stage pipelines of each comtree stage, normally 1 is enough
  input                     i_clkp       ,
  input                     i_rstn       ,
  //input  wire               i_f_multa_ns ,// 0-i_multa is usigned, 1-i_multa is signed, not necessary for 32bit design
  //input  wire               i_f_multb_ns ,// 0-i_multb is usigned, 1-i_multb is signed, not necessary for 32bit design
  input  wire [Width-1:0]   i_multa      ,// Multiplicand 
  input  wire [Width-1:0]   i_multb      ,// Multiplier

  output wire [Width*2-1:0] o_product     // product of multa and multb
  );
wire [Width-1:0] multa_wire, multb_wire;
pipelineto  #(.Width(Width*2),.Stage(Stage)) lineto_input(// input piepline 
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a({i_multa,      i_multb}),
  .o_a({multa_wire,   multb_wire})
  );

// internal connection
// partical product
wire [Width+1:0] pp01_wire, pp02_wire, pp03_wire, pp04_wire, pp05_wire, pp06_wire, pp07_wire, pp08_wire, pp09_wire;
wire [Width*2-1:0] product_wire; // final product for o_product connection

// booth encoder to get the part products
booth_r4_encoder16 u_booth_r4(
  //.i_f_multa_ns   (i_f_multa_ns ),
  //.i_f_multb_ns   (i_f_multb_ns ),
  .i_multa        (multa_wire   ),
  .i_multb        (multb_wire   ),
  .o_pp01         (pp01_wire    ),
  .o_pp02         (pp02_wire    ),
  .o_pp03         (pp03_wire    ),
  .o_pp04         (pp04_wire    ),
  .o_pp05         (pp05_wire    ),
  .o_pp06         (pp06_wire    ),
  .o_pp07         (pp07_wire    ),
  .o_pp08         (pp08_wire    ),
  .o_pp09         (pp09_wire    )
);

/*===================================================================
根据加法树表将booth编码后的信号连接起来，一共四级操作：
  第一级输入9个部分积，通过三加器转化为6个数据（3个数据结果，3个进位结果）；
  第二级输入6个数据，通过三加器转化为4个数据（2个数据结果，2个进位结果）；
  第三级输入4个数据，通过四加器转化为2个数据（1个数据结果，1个进位结果）；
  第四级输入2个数据，通过全加器转化为1个数据结果（最终结果）。
for effeciency, we use add4to2_encoder only necessary
=====================================================================*/ 
// --------------------------------------------------------- stage1 ---------------------------------------------------------
// midlle results of first stage
wire [21:0] mr_d11_wire, mr_c11_wire, mr_d12_wire, mr_c12_wire;
wire [19:0] mr_d13_wire, mr_c13_wire;
// 0.1->1.1
pipelineto  #(.Width(2),.Stage(Stage)) lineto_stg11(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a(pp01_wire  [1:0]   ),
  .o_a(mr_d11_wire[1:0]   )
  );
add2to2_encoder #(.Width(2),.Stage(Stage)) add2to2_stg11(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a(pp01_wire  [3:2]),   
  .i_b(pp02_wire  [1:0]), 
  .o_d(mr_d11_wire[3:2]),   .o_c(mr_c11_wire[3:2])
  );
add3to2_encoder #(.Width(18),.Stage(Stage)) add3to2_stg11(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a({{4{pp01_wire[17]}}, pp01_wire  [17:4]}      ),   
  .i_b({{2{pp02_wire[17]}}, pp02_wire  [17:2]}      ), 
  .i_c(                     pp03_wire  [17:0]       ), 
  .o_d(mr_d11_wire[21:4]),   .o_c(mr_c11_wire[21:4] )
  );

// 0.2->1.1
pipelineto  #(.Width(2),.Stage(Stage)) lineto_stg12(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a(pp04_wire  [1:0]   ),
  .o_a(mr_d12_wire[1:0]   )
  );
add2to2_encoder #(.Width(2),.Stage(Stage)) add2to2_stg12(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a(pp04_wire  [3:2]),   
  .i_b(pp05_wire  [1:0]), 
  .o_d(mr_d12_wire[3:2]),   .o_c(mr_c12_wire[3:2])
  );
add3to2_encoder #(.Width(18),.Stage(Stage)) add3to2_stg12(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a({{4{pp04_wire[17]}}, pp04_wire  [17:4]}      ),   
  .i_b({{2{pp05_wire[17]}}, pp05_wire  [17:2]}      ), 
  .i_c(                     pp06_wire  [17:0]       ), 
  .o_d(mr_d12_wire[21:4]),   .o_c(mr_c12_wire[21:4] )
  );

// 0.3->1.1
pipelineto  #(.Width(2),.Stage(Stage)) lineto_stg13(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a(pp07_wire  [1:0]   ),
  .o_a(mr_d13_wire[1:0]   )
  );
add2to2_encoder #(.Width(2),.Stage(Stage)) add2to2_stg13(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a(pp07_wire  [3:2]),   
  .i_b(pp08_wire  [1:0]), 
  .o_d(mr_d13_wire[3:2]),   .o_c(mr_c13_wire[3:2])
  );
add3to2_encoder #(.Width(16),.Stage(Stage)) add3to2_stg13(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a({{2{pp07_wire[17]}}, pp07_wire  [17:4]}      ),   
  .i_b(                     pp08_wire  [17:2]       ), 
  .i_c(                     pp09_wire  [15:0]       ), 
  .o_d(mr_d13_wire[19:4]),   .o_c(mr_c13_wire[19:4] )
  );
assign {mr_c11_wire[1:0], mr_c12_wire[1:0], mr_c13_wire[1:0]}={3{2'b0}};


// --------------------------------------------------------- stage2 ---------------------------------------------------------
wire [31:0] mr_d21_wire, mr_c21_wire;
wire [24:0] mr_d22_wire, mr_c22_wire;
// 1.1->2.1
pipelineto  #(.Width(1),.Stage(Stage)) lineto_stg21(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a(mr_d11_wire[0]   ),
  .o_a(mr_d21_wire[0]   )
  );
add2to2_encoder #(.Width(5),.Stage(Stage)) add2to2_stg21(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a(mr_d11_wire[5:1]),   
  .i_b(mr_c11_wire[4:0]), 
  .o_d(mr_d21_wire[5:1]),   .o_c(mr_c21_wire[5:1])
  );
add3to2_encoder #(.Width(22),.Stage(Stage)) add3to2_stg21(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a({{6{mr_d11_wire[21]}},  mr_d11_wire[21:6]}   ),  
  .i_b({{5{mr_c11_wire[21]}},  mr_c11_wire[21:5]}   ),   
  .i_c(                       mr_d12_wire[21:0]     ), 
  .o_d(mr_d21_wire[27:6]),    .o_c(mr_c21_wire[27:6])
  );

// 1.2->2.1
pipelineto  #(.Width(5),.Stage(Stage)) lineto_stg22(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a(mr_c12_wire[4:0]   ),
  .o_a(mr_d22_wire[4:0]   )
  );
add2to2_encoder #(.Width(1),.Stage(Stage)) add2to2_stg22(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a(mr_c12_wire[5]),   
  .i_b(mr_d13_wire[0]), 
  .o_d(mr_d22_wire[5]),   .o_c(mr_c22_wire[5])
  );
add3to2_encoder #(.Width(19),.Stage(Stage)) add3to2_stg22(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a({{3{mr_c12_wire[21]}},  mr_c12_wire[21:6]}   ),  
  .i_b(                       mr_d13_wire[19:1]     ),   
  .i_c(                       mr_c13_wire[18:0]     ), 
  .o_d(mr_d22_wire[24:6]),    .o_c(mr_c22_wire[24:6])
  );
assign {mr_c21_wire[0], mr_c22_wire[4:0]}=6'b0;


// ---------------------------------------------------------- stage3 ----------------------------------------------------------
// 2.1->full_adder
wire [31:0] mr_d31_wire, mr_c31_wire;
pipelineto  #(.Width(1),.Stage(Stage)) lineto_stg3(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a(mr_d21_wire[0]   ),
  .o_a(mr_d31_wire[0]   )
  );
add2to2_encoder #(.Width(6),.Stage(Stage)) add2to2_stg3(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a(mr_d21_wire[6:1]),   
  .i_b(mr_c21_wire[5:0]), 
  .o_d(mr_d31_wire[6:1]), .o_c(mr_c31_wire[6:1])
  );
add3to2_encoder #(.Width(1),.Stage(Stage)) add3to2_stg3(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a(mr_d21_wire[7]),  
  .i_b(mr_c21_wire[6]),   
  .i_c(mr_d22_wire[0]), 
  .o_d(mr_d31_wire[7]),  .o_c(mr_c31_wire[7])
  );
add4to2_encoder #(.Width(24),.Stage(Stage)) add4to2_stg3(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_c(0'b0),
  .i_y({{4{mr_d21_wire[27]}},   mr_d21_wire[27:8]}  ), // sign extend
  .i_z({{3{mr_c21_wire[27]}},   mr_c21_wire[27:7]}  ), // sign extend
  .i_a(                         mr_d22_wire[24:1]   ), // sign extend
  .i_b(                         mr_c22_wire[23:0]   ), 
  .o_d(mr_d31_wire[31:8]),  .o_c(mr_c31_wire[31:8]  )
  );

// ---------------------------------------------------------- stage4 ----------------------------------------------------------
assign mr_c31_wire[0]=1'b0;
// ------ stage4 full adder stage ------
Full_Ahead_2Adder #(.Width(Width*2)) final_adder(
  .i_clkp (i_clkp                     ),
  .i_rstn (i_rstn                     ),
  .i_c    (1'b0                       ),
  .i_a    ( mr_d31_wire[Width*2-1:0]         ),
  .i_b    ({mr_c31_wire[Width*2-2:0], 1'b0}  ), // shift 1 bit with extend 0.

  .o_d    (product_wire               ),
  .o_c    (),
  .o_gm   (),
  .o_pm   ()
  );

pipelineto  #(.Width(Width*2),.Stage(Stage)) lineto_output(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a(product_wire[Width*2-1:0]),
  .o_a(o_product)
  );
// assign o_product = product_wire[Width*2-1:0];// 输出最终结果

endmodule




//////////////////////////////////////////////////////////////////////////////////
// Company: SUSTech
// Engineer: Daojie.PENG@qq.com
// 
// Create Date: 2022/09/15 21:12:24
// Design Name: Booth Multiplier
// Module Name: booth_r4_encoder
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: booth radix 4 encoder
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// Reference：https://zhuanlan.zhihu.com/p/127164011?utm_source=wechat_session&utm_medium=social&utm_oi=40876629819392&utm_campaign=shareopn
//////////////////////////////////////////////////////////////////////////////////


module booth_r4_encoder16 #(parameter Width = 16)(
  //input  wire               i_f_multa_ns  , // 0-i_multa is unsigned, 1-i_multa is signed, no used
  //input  wire               i_f_multb_ns  , // 0-i_multb is unsigned, 1-i_multb is signed, no used
  input  wire [Width-1:0]   i_multa       , // Multiplicand
  input  wire [Width-1:0]   i_multb       , // Multipler

  output wire [Width+1:0]   o_pp01        , // partial products 
  output wire [Width+1:0]   o_pp02        ,
  output wire [Width+1:0]   o_pp03        ,
  output wire [Width+1:0]   o_pp04        ,
  output wire [Width+1:0]   o_pp05        ,
  output wire [Width+1:0]   o_pp06        ,
  output wire [Width+1:0]   o_pp07        ,
  output wire [Width+1:0]   o_pp08        ,
  output wire [Width+1:0]   o_pp09          
  );

// generat -x, -2x, 2x for Booth encoding
wire [Width+1:0] x     =  {{2{i_multa[Width-1]}},i_multa};       // extend sign + orignal 
wire [Width+1:0] x_c   = ~x + 1;         // -x, complement code of x
wire [Width+1:0] xm2   =  x << 1;        // 2*x
wire [Width+1:0] x_cm2 =  x_c << 1;      // -2*x

//        18 17         [16 15 14 13 12 11 10 9 8 7 6 5 4 3 2 1]     0  
//        |---|          |------------------------------------|      |
// extended sign bits              orignal operator             appended bit for encoding
wire [Width+2:0] y = {{2{i_multb[Width-1]}}, i_multb, 1'b0};

// calculating partial product based on Booth Radix-4 encoding. 

/* Radix-4 Booth Encoder table
// weighting base: 2^(2i)*[-2*y_(2i+1)+y_(2i)+y_(2i-1)]
|----------|----------|--------------|------------| 
|y_(2i+1)  |  y_(2i)  |   y_(2i-1)   |   pp_(i)   | 
|    0     |     0    |      0       |      0     | 
|    0     |     0    |      1       |      x     | 
|    0     |     1    |      0       |      x     | 
|    0     |     1    |      1       |      2x    | 
|    1     |     0    |      0       |      -2x   | 
|    1     |     0    |      1       |      -x    | 
|    1     |     1    |      0       |      -x    | 
|    1     |     1    |      1       |      0     | 
|----------|----------|--------------|------------| 
*/
wire [Width+1:0] pp[8:0];// 16 part products
generate
    genvar i;
    for (i = 0; i < Width+2; i = i + 2)
        begin: gen_pp
            assign pp[i/2] =    (y[i+2:i] == 3'b001 || y[i+2:i] == 3'b010) ? x      :
                                (y[i+2:i] == 3'b101 || y[i+2:i] == 3'b110) ? x_c    :
                                (y[i+2:i] == 3'b011                      ) ? xm2    :
                                (y[i+2:i] == 3'b100                      ) ? x_cm2  :33'b0;
        end
endgenerate

// assign {opp_16, opp_15, ..., o_pp09, o_pp08, o_pp07, o_pp06, o_pp05, o_pp04, o_pp03, o_pp02, o_pp01} = pp;
assign o_pp01   = pp[ 0];
assign o_pp02   = pp[ 1];
assign o_pp03   = pp[ 2];
assign o_pp04   = pp[ 3];
assign o_pp05   = pp[ 4];
assign o_pp06   = pp[ 5];
assign o_pp07   = pp[ 6];
assign o_pp08   = pp[ 7];
assign o_pp09   = pp[ 8];

endmodule

