module RTMQ_ALU(clk, alu_out, instr, regfile);

/*
输入：指令、寄存器地址表
操作：
输出：根据指令挑选出的算数和逻辑运算结果、目标寄存器地址、
*/

`include "RTMQ_Header.v"

input                clk;       // System clock
output [W_ALU-1 : 0] alu_out;   // alu_out = {alu_res, alu_msk, alu_rda, alu_r0a, alu_r1a,
                                //            imm_res, imm_rda, imm_seg}
                                //   Type-A instruction interface (A channel):
                                //     alu_res: result output, masked
                                //     alu_msk: result mask output, inverted
                                //     alu_rda: RD address
                                //     alu_r0a: R0 address
                                //     alu_r1a: R1 address
                                //   Type-I instruction interface (I channel):
                                //     imm_res: immediate output
                                //     imm_rda: RD address (combinatorial)
                                //     imm_seg: higher / lower segment flag (combinatorial)
input  [W_REG-1 : 0] instr;     // Current instruction
input  [W_BUS-1 : 0] regfile;   // Register file

//alu_out和instr的关系是什么样的？输入的是指令，输出的是alu_out包括A型和I型指令。

// ######## Type-A Instruction ########
//
// --- Encoding ---
// instr[31]     : 1'b1
// instr[30]     : RD inversion flag
// instr[29]     : Controller hold flag: 1 to initiate hold state
// instr[28]     : Flow control flag: 1 to initiate instruction fetch pipeline flush
// instr[27 : 24]: ALU opcode
// instr[23 : 16]: register address for RD
// instr[15]     : R0 immediate flag: 1 for immediate
// instr[14]     : R1 immediate flag: 1 for immediate
// instr[13]     : R0 is register: R0 inversion flag / R0 is immediate: imm[6]
// instr[12]     : R1 is register: R1 inversion flag / R1 is immediate: imm[6]
// instr[11 :  6]: R0 is register: R0 address / R0 is immediate: imm[5:0]
// instr[ 5 :  0]: R1 is register: R1 address / R1 is immediate: imm[5:0]
//
// NOTE: immediates are sign extended or zero padded, depending on opcode.
//
// --- for opcode: MOV ---
// instr[15 : 13]: 3'b100
// instr[12]     : R1 bitwise inversion flag
// instr[11 :  8]: 4'b0000
// instr[ 7 :  0]: R1 address

// ------ Timing Diagram ------
//
// T-A: Type-A Instr    VLD: Data valid
//
// clk    : /'''\.../'''\.../'''\.../'''\.../'''\.../  # system clock
// instr  : |  T-A  |  ---  |  ---  |  ---  |  ---  |  # current instruction
// alu_r*a: |  ---  |  VLD  |  ---  |  ---  |  ---  |  # operand address
// pre-mux: |  ---  |  VLD  |  ---  |  ---  |  ---  |  # operand pre-mux
// r0 / r1: |  ---  |  ---  |  VLD  |  ---  |  ---  |  # operand value
// rd_*** : |  ---  |  ---  |  ---  |  VLD  |  ---  |  # intermediate result
// alu_res: |  ---  |  ---  |  ---  |  ---  |  VLD  |  # ALU result / mask output
// alu_rda: |  ---  |  ---  |  ---  |  VLD  |  ---  |  # RD address
// alu_wse: |  ---  |  ---  |  ---  |  VLD  |  ---  |  # write side effect trigger

// ------ Pipeline Stage #1: Operand Pre-mux ------
/*
根据instr提供的地址，获得regfile地址上对应的数值；
*/
localparam N_SEG = 1 << (W_ADR - W_PAD);// 这是在算啥？地址宽度-PAD宽度剩余的宽度。剩余的宽度所能寻址的范围为N_SEG，生成N_SEG个片选器，片选出一簇t_r1_pmx
localparam W_PMX = N_SEG * W_REG;
wire [  W_PAD-1 : 0] t_r0_pad = instr[10 : 6];
wire [  W_PAD-1 : 0] t_r1_pad = instr[ 4 : 0];
wire [2*W_REG-1 : 0] t_r0_pmx;
wire [  W_PMX-1 : 0] t_r1_pmx;

WideMux #(.W_WRD(W_REG), .W_SEL(W_PAD))
  PMR0_1(.bus(regfile[2*W_PBS-1 : W_PBS]), .sel(t_r0_pad), .out(t_r0_pmx[2*W_REG-1 : W_REG]));
WideMux #(.W_WRD(W_REG), .W_SEL(W_PAD))
  PMR0_0(.bus(regfile[  W_PBS-1 :     0]), .sel(t_r0_pad), .out(t_r0_pmx[  W_REG-1 :     0]));

genvar i;// R0和R1有什么区别？为什么位数以至于MUX数量不一样？
generate
for (i = 0; i < N_SEG; i = i + 1)
begin: PMUX

  WideMux #(.W_WRD(W_REG), .W_SEL(W_PAD))
    iPMX(.bus(regfile[W_PBS*(i+1)-1 : W_PBS*i]), .sel(t_r1_pad), .out(t_r1_pmx[W_REG*(i+1)-1 : W_REG*i]));

end
endgenerate

reg  [2*W_REG-1 : 0] d_r0_pmx = 0;
reg  [  W_PMX-1 : 0] d_r1_pmx = 0;
always @ (posedge clk)
if (instr[P_ITH]) {d_r0_pmx, d_r1_pmx} <= {t_r0_pmx, t_r1_pmx};// 0 for Type-I: Immediate, 1 for Type-A: ALU
                                                                // t_r0_pmx: 包含两个寄存器值；t_r1_pmx：包含N_SEG个寄存器值
else {d_r0_pmx, d_r1_pmx} <= {d_r0_pmx, d_r1_pmx};// 这是处理的非立即数，如果是立即数的情况，则没有操作

// --- Output: alu_r0a, alu_r1a ---解析指令

wire [ 3 : 0] opc_pl1 = instr[27 : 24];
wire          f_r0_imm_pl1 = instr[15];
wire          f_r1_imm_pl1 = instr[14];

reg  [W_ADR-1 : 0] alu_r0a = 0;
reg  [W_ADR-1 : 0] alu_r1a = 0;

always @ (posedge clk)
if (instr[P_ITH] & ~f_r0_imm_pl1) alu_r0a <= {2'b0, instr[11 : 6]};
else alu_r0a <= 0;

always @ (posedge clk)// 为什么要设计MOV指令单独？
if (~instr[P_ITH]) 
  alu_r1a <= 0;
else if (opc_pl1 == O_MOV)
  alu_r1a <= instr[7 : 0];
else if (f_r1_imm_pl1)
  alu_r1a <= 0;
else
  alu_r1a <= {2'b0, instr[5 : 0]};

// ------ Pipeline Stage #2: Operand Evaluation ------
/*
提取输入的值；计算寄存器值的翻转
*/
reg  [W_REG-1 : 0] ins_pl2 = 0;
always @ (posedge clk) ins_pl2 <= instr;

wire f_r0_imm = ins_pl2[15];// f_是flag
wire f_r1_imm = ins_pl2[14];
wire f_r0_inv = ins_pl2[13];
wire f_r1_inv = ins_pl2[12];

wire [W_REG-1 : 0] t_i0_ath = {{26{f_r0_inv}}, ins_pl2[11 : 6]};// i是immediate，ath是Arithmetic
wire [W_REG-1 : 0] t_i1_ath = {{26{f_r1_inv}}, ins_pl2[ 5 : 0]};
wire [W_REG-1 : 0] t_i0_lgc = {25'b0, f_r0_inv, ins_pl2[11 : 6]};// lgc是logic
wire [W_REG-1 : 0] t_i1_lgc = {25'b0, f_r1_inv, ins_pl2[ 5 : 0]};
wire [W_REG-1 : 0] t_r0_reg = ins_pl2[11] ? d_r0_pmx[2*W_REG-1 : W_REG] : d_r0_pmx[W_REG-1 : 0];
wire [W_REG-1 : 0] t_r1_reg = ins_pl2[ 5] ? d_r1_pmx[2*W_REG-1 : W_REG] : d_r1_pmx[W_REG-1 : 0];// 它有N_SEG个值，为什么只从前两个中选择？
wire [W_REG-1 : 0] t_r0_inv = t_r0_reg ^ {(W_REG){f_r0_inv}};
wire [W_REG-1 : 0] t_r1_inv = t_r1_reg ^ {(W_REG){f_r1_inv}};// 这里进行异或操作的作用是？根据翻转标志位是否为1进行翻转，
wire [W_REG-1 : 0] t_rd_mov;

WideMux #(.W_WRD(W_REG), .W_SEL(3))
  MMOV(.bus(d_r1_pmx), .sel(ins_pl2[7 : 5]), .out(t_rd_mov));

reg  [W_REG-1 : 0] d_r0_lgc = 0;
reg  [W_REG-1 : 0] d_r0_ath = 0;
reg  [W_REG-1 : 0] d_r1_lgc = 0;
reg  [W_REG-1 : 0] d_r1_ath = 0;
reg  [W_REG-1 : 0] d_rd_mov = 0;

always @ (posedge clk)// 这部分如何体现逻辑运算和算术运算的？
if (ins_pl2[P_ITH])// 根据是否是立即数选择相应的输出进入下一级流水线，接下来就是对这几个数的运算操作了
begin
  d_r0_lgc <= f_r0_imm ? t_i0_lgc : (t_r0_inv);// 对于逻辑取反，就是直接每一位翻转
  d_r0_ath <= f_r0_imm ? t_i0_ath : (t_r0_inv + f_r0_inv);// 对于算数取反，就是每位取反+1；运算都采用的是补码形式
  d_r1_lgc <= f_r1_imm ? t_i1_lgc : (t_r1_inv);
  d_r1_ath <= f_r1_imm ? t_i1_ath : (t_r1_inv + f_r1_inv);
  d_rd_mov <= t_rd_mov ^ {(W_REG){f_r1_inv}};
end
else {d_r0_lgc, d_r0_ath, d_r1_lgc, d_r1_ath, d_rd_mov} <= {d_r0_lgc, d_r0_ath, d_r1_lgc, d_r1_ath, d_rd_mov};

// ------ Pipeline Stage #3: Intermediate Result ------
/*

*/
reg  [W_REG-1 : 0] ins_pl3 = 0;
wire [ 3      : 0] opc_pl3 = ins_pl3[27 : 24];
always @ (posedge clk) ins_pl3 <= ins_pl2;

wire f_rd_inv = ins_pl3[P_ITL];
wire sgn_r0   = d_r0_ath[W_REG-1];    // Sign bit of R0
wire sgn_r1   = d_r1_ath[W_REG-1];    // Sign bit of R1

wire [W_REG-1 : 0] t_inv_ext = {(W_REG){f_rd_inv}};

// --- Opcodes: Basic ---

reg  [W_REG-1 : 0] rd_add = 0;
reg  [W_REG-1 : 0] rd_and = 0;
reg  [W_REG-1 : 0] rd_xor = 0;

always @ (posedge clk) if (ins_pl3[P_ITH])
begin
  rd_add <= ((d_r0_ath + d_r1_ath) ^ t_inv_ext) + f_rd_inv;// 为什么要异或一下t_inv_ext再加一下f_rd_inv？同时实现加减法，根据f_rd_inv。
  rd_and <= ((d_r0_lgc & d_r1_lgc) ^ t_inv_ext);// 与0异或相当于不变，与1异或相当于取反
  rd_xor <= ((d_r0_lgc ^ d_r1_lgc) ^ t_inv_ext);
end
else {rd_add, rd_and, rd_xor} <= {rd_add, rd_and, rd_xor};

// --- Opcodes: Compare ---

wire t_clu = (d_r0_ath < d_r1_ath) ^ f_rd_inv;// u 无符号比较；s有符号比较
wire t_cls = ({sgn_r1, d_r0_ath[W_REG-2 : 0]} < {sgn_r0, d_r1_ath[W_REG-2 : 0]}) ^ f_rd_inv;// 加t或者d前缀的是什么含义？temp
wire t_ceq = (d_r0_ath == d_r1_ath) ^ f_rd_inv;// 相等判断

reg  [W_REG-1 : 0] rd_clu = 0;  // RD = (R0 < R1), unsigned compare
reg  [W_REG-1 : 0] rd_cls = 0;  // RD = (R0 < R1), signed compare
reg  [W_REG-1 : 0] rd_ceq = 0;  // RD = (R0 == R1)

always @ (posedge clk) if (ins_pl3[P_ITH])
begin
  rd_clu <= {(W_REG){t_clu}};
  rd_cls <= {(W_REG){t_cls}};
  rd_ceq <= {(W_REG){t_ceq}};
end
else {rd_clu, rd_cls, rd_ceq} <= {rd_clu, rd_cls, rd_ceq};

// --- Opcodes: Set ---

reg  [W_REG-1 : 0] rd_sgn = 0;  // RD = R0 * sign(R1)
reg  [W_REG-1 : 0] rd_set = 0;  // RD = R0, with mask
reg  [W_REG-1 : 0] rd_mov = 0;
reg  [W_REG-1 : 0] mk_pl3 = 0;  // Mask

always @ (posedge clk) if (ins_pl3[P_ITH])
begin
  rd_sgn <= (sgn_r1) ? (~d_r0_ath + 1) : d_r0_ath;
  rd_set <= d_r0_lgc;
  rd_mov <= d_rd_mov + f_rd_inv;
  case (opc_pl3)
    O_SNE: mk_pl3 <= {(W_REG){sgn_r1 ^ f_rd_inv}};
    O_SMK: mk_pl3 <= d_r1_lgc;
    default: mk_pl3 <= 32'hFFFFFFFF;
  endcase
end
else {rd_set, rd_mov, mk_pl3} <= {rd_set, rd_mov, mk_pl3};// pipeline3的掩码做什么用？

// --- Opcodes: Shift & Reverse ---

wire [ 4      : 0] r1_sft = d_r1_ath[4 : 0];

// Shift Left Logical
wire [W_REG-1 : 0] t_sll_hi;
wire [W_REG-1 : 0] t_sll_md;
wire [W_REG-1 : 0] t_sll_lo;
wire r0_lsb = d_r0_lgc[0];
assign {t_sll_hi, t_sll_md, t_sll_lo} = {t_inv_ext, d_r0_lgc, {(W_REG){r0_lsb}}} << r1_sft;

// Shift Left Arithmetic
wire [W_REG-1 : 0] t_sla_hi;
wire [W_REG-1 : 0] t_sla_md;
wire [W_REG-1 : 0] t_sla_lo;
wire r0_msb = d_r0_lgc[W_REG-1];
assign {t_sla_hi, t_sla_md, t_sla_lo} = {{(W_REG){r0_msb}}, d_r0_lgc, t_inv_ext} << r1_sft;

// Shift Left Cyclic
wire [W_REG-1 : 0] t_slc_hi;
wire [W_REG-1 : 0] t_slc_md;// Circle shift的实现 
wire [W_REG-1 : 0] t_slc_lo;
wire [W_REG-1 : 0] t_r0_inv_sft = d_r0_lgc ^ t_inv_ext;
assign {t_slc_hi, t_slc_md, t_slc_lo} = {t_r0_inv_sft, d_r0_lgc, t_r0_inv_sft} << r1_sft;

// Bit Order Reverse
wire [W_REG-1 : 0] t_rev;
generate
  for (i = 0; i < W_REG; i = i + 1)
  begin
    
    assign t_rev[i] = d_r0_lgc[W_REG-i-1];
    
  end
endgenerate

// Register result
reg  [W_REG-1 : 0] rd_sll = 0;
reg  [W_REG-1 : 0] rd_sla = 0;
reg  [W_REG-1 : 0] rd_slc = 0;
reg  [W_REG-1 : 0] rd_rev = 0;

always @ (posedge clk) if (ins_pl3[P_ITH])
begin
  rd_sll <= sgn_r1 ? t_sll_hi : t_sll_md;// 根据R1的符号位选择输出结果
  rd_sla <= sgn_r1 ? t_sla_hi : t_sla_md;
  rd_slc <= sgn_r1 ? t_slc_hi : t_slc_md;
  rd_rev <= t_rev;
end
else {rd_sll, rd_sla, rd_slc, rd_rev} <= {rd_sll, rd_sla, rd_slc, rd_rev};

// --- Output: alu_rda ---

reg  [W_ADR-1 : 0] alu_rda = 0;     // RD address:
                                    //   1 cycle earlier than <alu_res> and <alu_msk>, 
                                    //     so that pipelined write flag bit can be generated:
                                    //     f_wrt <= (alu_rda == ADDR),
                                    //     which aligns with <alu_res> and <alu_msk>.
                                    //   NOTE: For opcode SNE, <alu_rda> = 0 if sgn(R1) ^ f_rd_inv = 0.

always @ (posedge clk)
if (~ins_pl3[P_ITH])
  alu_rda <= 0;
else if (opc_pl3 != O_SNE)
  alu_rda <= ins_pl3[P_RDH : P_RDL];
else if (sgn_r1 ^ f_rd_inv)
  alu_rda <= ins_pl3[P_RDH : P_RDL];  // Output <alu_rda> only when SNE actually takes place
else
  alu_rda <= 0;

// ------ Pipeline Stage #4: Output ------// 这部分是核心把手，选择信号输出，将前面的操作联系起来

reg  [W_REG-1 : 0] ins_pl4 = 0;
wire [ 3      : 0] opc_pl4 = ins_pl4[27 : 24];
always @ (posedge clk) ins_pl4 <= ins_pl3;

wire [W_REG-1    : 0] t_alu_mux;
wire [16*W_REG-1 : 0] t_res_bus = {{(W_REG*2){1'b0}},
                                   rd_rev, rd_slc, rd_sla, rd_sll,
                                   rd_mov, rd_set, rd_set, rd_sgn,
                                   rd_ceq, rd_cls, rd_clu,
                                   rd_xor, rd_and, rd_add};

WideMux #(.W_WRD(W_REG), .W_SEL(4))
  MXRD(.bus(t_res_bus), .sel(opc_pl4), .out(t_alu_mux));

// --- Output: alu_res, alu_msk ---

reg  [W_REG-1 : 0] alu_res = 0;// 这块儿逻辑不太理解，
reg  [W_REG-1 : 0] alu_msk = 0;     // <alu_res> is masked and <alu_msk> is inverted to save
                                    //   combinatorial logic in downstream stages. In this way,
                                    //   the assignment to the register can simply be:
                                    //   RD <= alu_res | (RD & alu_msk)
                                    // alu_msk全为零，则RD=alu_res；alu_msk全为1，则RD=alu_res|RD；

always @ (posedge clk) 
if (ins_pl4[P_ITH])
begin
  alu_res <= t_alu_mux & mk_pl3;// 用musk的原因好像说过是可以只改变某几位？
  alu_msk <= ~mk_pl3;
end
else {alu_res, alu_msk} <= 0;

// ######## Type-I Instruction ########
// 
// --- Encoding ---
// instr[31]     : 1'b0
// instr[30]     : Segment flag: 0 for higher 12 bits, 1 for lower 20 bits
// instr[29]     : Controller hold flag
// instr[28]     : Flow control flag
// instr[23 : 16]: RD address
//
// --- For lower segment: RD[19:0] = imm ---
// instr[27 : 24]: imm[19:16]
// instr[15 :  0]: imm[15:0]
//
// --- For higher segment: RD[31:20] = imm ---
// instr[27 : 24]: 4'b0000
// instr[15 : 12]: 4'b0000
// instr[11 :  0]: imm[11:0]

// --- Output: imm_rda, imm_seg ---

wire [W_ADR-1 : 0] imm_rda = instr[P_ITH] ? 0 : instr[P_RDH : P_RDL];
wire               imm_seg = ~instr[P_ITH] & instr[P_ITL];

// --- Output: imm_res ---

reg  [W_REG-1 : 0] imm_res = 0;
always @ (posedge clk)
/*
  功能：根据指令是否为立即数指令为立即数结果赋值
  1.非立即数，结果清零；
  2.立即数，根据立即数指令的内容判断是20位还是12位立即数并赋值
*/
if (instr[P_ITH])
  imm_res <= 0;
else
  imm_res <= instr[P_ITL] ? {12'b0, instr[27 : 24], instr[15 : 0]} : {instr[11 : 0], 20'b0};

// ######## Pack Output ########

assign alu_out = {alu_res, alu_msk, alu_rda, alu_r0a, alu_r1a,
                  imm_res, imm_rda, imm_seg};// 最终输出结构

endmodule
