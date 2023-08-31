`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: SUSTech
// Engineer: Daojie.PENG@outlook.com
// 
// Create Date: 20230316 09:42:48
// Design Name: 
// Module Name: IIR Filter 16bit
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
//            
// Dependencies: 
// 
// Revision:
// Revision 0.02 - change adder turns
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module IIR_Filter32 #(
    parameter N_order=4  , // capable Order of IIR filter, it can be 4, 8, 
    parameter N_scale=24, // scale bits
    parameter Width = 32,   // bit width of the filter input and output, can't change
    parameter Stage = 0)(// inner pipeline, for this filter, it must be 0 and can not be changed.
  input  wire                               i_clkp      ,
  input  wire                               i_rstn      ,
  input  wire        [Width*N_order-1:0]    i_factor_a  , // N_order factor a for y[n]
  input  wire        [Width*N_order-1:0]    i_factor_b  , // N_order factor b for x[n]
  input  wire        [Width-1:0]            i_filter    ,

  output wire        [Width-1:0]            o_filter    
  );
localparam WWidth=Width*2;
localparam N_input=6;// 内部计算时所有中间数值都扩大2^N_input倍，防止refactor时被过多截断而导致无法起振
//localparam n_b=15;
/*
n-N_order recursive filter use n delay of input and output;

The general diference equation for recursive filters is:
    a_0*y[n]+a_1*y[n-1]+...+a_i*y[n-i] = b_0*x[n]+b_1*x[n-1]+...+b_j*x[n-j], 
    the biggest i or j defines the order which is order=max(i, j), i and j are integers.

*/
wire [Width*N_order-1:0] factor_a_rwire, factor_b_rwire;// 对于外部的输入还是有必要pipe一下的，快慢时钟匹配问题。
wire [Width-1:0] filter_in_rwire; // pipeline input of filter ;factor a and b is not time-varying, so no need for pipeline
pipelineto  #(.Width(Width*(N_order*2+1)),.Stage(1)) lineto_input(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a({i_factor_a, i_factor_b, i_filter}),// refactor of filter_wire >>>N_input
  .o_a({factor_a_rwire, factor_b_rwire, filter_in_rwire})
  );

// Buffer register for xn
reg [Width*N_order-1:0]       xn_reg;
always @ (posedge i_clkp or negedge i_rstn)
    begin // the x[n] shift register which surves value x[n], x[n-1], ... , x[0]
        if (!i_rstn) 
            begin
                xn_reg<=0;
            end
        else 
            begin// {(16-N_input){filter_in_rwire[Width-1]}} ,
                xn_reg<={xn_reg, filter_in_rwire[Width-N_input-1:0], {N_input{1'b0}}};
            end
    end

// Buffer register for xn
wire [Width-1:0] filter_wire;
reg  [Width*N_order-1:0]      yn_reg;
always @ (posedge i_clkp or negedge i_rstn)
    begin // the y[n] shift register which surves value y[n], y[n-1], ... , y[0]
        if (!i_rstn) 
            begin
                yn_reg<=0;
            end
        else 
            begin
                yn_reg<={yn_reg, filter_wire};
            end
    end


// generate N_order-pairs multipliers for y[n] and x[n]

wire [WWidth*N_order-1:0]     b_xn_wire;
wire [WWidth*N_order-1:0]     a_yn_wire;
generate
    genvar i;
    for (i = 0; i < N_order; i = i + 1)
        begin: IIR_filter // calculate the  y[n] and x[n] factored by a and b respectively
            Booth_Multiplier32 #(.Stage(Stage)) y_n(// multiplier for y[n]
                .i_clkp         (i_clkp     ),
                .i_rstn         (i_rstn     ),
                //.i_f_multa_ns   (1'b1       ),
                //.i_f_multb_ns   (1'b1       ),
                .i_multa        (factor_a_rwire [(i+1)*Width-1:i*Width]    ),
                .i_multb        (yn_reg     [(i+1)*Width-1:i*Width]    ),
                .o_product      (a_yn_wire   [(i+1)*WWidth-1:i*WWidth] )
                );
            Booth_Multiplier32 #(.Stage(Stage)) x_n(// multiplier for x[n]
                .i_clkp         (i_clkp     ),
                .i_rstn         (i_rstn     ),
                //.i_f_multa_ns   (1'b1       ),
                //.i_f_multb_ns   (1'b1       ),
                .i_multa        (factor_b_rwire [(i+1)*Width-1:i*Width]    ),
                .i_multb        (xn_reg     [(i+1)*Width-1:i*Width]    ),
                .o_product      (b_xn_wire   [(i+1)*WWidth-1:i*WWidth] )
                );
        end
endgenerate

// 考虑到两者缩放范围不??样，??要先分别计算x[n]和y[n]的和，经过缩放后??后相加???
wire [WWidth-1:0] suma_wire, sumb_wire;
Full_Ahead_4Adder #(.Width(WWidth), .Stage(Stage)) add_a(
    .i_clkp         (i_clkp     ),
    .i_rstn         (i_rstn     ),
    .i_c            (1'b0       ),
    .i_y            (a_yn_wire[WWidth*1-1:0]        ),
    .i_z            (a_yn_wire[WWidth*2-1:WWidth*1] ),
    .i_a            (a_yn_wire[WWidth*3-1:WWidth*2] ),
    .i_b            (a_yn_wire[WWidth*4-1:WWidth*3] ),
    .o_d            (suma_wire                      ),
    .o_c            (),
    .o_gm           (),
    .o_pm           ()
    );
Full_Ahead_4Adder #(.Width(WWidth), .Stage(Stage)) add_b(
    .i_clkp         (i_clkp     ),
    .i_rstn         (i_rstn     ),
    .i_c            (1'b0       ),
    .i_y            (b_xn_wire[WWidth*1-1:0]        ),
    .i_z            (b_xn_wire[WWidth*2-1:WWidth*1] ),
    .i_a            (b_xn_wire[WWidth*3-1:WWidth*2] ),
    .i_b            (b_xn_wire[WWidth*4-1:WWidth*3] ),
    .o_d            (sumb_wire                      ),
    .o_c            (),
    .o_gm           (),
    .o_pm           ()
    );
wire [Width-1:0] sum_wire;
Full_Ahead_2Adder #(.Width(Width),.Stage(Stage)) add_final(// final addition to produce 'sum_wire'
    .i_clkp         (i_clkp         ),
    .i_rstn         (i_rstn         ),
    .i_c            (1'b0           ),// sign(1) + data(31)
    .i_a            (suma_wire[N_scale+Width-1:N_scale]      ),// refactor of sum a>>>n_a{suma_wire[WWidth-1], suma_wire[n_a+Width-2:n_a]}
    .i_b            (sumb_wire[N_scale+Width-1:N_scale]      ),// refactor of sum b>>>n_b{sumb_wire[WWidth-1], sumb_wire[n_b+Width-2:n_b]}
    .o_d            (sum_wire       ),
    .o_c            (),
    .o_gm           (),
    .o_pm           ()
    );

pipelineto  #(.Width(Width),.Stage(Stage)) lineto_feedback(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a(sum_wire),// refactor of filter_wire >>>N_input[N_scale+Width-1:N_scale]
  .o_a(filter_wire)
  );
//assign filter_wire=sum_wire[N_scale+Width-1:N_scale];//;sum_wire>>>N_scale
/*
always @ (posedge i_clkp or negedge i_rstn)
    begin// 防止本应该为零的数，被截取成了-1；
        if (sum_wire[N_scale+Width-1:N_scale]==32'hffff_ffff)
            begin
                filter_wire<=-32'b1; // 如果截取的全为负的符号位，则将其认为是-1
            end
        else 
            begin// -sum_wire[Width-1]: 对于正数直接抛掉小数位；对于负数抛掉小数位后再-1。总体相当于取floor()
                filter_wire<=sum_wire[N_scale+Width-1:N_scale]-sum_wire[Width-1];//;sum_wire>>>N_scale
            end
    end
*/
pipelineto  #(.Width(Width),.Stage(1)) lineto_output(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a({{(N_input){filter_wire[Width-1]}}, filter_wire[Width-1:N_input]}),// refactor of filter_wire >>>N_input
  .o_a(o_filter)
  );

// assign o_filter=sum_wire; // a(0, 1) is scaled to a(0,2^15) before caculation, now scale the result back here


endmodule

