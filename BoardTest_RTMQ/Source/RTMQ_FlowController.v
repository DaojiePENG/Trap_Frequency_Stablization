module RTMQ_FlowController(clk, alu_out, reg_ptr,
                           if_adr, if_ins, f_ftc,
                           instr, f_hld, f_rsm,
                           f_cfg, cfg_ins);

`include "RTMQ_Header.v"

input                clk;           // System clock
input  [W_ALU-1 : 0] alu_out;       // ALU output bus
output [W_REG-1 : 0] reg_ptr;       // Address of current instruction (for regfile)

output [W_REG-1 : 0] if_adr;        // Instruction fetch (IF) address
input  [W_REG-1 : 0] if_ins;        // IF input
output               f_ftc;         // IF pipeline fetch flag 输出表明流水线已被访问过？

output [W_REG-1 : 0] instr;         // Current instruction
output               f_hld;         // HOLD state indicator
input                f_rsm;         // External RESUME flag, ORed for all peripherals
                                    // For peripherals:
                                    //   Each time, only one peripheral can be activated.
                                    //   When activated, <f_rsm> should remain asserted until <f_hld> == 1 is detected.
                                    //   In this way, belated HLD flag will not stall the execution.

input                f_cfg;         // Configuration override flag
input  [W_REG-1 : 0] cfg_ins;       // Configuration instruction

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

// ------ f_ftc ------
// Controller hold state is initiated with HLD flag,
//   and later released with <f_rsm> == 1.
// Hold state is used to implement peripherals like timers and external triggers.
// NOTE: Type-I: higher seg. should never assert HLD flg.
// IF pipeline is suspended in hold or configuration override state.

reg  f_ftc = 0;  // High fanout signal: may require replication.
wire f_hld;
wire f_nftc_cmb = f_cfg | f_hld | instr[P_HLD];// 这个信号命名是什么意思？起什么作用？ 
//这个信号是控制取指流水线挂起状态的~n表示反向，ftc是fetch，就是取指，cmb表示组合逻辑

SRFlag #(.Pri("set"), .PUS(1'b1))
  FHLD(.clk(clk), .set(instr[P_HLD]), .rst(f_rsm), .flg(f_hld));

always @ (posedge clk) f_ftc <= ~f_nftc_cmb;

// ------ IF pipeline flush ------ 流水线刷新
// Assert FCT flag to initiate an IF pipeline flush.
// Always assert FCT flag when <rd_adr> == R_PTR,
//   so that flow control overhead is identical between branches.

reg  [N_PLA-1 : 0] ppl_alu = 0;   // This is used to synchronize the flush behavior with ALU pipelining.
// Be high from the assertion of FCT flag, to valid instruction appearing at <if_ins>.
wire f_fls_reg;
wire f_fls = f_fls_reg | instr[P_FCT];
always @ (posedge clk)
if (instr[P_FCT])
  // 1.P_FCT = 28 Flow control flag: 1 to initiate pipeline flush 如果流水线刷新了，
  ppl_alu <= instr[P_ITH] ? 3'b000 : 3'b111;
else
  // 2.将刷新标志位推入ppl_alu
  ppl_alu <= {ppl_alu, f_fls_reg};

generate
if (N_PLM > 1)
// 1.指令流水线时延N_PLM=3, Pipeline latency of instruction memory: addr valid --> output valid
begin

  // This is used to synchronize the flush behavior with main memory pipelining.内存同步
  reg  [N_PLM-2 : 0] ppl_mem = 0;
  always @ (posedge clk)
  /*
    功能：根据N_PLM指令时延来扩展ppl_alu缓存长度，
  */
  if (instr[P_FCT])
    // 1.P_FCT=28, Flow control flag: 1 to initiate pipeline flush 流水线被刷新，则ppl_mem清零
    ppl_mem <= 0;
  else if (f_ftc)
    // 2.如果取了一次指令，那么将ppl_alu的高位推入ppl_mem
    ppl_mem <= {ppl_mem, ppl_alu[N_PLA-1]};
  else
    // 3.否则不变
    ppl_mem <= ppl_mem;

  SRFlag #(.Pri("set"), .PUS(1'b0))
    FFCT(.clk(clk), .set(instr[P_FCT]), .rst(ppl_mem[N_PLM-2] & f_ftc), .flg(f_fls_reg));

end
else
begin

  SRFlag #(.Pri("set"), .PUS(1'b0))
    FFCT(.clk(clk), .set(instr[P_FCT]), .rst(ppl_alu[N_PLA-1] & f_ftc), .flg(f_fls_reg));

end
endgenerate

// ------ if_adr ------ instruction fetch address

wire f_wrt_ilo;
RTMQ_AcsFlg #(.ADDR(R_PTR))
  FACS(.clk(clk), .alu_out(alu_out), .f_read(), .f_wrt_alu(),
       .f_wrt_ihi(), .f_wrt_ilo(f_wrt_ilo));

reg  [W_REG-1 : 0] if_adr = 0;
reg  [W_REG-1 : 0] dft_val = 0;
reg  [N_PLA-1 : 0] f_wrt_alu = 0;

always @ (posedge clk) f_wrt_alu <= {f_wrt_alu, (instr[P_RDH : P_RDL] == R_PTR) & instr[P_ITH]};
always @ (posedge clk)
/*
  功能：
  这个是处理条件跳转的逻辑的一部分~就是遇到条件跳转语句时，若不满足条件，则指令指针所要获得的值;
  这部分实际上涉及好几个流水线的步骤交汇，代码虽短，但是理解起来比较复杂
*/
if (f_fls)
  // 1.如果刷新了，则默认地址值为当前指针地址+1；
  dft_val <= reg_ptr + 1;
else
  // 2.默认情况下，值为进入流水时延前的地址根据f_ftc+(f_nftc_cmb ^ 1'b1)的值，+0，+1或者+2
  dft_val <= if_adr + f_ftc + (f_nftc_cmb ^ 1'b1);

always @ (posedge clk)
/*
  功能：实现寄存器的自动+1操作和写
*/
if (f_wrt_ilo)           // Type-I instruction can only initiate short jump
  // 1.如果是用立即数赋值，只能赋值低位一部分
  if_adr <= {dft_val[W_REG-1 : W_LSG], imm_res[W_LSG-1 : 0]};
else if (f_wrt_alu[N_PLA-1])
// 2.如果是用alu写地址，则msk型整个寄存器赋值
  if_adr <= alu_res | (dft_val & alu_msk);
else
  // 3.默认情况fetch一个指令地址+1
  if_adr <= if_adr + f_ftc;

// ------ instr ------

reg  [W_REG-1 : 0] instr = 0;
reg  [W_REG-1 : 0] ins_buf = 0;

always @ (posedge clk)
/*
功能：根据不同情况选择输出的指令（四种情况：配置、挂起、恢复、正常）
*/
if (f_cfg)
  // 1.config的情况下，输出的指令为config的指令
  //  此时同周期的f_nftc_cmb = f_cfg | f_hld | instr[P_HLD]=1，进入挂起状态
  instr <= cfg_ins;      // Configuration override state
else if (f_fls | f_nftc_cmb)// =if (f_nftc_cmb)?, 两者差一个时钟
  // 2.刷新或挂起的状态下，输出的指令为空指令，给instr赋值为I_NOP=32'h00000000
  instr <= I_NOP;        // IF pipeline flush / Controller hold state
else if (~f_ftc)
  // 3.f_ftc <= ~f_nftc_cmb，在这种情况下，输出的指令为缓存中的指令。
  //  f_nftc_cmb == 0时说明不在挂起状态了，f_ftc == 0说明上一个状态是在挂起状态的，因此就是从挂起改变到恢复的时候
  instr <= ins_buf;      // Resume from hold state 从hold状态复原回来，下面1
else 
  // 4.正常情况下，输出的指令就是输入的指令，不对输入的指令做改变
  instr <= if_ins;       // Normal instruction fetch

// Store last instruction in the pipeline when entering hold state.
always @ (posedge clk)
/*
  功能：将挂起时输入的指令（1条）放入缓存保存
*/
if (f_fls)
  // 1.刷新时指令缓存区ins_buf清空
  ins_buf <= 0;
else if (f_nftc_cmb & f_ftc)
  // 2.上一周期没挂起，这一周期挂起了。进入挂起状态下要取数据，则将当前本应取的指令存入缓存。时输出的指令为空指令。
  ins_buf <= if_ins;
else
  // 3.其它情况下缓存ins_buf不变
  ins_buf <= ins_buf;

// ------ reg_ptr ------

localparam W_DLY = W_REG * N_PLM;
reg  [W_REG-1 : 0] reg_ptr = 0;
reg  [W_REG-1 : 0] ptr_buf = 0;
reg  [W_DLY-1 : 0] ptr_dly = 0;

always @ (posedge clk)
/*
  功能：实现指令地址的历史缓存，缓存数量为3；
  指针寄存器会读取ptr_dly高位，每访问一次就将高位指令推出，将新输入的指令推入低位；
 */
if (f_ftc)
  // 1.如果输出了流水线访问，那么将访问过的指令地址存到ptr_dly的低位
  ptr_dly <= {ptr_dly, if_adr};// ptr_dly可以装载3个指令地址if_adr
else
  // 2.如果没有访问到，则ptr_dly保持不变
  ptr_dly <= ptr_dly;

always @ (posedge clk)
/*
  功能：选择当前要输出的指针寄存器地址，即决定指针指向的位置
*/
if (f_fls | f_nftc_cmb)
  // 1.如果刷新或者挂起，则指针不变
  reg_ptr <= reg_ptr;
else if (~f_ftc)
  // 2.如果是从挂起状态恢复，则指针重新恢复为挂起前的位置
  reg_ptr <= ptr_buf;
else
  // 3.正常情况下，从指针延时的高位取值
  reg_ptr <= ptr_dly[W_DLY-1 : W_DLY-W_REG];

always @ (posedge clk)
/*
  功能：在遇到刷新或挂起时将指针地址缓存
*/
if (f_fls)
  // 1.如果进行刷新操作，则将当前指针地址存入指针缓存中
  ptr_buf <= reg_ptr;
else if (f_nftc_cmb & f_ftc)
  // 2.如果进入挂起状态下，则将当前指针保存在缓存中
  ptr_buf <= ptr_dly[W_DLY-1 : W_DLY-W_REG];
else
  // 3.其它情况下指针缓存保持不变
  ptr_buf <= ptr_buf;

endmodule
