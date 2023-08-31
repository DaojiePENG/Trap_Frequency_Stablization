module RTMQ_Timer(clk, alu_out, reg_wck, reg_tim, f_hld, f_timout);

`include "RTMQ_Header.v"

input                clk;           // System clock
input  [W_ALU-1 : 0] alu_out;       // ALU output bus
output [W_REG-1 : 0] reg_wck;       // Wall clock output: cycles since power-up, lower segment
output [W_REG-1 : 0] reg_tim;       // Wall clock output: cycles since power-up, higher segment
input                f_hld;         // Hold state indicator
output               f_timout;      // Time-out flag: to resume hold state

// --- Unpack ALU bus ---
wire [W_REG-1 : 0] alu_res;
wire [W_REG-1 : 0] alu_msk;
wire [W_ADR-1 : 0] alu_rda;
wire [W_ADR-1 : 0] alu_r0a;
wire [W_ADR-1 : 0] alu_r1a;
wire [W_REG-1 : 0] imm_res;
wire [W_ADR-1 : 0] imm_rda;
wire               imm_seg;
assign {alu_res, alu_msk, alu_rda, alu_r0a, alu_r1a,
        imm_res, imm_rda, imm_seg} = alu_out;

// ------ Time Stamp Buffer ------

wire f_wrt_alu;
wire f_wrt_ihi;
wire f_wrt_ilo;
RTMQ_AcsFlg #(.ADDR(R_TIM))// 时间戳缓冲寄存器-根据alu_out给出读写信号
  FACS(.clk(clk), .alu_out(alu_out), .f_read(), .f_wrt_alu(f_wrt_alu),
       .f_wrt_ihi(f_wrt_ihi), .f_wrt_ilo(f_wrt_ilo));

reg  f_set = 0;
always @ (posedge clk) f_set <= f_wrt_ilo | f_wrt_alu;

reg  [W_REG-1 : 0] tim_buf = 0;
always @ (posedge clk)
/*
  功能：根据alu指令对time缓冲区进行赋值操作
  1.立即数地位赋值；
  2.立即数高位赋值；
  3.alu赋值；
  4.默认值保持不变；
 */
if (f_wrt_ilo)
  // To compensate Type-I and Type-A latency difference
  tim_buf <= {tim_buf[W_REG-1 : W_LSG], imm_res[W_LSG-1 : 0]} + 3;// +3是为了补偿两种指令的不同时延，时延不同在哪里体现？
else if (f_wrt_ihi)
  tim_buf <= {imm_res[W_REG-1 : W_LSG], tim_buf[W_LSG-1 : 0]};
else if (f_wrt_alu)
  tim_buf <= alu_res | (tim_buf & alu_msk);
else
  tim_buf <= tim_buf;

// ------ Countdown Timer ------

reg  [W_REG-1 : 0] tim = 0;
reg                f_cdn = 0;
wire               f_vld = (tim_buf > N_MND);// 为什么一定要>N_MND=9?
always @ (posedge clk)
begin
  if (f_set) tim <= f_vld ? (tim_buf - N_MND) : 0;// N_MND = 9; Minimum allowed duration of TIM, in cycles把它减掉赋值给tim，进而给SRFlag来判断给出f_timout输出
  else tim <= tim - f_cdn;// 计时器递减
  if (f_set) f_cdn <= f_vld;
  else f_cdn <= (tim > 1);
end

SRFlag #(.Pri("set"), .PUS(1'b0))
/*
  功能：决定了什么时候从hold状态恢复。当tim==1或者时给出恢复信号f_timout
*/ 
  FTIM(.clk(clk), .set((tim == 1) | (f_set & ~f_vld)), .rst(f_hld), .flg(f_timout));

// ------ Wall Clock ------
// 按道理只要这部分就可以了，上面那么一大堆是干什么呢？给出了f_timout,配合完成定时任务，从hold中回复。
reg  [W_REG-1 : 0] reg_tim = 0;
reg  [W_REG-1 : 0] reg_wck = 0;
wire [W_REG-1 : 0] rst_vlo = {{(W_REG-W_LSG){imm_res[W_LSG-1]}}, imm_res[W_LSG-1 : 0]};
wire [W_REG-1 : 0] rst_vhi = {{W_REG{imm_res[W_LSG-1]}}};
reg                carry = 0;
reg                f_rst = 0;

always @ (posedge clk) f_rst <= (imm_rda == R_WCK) & imm_seg;// 这个有什么作用呢？下面操作时钟。

always @ (posedge clk)// 时钟递增
if (f_rst)
// 1.如果达成rst条件则时钟tim和墙钟wck都重装填
begin
  carry <= 0;
  reg_wck <= rst_vlo;
  reg_tim <= rst_vhi;
end
else
// 2.否则墙钟递增，墙钟wck有进位了传递给时钟tim
begin
  {carry, reg_wck} <= reg_wck + 1;
  reg_tim <= reg_tim + carry;
end

endmodule
