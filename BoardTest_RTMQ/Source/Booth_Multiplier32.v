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
// Dependencies: booth_r4_encoder, comtree_3to2
// 
// Revision:
// Revision 0.01 - File Created
// Revision 0.02 - add pipeline choice for design, 2023年3月19日14:13:29
// Revision 0.03 - update encoder4to2, add 'i_c', 2023年3月29日12:17:31
// Additional Comments:
// Reference： https://zhuanlan.zhihu.com/p/127164011?utm_source=wechat_session&utm_medium=social&utm_oi=40876629819392&utm_campaign=shareopn
//////////////////////////////////////////////////////////////////////////////////

module Booth_Multiplier32 #(
/*
功能： 实现32位乘法，总流水线数=Stage*3+adder_pipe, default adder_pipe=1;
*/
  parameter Width = 32,// can not be changed
  parameter Stage = 1)(// stage pipelines of each comtree stage, normally 1 is enough
  input                     i_clkp       ,
  input                     i_rstn       ,
  //input  wire               i_f_multa_ns ,// 0-i_multa is usigned, 1-i_multa is signed, not necessary for 32bit design
  //input  wire               i_f_multb_ns ,// 0-i_multb is usigned, 1-i_multb is signed, not necessary for 32bit design
  input  wire [Width-1:0]   i_multa      ,// Multiplicand 
  input  wire [Width-1:0]   i_multb      ,// Multiplier

  output wire [Width*2-1:0] o_product     // product of multa and multb
  );

// internal connection
// partical product
wire [Width:0] pp01_wire, pp02_wire, pp03_wire, pp04_wire, pp05_wire, pp06_wire, pp07_wire, pp08_wire;
wire [Width:0] pp09_wire, pp10_wire, pp11_wire, pp12_wire, pp13_wire, pp14_wire, pp15_wire, pp16_wire;
wire [Width*2-1:0] product_wire; // final product for o_product connection

// booth encoder to get the part products
booth_r4_encoder32 u_booth_r4(
  //.i_f_multa_ns   (i_f_multa_ns ),
  //.i_f_multb_ns   (i_f_multb_ns ),
  .i_multa        (i_multa      ),
  .i_multb        (i_multb      ),
  .o_pp01         (pp01_wire    ),
  .o_pp02         (pp02_wire    ),
  .o_pp03         (pp03_wire    ),
  .o_pp04         (pp04_wire    ),
  .o_pp05         (pp05_wire    ),
  .o_pp06         (pp06_wire    ),
  .o_pp07         (pp07_wire    ),
  .o_pp08         (pp08_wire    ),
  .o_pp09         (pp09_wire    ),
  .o_pp10         (pp10_wire    ),
  .o_pp11         (pp11_wire    ),
  .o_pp12         (pp12_wire    ),
  .o_pp13         (pp13_wire    ),
  .o_pp14         (pp14_wire    ),
  .o_pp15         (pp15_wire    ),
  .o_pp16         (pp16_wire    )
);

/*===================================================================
根据加法树表将booth编码后的信号连接起来，一共四级操作：
  第一级输入16个部分积，通过四加器转化为8个数据（4个数据结果，4个进位结果）；
  第二级输入8个数据，通过四加器转化为4个数据（2个数据结果，2个进位结果）；
  第三级输入4个数据，通过四加器转化为2个数据（1个数据结果，1个进位结果）；
  第四级输入2个数据，通过四全加器转化为1个数据结果（最终结果）。
for effeciency, we use add4to2_encoder only necessary
=====================================================================*/ 
// ------ stage1 ------
// midlle results of first stage
wire [38:0] mr_d11_wire, mr_c11_wire, mr_d12_wire, mr_c12_wire, mr_d13_wire, mr_c13_wire, mr_d14_wire, mr_c14_wire;
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
add3to2_encoder #(.Width(2),.Stage(Stage)) add3to2_stg11(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a(pp01_wire  [5:4]),   
  .i_b(pp02_wire  [3:2]), 
  .i_c(pp03_wire  [1:0]), 
  .o_d(mr_d11_wire[5:4]),   .o_c(mr_c11_wire[5:4])
  );
add4to2_encoder #(.Width(33),.Stage(Stage)) add4to2_stg11(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_c(1'b0),
  .i_y({{6{pp01_wire[32]}}, pp01_wire[32:6]}      ), // sign extend
  .i_z({{4{pp02_wire[32]}}, pp02_wire[32:4]}      ), // sign extend
  .i_a({{2{pp03_wire[32]}}, pp03_wire[32:2]}      ), // sign extend
  .i_b(                     pp04_wire[32:0]       ), 
  .o_d(mr_d11_wire[38:6]),  .o_c(mr_c11_wire[38:6])
  );

