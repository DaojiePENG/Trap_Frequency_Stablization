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


module IIR_Filter16 #(
    parameter N_order=4  , // capable Order of IIR filter, it can be 4, 8, 
    parameter Width = 16   // bit width of the filter input and output, can't change
    )(
  input  wire                               i_clkp      ,
  input  wire                               i_rstn      ,
  input  wire        [Width*N_order-1:0]    i_factor_a  , // N_order factor a for y[n]
  input  wire        [Width*N_order-1:0]    i_factor_b  , // N_order factor b for x[n]
  input  wire signed [Width-1:0]            i_filter    ,

  output wire signed [Width-1:0]            o_filter    
  );
localparam WWidth=Width*2;
localparam n_a=15;
localparam n_b=15;
/*
n-N_order recursive filter use n delay of input and output;

The general diference equation for recursive filters is:
    a_0*y[n]+a_1*y[n-1]+...+a_i*y[n-i] = b_0*x[n]+b_1*x[n-1]+...+b_j*x[n-j], 
    the biggest i or j defines the order which is order=max(i, j), i and j are integers.

*/

// Buffer register for xn
reg [Width*N_order-1:0]       xn_reg;
always @ (posedge i_clkp or negedge i_rstn)
    begin // the x[n] shift register which surves value x[n], x[n-1], ... , x[0]
        if (!i_rstn) 
            begin
                xn_reg<=0;
            end
        else 
            begin
                xn_reg<={xn_reg, i_filter};
            end
    end

// Buffer register for xn
reg  [Width*N_order-1:0]      yn_reg;
always @ (posedge i_clkp or negedge i_rstn)
    begin // the y[n] shift register which surves value y[n], y[n-1], ... , y[0]
        if (!i_rstn) 
            begin
                yn_reg<=0;
            end
        else 
            begin
                yn_reg<={yn_reg, o_filter};
            end
    end


// generate N_order-pairs multipliers for y[n] and x[n]
wire [WWidth*N_order-1:0]     b_xn_wire;
wire [WWidth*N_order-1:0]     a_yn_wire;
generate
    genvar i;
    for (i = 0; i < N_order; i = i + 1)
        begin: IIR_filter // calculate the  y[n] and x[n] factored by a and b respectively
            Booth_Multiplier16 y_n(// multiplier for y[n]
                .i_clkp         (i_clkp     ),
                .i_rstn         (i_rstn     ),
                .i_multa        (i_factor_a [(i+1)*Width-1:i*Width]    ),
                .i_multb        (yn_reg     [(i+1)*Width-1:i*Width]    ),
                .o_product      (a_yn_wire   [(i+1)*WWidth-1:i*WWidth] )
                );
            Booth_Multiplier16 x_n(// multiplier for x[n]
                .i_clkp         (i_clkp     ),
                .i_rstn         (i_rstn     ),
                .i_multa        (i_factor_b [(i+1)*Width-1:i*Width]    ),
                .i_multb        (xn_reg     [(i+1)*Width-1:i*Width]    ),
                .o_product      (b_xn_wire   [(i+1)*WWidth-1:i*WWidth] )
                );
        end
endgenerate

// 考虑到两者缩放范围不??样，??要先分别计算x[n]和y[n]的和，经过缩放后??后相加???
wire [WWidth-1:0] suma_wire, sumb_wire;
Full_Ahead_4Adder_P2 #(.Width(WWidth)) add_a(
    .i_clkp         (i_clkp     ),
    .i_rstn         (i_rstn     ),
    .i_c            (1'b0       ),
    .i_y            (a_yn_wire[WWidth*1-1:0]        ),
    .i_z            (a_yn_wire[WWidth*2-1:WWidth*1] ),
    .i_a            (a_yn_wire[WWidth*3-1:WWidth*2] ),
    .i_b            (a_yn_wire[WWidth*4-1:WWidth*3] ),
    .o_d            (suma_wire                      ),
    .o_c            (                               )
    );
Full_Ahead_4Adder_P2 #(.Width(WWidth)) add_b(
    .i_clkp         (i_clkp     ),
    .i_rstn         (i_rstn     ),
    .i_c            (1'b0       ),
    .i_y            (b_xn_wire[WWidth*1-1:0]        ),
    .i_z            (b_xn_wire[WWidth*2-1:WWidth*1] ),
    .i_a            (b_xn_wire[WWidth*3-1:WWidth*2] ),
    .i_b            (b_xn_wire[WWidth*4-1:WWidth*3] ),
    .o_d            (sumb_wire                      ),
    .o_c            (                               )
    );
wire [Width-1:0] sum_wire;
Full_Ahead_2Adder #(.Width(Width)) add_final(// final addition to produce 'sum_wire'
    //.i_clkp         (i_clkp         ),
    //.i_rstn         (i_rstn         ),
    .i_c            (1'b0           ),
    .i_a            (suma_wire>>>n_a),// refactor of sum a
    .i_b            (sumb_wire>>>n_b),// refactor of sum b
    .o_d            (sum_wire       ),
    .o_c            ()
    );

pipelineto  #(.Width(Width),.Stage(1)) lineto_output(
  .i_clkp(i_clkp), .i_rstn(i_rstn),
  .i_a(sum_wire),
  .o_a(o_filter)
  );
//assign o_filter=sum_wire; // a(0, 1) is scaled to a(0,2^15) before caculation, now scale the result back here


endmodule

