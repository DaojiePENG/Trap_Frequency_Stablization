`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: SUSTech
// Engineer: Daojie.PENG@outlook.com
// 
// Create Date: 2022/12/15 20:31:24
// Design Name: 
// Module Name: PID_16_tb
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


module PID_16_tb;
reg i_clkp;
reg i_rstn;
wire signed[31:0] o_ut;
reg signed[15:0] sys;
reg signed[15:0] ref;
reg signed[15:0] kp,ki,kd,i_k0,i_k1,i_k2;

wire signed[15:0] reg_o_et_0, reg_o_et_1, reg_o_et_2;
wire signed[31:0] reg_o_mult0, reg_o_mult1, reg_o_mult2, reg_o_add0, reg_o_add1, reg_o_add2;

PID_16 uut(
    /**/
    .i_clkp    (i_clkp),
    .i_rstn      (i_rstn),
    .i_rt         (ref), // 目标信号
    .i_yt         (sys), // 实际信号
    .i_k0        (i_k0),
    .i_k1        (i_k1),
    .i_k2        (i_k2),
    
    .o_ut          (o_ut) // 误差调节信号
    /**/
    );
initial
    begin
        i_clkp=0;
        i_rstn=0;
        ref=1000;
/*
        #10;
        sys=0;
        kp=1;
        ki=1;
        kd=0;
        i_rstn=1;
        #5000;
        i_rstn=0;

        #10;
        sys=0;
        kp=0;
        ki=1;
        kd=0;
        i_rstn=1;
        #5000;
        i_rstn=0;

        #10;
        sys=0;
        kp=0;
        ki=0;
        kd=1;
        i_rstn=1;
        #10000;
        i_rstn=0;
// 混合kp
        #10;
        sys=0;
        kp=0;
        ki=1;
        kd=1;
        i_rstn=1;
        #5000;
        i_rstn=0;

        #10;
        sys=0;
        kp=1;
        ki=1;
        kd=1;
        i_rstn=1;
        #5000;
        i_rstn=0;

        #10;
        sys=0;
        kp=2;
        ki=1;
        kd=1;
        i_rstn=1;
        #5000;
        i_rstn=0;

        #10;
        sys=0;
        kp=3;
        ki=1;
        kd=1;
        i_rstn=1;
        #5000;
        i_rstn=0;

        #10;
        sys=0;
        kp=4;
        ki=1;
        kd=1;
        i_rstn=1;
        #5000;
        i_rstn=0;
*/
        #10;
        sys=0;
        kp=2;
        ki=0;
        kd=0;
        i_rstn=1;
        #5000;
        i_rstn=0;

        #10;
        sys=0;
        kp=3;
        ki=0;
        kd=0;
        i_rstn=1;
        #5000;
        i_rstn=0;

        #10;
        sys=0;
        kp=4;
        ki=0;
        kd=0;
        i_rstn=1;
        #5000;
        i_rstn=0;

        #10;
        sys=0;
        kp=5;
        ki=0;
        kd=0;
        i_rstn=1;
        #5000;
        i_rstn=0;
        
        #10;
        sys=0;
        kp=6;
        ki=0;
        kd=0;
        i_rstn=1;
        #5000;
        i_rstn=0;
        
/*
        #10;
        sys=0;
        kp=0;
        ki=0;
        kd=0;
        i_rstn=1;
        #5000;
        i_rstn=0;

        #10;
        sys=0;
        kp=0;
        ki=0;
        kd=1;
        i_rstn=1;
        #5000;
        i_rstn=0;

        #1000;
        sys=0;
        kp=0;
        ki=0;
        kd=2;
        i_rstn=1;
        #50;
        i_rstn=0;



// 混合ki

        #10;
        sys=0;
        kp=1;
        ki=0;
        kd=1;
        i_rstn=1;
        #5000;
        i_rstn=0;

        #10;
        sys=0;
        kp=1;
        ki=1;
        kd=1;
        i_rstn=1;
        #5000;
        i_rstn=0;

        #10;
        sys=0;
        kp=1;
        ki=2;
        kd=1;
        i_rstn=1;
        #5000;
        i_rstn=0;

        #10;
        sys=0;
        kp=1;
        ki=3;
        kd=1;
        i_rstn=1;
        #5000;
        i_rstn=0;

        #10;
        sys=0;
        kp=1;
        ki=4;
        kd=1;
        i_rstn=1;
        #5000;
        i_rstn=0;

        #10;
        sys=0;
        kp=1;
        ki=5;
        kd=1;
        i_rstn=1;
        #5000;
        i_rstn=0;
*/
/*
// 混合kd
        #10;
        sys=0;
        kp=1;
        ki=1;
        kd=0;
        i_rstn=1;
        #5000;
        i_rstn=0;

        #10;
        sys=0;
        kp=1;
        ki=1;
        kd=1;
        i_rstn=1;
        #5000;
        i_rstn=0;

        #10;
        sys=0;
        kp=1;
        ki=1;
        kd=2;
        i_rstn=1;
        #5000;
        i_rstn=0;

        #10;
        sys=0;
        kp=1;
        ki=1;
        kd=3;
        i_rstn=1;
        #5000;
        i_rstn=0;

        #10;
        sys=0;
        kp=1;
        ki=1;
        kd=4;
        i_rstn=1;
        #5000;
        i_rstn=0;

        #10;
        sys=0;
        kp=1;
        ki=1;
        kd=5;
        i_rstn=1;
        #5000;
        i_rstn=0;
*/

/*
        #10;
        sys=0;
        kp=1;
        ki=0;
        kd=1;
        i_rstn=1;
        #5000;
        i_rstn=0;
*/
        $finish;
    end
always #5
    begin
        i_clkp=~i_clkp;
        i_k0=kp+ki+kd;
        i_k1=-kp-2*kd;
        i_k2=kd;
        //sys=sys+o_ut/50;
        
        sys=1010;
    end
endmodule