// 0.2->1.1
pipelineto  #(.Width(2),.Stage(Stage)) lineto_stg12(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a(pp05_wire  [1:0]   ),
  .o_a(mr_d12_wire[1:0]   )
  );
add2to2_encoder #(.Width(2),.Stage(Stage)) add2to2_stg12(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a(pp05_wire  [3:2]),   
  .i_b(pp06_wire  [1:0]), 
  .o_d(mr_d12_wire[3:2]),   .o_c(mr_c12_wire[3:2])
  );
add3to2_encoder #(.Width(2),.Stage(Stage)) add3to2_stg12(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a(pp05_wire  [5:4]),   
  .i_b(pp06_wire  [3:2]), 
  .i_c(pp07_wire  [1:0]), 
  .o_d(mr_d12_wire[5:4]),   .o_c(mr_c12_wire[5:4])
  );
add4to2_encoder #(.Width(33),.Stage(Stage)) add4to2_stg12(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_c(1'b0),
  .i_y({{6{pp05_wire[32]}}, pp05_wire[32:6]}      ), // sign extend
  .i_z({{4{pp06_wire[32]}}, pp06_wire[32:4]}      ), // sign extend
  .i_a({{2{pp07_wire[32]}}, pp07_wire[32:2]}      ), // sign extend
  .i_b(                     pp08_wire[32:0]       ), 
  .o_d(mr_d12_wire[38:6]),  .o_c(mr_c12_wire[38:6])
  );

// 0.3->1.2
pipelineto  #(.Width(2),.Stage(Stage)) lineto_stg13(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a(pp09_wire  [1:0]   ),
  .o_a(mr_d13_wire[1:0]   )
  );
add2to2_encoder #(.Width(2),.Stage(Stage)) add2to2_stg13(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a(pp09_wire  [3:2]),   
  .i_b(pp10_wire  [1:0]), 
  .o_d(mr_d13_wire[3:2]),   .o_c(mr_c13_wire[3:2])
  );
add3to2_encoder #(.Width(2),.Stage(Stage)) add3to2_stg13(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a(pp09_wire  [5:4]),   
  .i_b(pp10_wire  [3:2]), 
  .i_c(pp11_wire  [1:0]), 
  .o_d(mr_d13_wire[5:4]),   .o_c(mr_c13_wire[5:4])
  );
add4to2_encoder #(.Width(33),.Stage(Stage)) add4to2_stg13(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_c(1'b0),
  .i_y({{6{pp09_wire[32]}}, pp09_wire[32:6]}      ), // sign extend
  .i_z({{4{pp10_wire[32]}}, pp10_wire[32:4]}      ), // sign extend
  .i_a({{2{pp11_wire[32]}}, pp11_wire[32:2]}      ), // sign extend
  .i_b(                     pp12_wire[32:0]       ), 
  .o_d(mr_d13_wire[38:6]),  .o_c(mr_c13_wire[38:6])
  );

// 0.4->1.2
pipelineto  #(.Width(2),.Stage(Stage)) lineto_stg14(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a(pp13_wire  [1:0]   ),
  .o_a(mr_d14_wire[1:0]   )
  );
add2to2_encoder #(.Width(2),.Stage(Stage)) add2to2_stg14(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a(pp13_wire  [3:2]),   
  .i_b(pp14_wire  [1:0]), 
  .o_d(mr_d14_wire[3:2]),   .o_c(mr_c14_wire[3:2])
  );
add3to2_encoder #(.Width(2),.Stage(Stage)) add3to2_stg14(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a(pp13_wire  [5:4]),   
  .i_b(pp14_wire  [3:2]), 
  .i_c(pp15_wire  [1:0]), 
  .o_d(mr_d14_wire[5:4]),   .o_c(mr_c14_wire[5:4])
  );
add4to2_encoder #(.Width(33),.Stage(Stage)) add4to2_stg14(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_c(1'b0),
  .i_y({{6{pp13_wire[32]}}, pp13_wire[32:6]}      ), // sign extend
  .i_z({{4{pp14_wire[32]}}, pp14_wire[32:4]}      ), // sign extend
  .i_a({{2{pp15_wire[32]}}, pp15_wire[32:2]}      ), // sign extend
  .i_b(                     pp16_wire[32:0]       ), 
  .o_d(mr_d14_wire[38:6]),  .o_c(mr_c14_wire[38:6])
  );

assign {mr_c11_wire[1:0], mr_c12_wire[1:0], mr_c13_wire[1:0], mr_c14_wire[1:0]}={4{2'b0}};

// ------ stage2 ------
wire [47:0] mr_d21_wire, mr_c21_wire, mr_d22_wire, mr_c22_wire;
// 1.1->2.1
pipelineto  #(.Width(1),.Stage(Stage)) lineto_stg21(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a(mr_d11_wire[0]   ),
  .o_a(mr_d21_wire[0]   )
  );
add2to2_encoder #(.Width(7),.Stage(Stage)) add2to2_stg21(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a(mr_d11_wire[7:1]),   
  .i_b(mr_c11_wire[6:0]), 
  .o_d(mr_d21_wire[7:1]),   .o_c(mr_c21_wire[7:1])
  );
