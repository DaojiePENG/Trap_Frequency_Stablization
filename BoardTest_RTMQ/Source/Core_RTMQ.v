module Core_RTMQ(clk, alu_out, regfile,      // ALU signals
                 if_adr, if_ins, f_ftc,      // Instruction fetch (IF) signals
                 f_hld, f_rsm,               // Flow control signals
                 f_cfg, cfg_ins);            // Core configuration signals

`include "RTMQ_Header.v"

input                clk;       // System clock
output [W_ALU-1 : 0] alu_out;   // alu_out = {alu_res, alu_msk, rd_adr, r0_adr, r1_adr, se_trg}
input  [W_BUS-1 : 0] regfile;   // Register file input

output [W_REG-1 : 0] if_adr;    // IF address
input  [W_REG-1 : 0] if_ins;    // IF input
output               f_ftc;     // IF pipeline fetch flag (clock enable for block ram)
output               f_hld;     // Core HOLD state indicator
input                f_rsm;     // External RESUME flag

input                f_cfg;     // Configuration override flag
input  [W_REG-1 : 0] cfg_ins;   // Configuration instruction

wire [W_REG-1 : 0] instr;
wire [W_REG-1 : 0] reg_wck;
wire [W_REG-1 : 0] reg_tim;
wire [W_REG-1 : 0] reg_ptr;
wire [W_BUS-1 : 0] rf_int = {regfile[W_BUS-1 : N_ACR*W_REG], reg_tim, reg_wck, reg_ptr, 32'b0};
wire               f_hld;
wire               f_timout;

RTMQ_ALU
  iALU(.clk(clk), .alu_out(alu_out),
       .instr(instr), .regfile(rf_int));

RTMQ_FlowController
  iFCT(.clk(clk), .alu_out(alu_out), .reg_ptr(reg_ptr),
       .if_adr(if_adr), .if_ins(if_ins), .f_ftc(f_ftc),
       .instr(instr), .f_hld(f_hld), .f_rsm(f_rsm | f_timout),
       .f_cfg(f_cfg), .cfg_ins(cfg_ins));

RTMQ_Timer
  iTIM(.clk(clk), .alu_out(alu_out), .reg_wck(reg_wck), .reg_tim(reg_tim),
       .f_hld(f_hld), .f_timout(f_timout));

endmodule
