module RTMQ_GPRegister(clk, alu_out, reg_out, f_trg);

parameter ADDR = 0;                 // Address of this register

`include "RTMQ_Header.v"

input                clk;           // System clock
input  [W_ALU-1 : 0] alu_out;       // ALU output bus
output [W_REG-1 : 0] reg_out;       // Data output
output               f_trg;         // Delayed <alu_wse> / <imm_wse>

// ------ Timing Diagram ------
//
// REG: Register address    NEW: New value    OLD: Old value    VLD: Data valid
//
// clk    : /'''\.../'''\.../'''\.../  # system clock
// *_rda  : |  REG  |  ---  |  ---  |  # RD address from either A or I channel
// f_wrt  : |  ---  |   1   |  ---  |  # register write flag
// res/msk: |  ---  |  NEW  |  ---  |  # ALU output
// reg_out: |  OLD  |  OLD  |  NEW  |  # register output
// *_wse  : |  VLD  |  ---  |  ---  |  # side effect trigger
// f_trg  : |  ---  |  ---  |  VLD  |  # side effect trigger, delayed output

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

wire f_wrt_alu;
wire f_wrt_ihi;
wire f_wrt_ilo;
RTMQ_AcsFlg #(.ADDR(ADDR))
  FACS(.clk(clk), .alu_out(alu_out), .f_read(), .f_wrt_alu(f_wrt_alu),
       .f_wrt_ihi(f_wrt_ihi), .f_wrt_ilo(f_wrt_ilo));

reg  [W_REG-1 : 0] reg_out = 0;     // Register data
always @ (posedge clk)
if (f_wrt_ihi)                      // I channel has higher priority, but do avoid such conflict.
  reg_out <= {imm_res[W_REG-1 : W_LSG], reg_out[W_LSG-1 : 0]};
else if (f_wrt_ilo)
  reg_out <= {reg_out[W_REG-1 : W_LSG], imm_res[W_LSG-1 : 0]};
else if (f_wrt_alu)
  reg_out <= alu_res | (reg_out & alu_msk);
else
  reg_out <= reg_out;

reg  f_trg = 0;
always @ (posedge clk) f_trg <= f_wrt_ilo | f_wrt_alu;

endmodule