add3to2_encoder #(.Width(1),.Stage(Stage)) add3to2_stg21(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a(mr_d11_wire[8]),  
  .i_b(mr_c11_wire[7] ),   
  .i_c(mr_d12_wire[0] ), 
  .o_d(mr_d21_wire[8]),    .o_c(mr_c21_wire[8])
  );
add4to2_encoder #(.Width(39),.Stage(Stage)) add4to2_stg21(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_c(1'b0),
  .i_y({{9{mr_d11_wire[38]}}, mr_d11_wire[38:9]}    ), // sign extend
  .i_z({{8{mr_c11_wire[38]}}, mr_c11_wire[38:8]}    ), // sign extend
  .i_a({mr_d12_wire[38],      mr_d12_wire[38:1]}    ), // sign extend
  .i_b(                       mr_c12_wire[38:0]     ), 
  .o_d(mr_d21_wire[47:9]),   .o_c(mr_c21_wire[47:9] )
  );
// 1.2->2.1
pipelineto  #(.Width(1),.Stage(Stage)) lineto_stg22(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a(mr_d13_wire[0]   ),
  .o_a(mr_d22_wire[0]   )
  );
add2to2_encoder #(.Width(7),.Stage(Stage)) add2to2_stg22(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a(mr_d13_wire[7:1]),   
  .i_b(mr_c13_wire[6:0]), 
  .o_d(mr_d22_wire[7:1]),   .o_c(mr_c22_wire[7:1])
  );
add3to2_encoder #(.Width(1),.Stage(Stage)) add3to2_stg22(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a(mr_d13_wire[8]),  
  .i_b(mr_c13_wire[7] ),   
  .i_c(mr_d14_wire[0] ), 
  .o_d(mr_d22_wire[8]),    .o_c(mr_c22_wire[8])
  );
add4to2_encoder #(.Width(39),.Stage(Stage)) add4to2_stg22(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_c(1'b0),
  .i_y({{9{mr_d13_wire[38]}}, mr_d13_wire[38:9]}    ), // sign extend
  .i_z({{8{mr_c13_wire[38]}}, mr_c13_wire[38:8]}    ), // sign extend
  .i_a({mr_d14_wire[38],      mr_d14_wire[38:1]}    ), // sign extend
  .i_b(                       mr_c14_wire[38:0]     ), 
  .o_d(mr_d22_wire[47:9]),   .o_c(mr_c22_wire[47:9] )
  );
assign {mr_c21_wire[0], mr_c22_wire[0]}=2'b0;

// ------ stage3 ------
// 2.1->full_adder
wire [63:0] mr_d31_wire, mr_c31_wire;// carray out is useless so no need for save
pipelineto  #(.Width(1),.Stage(Stage)) lineto_stg3(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a(mr_d21_wire[0]   ),
  .o_a(mr_d31_wire[0]   )
  );
add2to2_encoder #(.Width(15),.Stage(Stage)) add2to2_stg3(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a(mr_d21_wire[15:1]),   
  .i_b(mr_c21_wire[14:0]), 
  .o_d(mr_d31_wire[15:1]), .o_c(mr_c31_wire[15:1])
  );
add3to2_encoder #(.Width(1),.Stage(Stage)) add3to2_stg3(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a(mr_d21_wire[16]),  
  .i_b(mr_c21_wire[15]),   
  .i_c(mr_d22_wire[0]), 
  .o_d(mr_d31_wire[16]),  .o_c(mr_c31_wire[16])
  );
add4to2_encoder #(.Width(47),.Stage(Stage)) add4to2_stg3(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_c(1'b0),
  .i_y({{16{mr_d21_wire[47]}},  mr_d21_wire[47:17]} ), // sign extend
  .i_z({{15{mr_c21_wire[47]}},  mr_c21_wire[47:16]} ), // sign extend
  .i_a(                         mr_d22_wire[47:1]   ), // sign extend
  .i_b(                         mr_c22_wire[46:0]   ), 
  .o_d(mr_d31_wire[63:17]),  .o_c(mr_c31_wire[63:17])
  );


assign mr_c31_wire[0]=1'b0;
// ------ stage4 full adder stage ------
/*
Full_Ahead_2Adder64_P1 #(.Width(64),.Stage(Stage)) final_adder(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_c    (1'b0                       ),
  .i_a    ( mr_d31_wire[63:0]         ),
  .i_b    ({mr_c31_wire[62:0], 1'b0}  ), // shift 1 bit with extend 0.

  .o_d    (product_wire               ),
  .o_c    (),
  .o_gm   (),
  .o_pm   ()
  );
*/
Full_Ahead_2Adder #(.Width(64),.Stage(0)) final_adder(
  .i_clkp (i_clkp                     ), 
  .i_rstn (i_rstn                     ),
  .i_c    (1'b0                       ),
  .i_a    ( mr_d31_wire[63:0]         ),
  .i_b    ({mr_c31_wire[62:0], 1'b0}  ), // shift 1 bit with extend 0.

  .o_d    (product_wire               ),
  .o_c    (),
  .o_gm   (),
  .o_pm   ()
  );
assign o_product = product_wire[Width*2-1:0];// 输出最终结果

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


module booth_r4_encoder32 #(parameter Width = 32)(
  //input  wire               i_f_multa_ns  , // 0-i_multa is unsigned, 1-i_multa is signed, no used
  //input  wire               i_f_multb_ns  , // 0-i_multb is unsigned, 1-i_multb is signed, no used
  input  wire [Width-1:0]   i_multa       , // Multiplicand
  input  wire [Width-1:0]   i_multb       , // Multipler

  output wire [Width:0]     o_pp01        , // partial products 
  output wire [Width:0]     o_pp02        ,
  output wire [Width:0]     o_pp03        ,
  output wire [Width:0]     o_pp04        ,
  output wire [Width:0]     o_pp05        ,
  output wire [Width:0]     o_pp06        ,
  output wire [Width:0]     o_pp07        ,
  output wire [Width:0]     o_pp08        ,
  output wire [Width:0]     o_pp09        ,
  output wire [Width:0]     o_pp10        ,
  output wire [Width:0]     o_pp11        ,
  output wire [Width:0]     o_pp12        ,
  output wire [Width:0]     o_pp13        ,
  output wire [Width:0]     o_pp14        ,
  output wire [Width:0]     o_pp15        ,
  output wire [Width:0]     o_pp16         
  );

// generat -x, -2x, 2x for Booth encoding
wire [Width:0] x     =  {i_multa[Width-1],i_multa};       // extend sign + orignal 
wire [Width:0] x_c   = ~x + 1;         // -x, complement code of x
wire [Width:0] xm2   =  x << 1;        // 2*x
wire [Width:0] x_cm2 =  x_c << 1;      // -2*x

// [32 31 30 ....................  4 3 2 1]     0  
// |--------------------------------------|     |
//      orignal operator             appended bit for encoding
wire [Width:0] y = {i_multb, 1'b0};

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
wire [Width:0] pp[15:0];// 16 part products
generate
    genvar i;
    for (i = 0; i < 32; i = i + 2)
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
assign o_pp10   = pp[ 9];
assign o_pp11   = pp[10];
assign o_pp12   = pp[11];
assign o_pp13   = pp[12];
assign o_pp14   = pp[13];
assign o_pp15   = pp[14];
assign o_pp16   = pp[15];
endmodule

/*
//////////////////////////////////////////////////////////////////////////////////
// Company: SUSTech
// Engineer: Daojie.PENG@qq.com
// 
// Create Date: 2023/03/18 2:12:24
// Design Name: Booth pipelineto
// Module Name: pipelineto, add3to2_encoder, add4to2_encoder
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: multi-bits adders: pipelineto, add3to2_encoder, add4to2_encoder
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// Reference：
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
  input               i_clkp  , 
  input               i_rstn  ,
  input  [Width-1:0]  i_y     , // data1
  input  [Width-1:0]  i_z     , // data2
  input  [Width-1:0]  i_a     , // data3
  input  [Width-1:0]  i_b     , // data4

  output [Width-1:0]  o_d     , // data out
  output [Width-1:0]  o_c       // carry out
  );

wire [Width-1:0] d_wire,c_wire,c2_wire; // 进位保留加法结果；
generate// 1.输入四个加数，输出三个结果；
    genvar i;
    for (i = 0; i < Width; i = i + 1)
        begin: full_adder4_gene
        if (i==0) 
            begin
                full_adder5to3 uut(
                .i_0    (i_y[i]         ),// data1
                .i_1    (i_z[i]         ),// data2
                .i_2    (i_a[i]         ),// data3
                .i_3    (i_b[i]         ),// data4
                .i_c    (1'b0           ),

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
            end
        end
endgenerate
wire [Width-1:0] d1_wire,c1_wire; // 流水线后的进位保留加法结果；
pipelineto #(.Width(Width*2), .Stage(Stage)) lineto_1(// possible pipeline for final results
  .i_clkp(i_clkp), .i_rstn(i_rstn), 
  .i_a({d_wire,c_wire}), .o_a({d1_wire,c1_wire}));
assign o_d=d1_wire;
assign o_c=c1_wire;
endmodule

*/