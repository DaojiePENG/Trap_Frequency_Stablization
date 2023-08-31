// ------ Architectural Parameters ------

parameter W_REG = 32;             // Register & instruction width
parameter W_ADR = 8;              // Register address width
parameter N_REG = 1 << W_ADR;     // Maximum number of registers
parameter W_BUS = N_REG * W_REG;  // Regfile bus width
parameter W_PAD = 5;              // ALU operand pre-mux address width
parameter N_PRE = 1 << W_PAD;     // Width of pre-mux bus in number of registers
parameter W_PBS = N_PRE * W_REG;  // ALU operand pre-mux bus width
parameter W_ALU = 3 * W_REG + 4 * W_ADR + 1;
                                  // ALU output bus width
                                  // alu_out = {alu_res, alu_msk, alu_rda, alu_r0a, alu_r1a,
                                  //            imm_res, imm_rda, imm_seg}
parameter W_LSG = 20;             // Width of lower segment for Type-I immediate
parameter I_NOP = 32'h00000000;   // Null instruction
parameter N_PLM = 3;              // Pipeline latency of instruction memory: addr valid --> output valid
parameter N_PLA = 4;              // Pipeline latency of ALU: <instr> valid --> <alu_res> valid

// ------ Instruction Flag Positions ------

parameter P_ITH = 31;             // Instruction Type High: 0 for Type-I: Immediate, 1 for Type-A: ALU
parameter P_ITL = 30;             // Instruction Type Low:
                                  //   for Type-I: 0 for higher 12 bits (LDH), 1 for lower 20 bits (LDL)
                                  //   for Type-A: result inversion flag, 1 for logic inversion
                                  //               or arithmetic negation (depends on opcode) 
parameter P_HLD = 29;             // Hold flag: 1 to suspend the controller until external RESUME is asserted
parameter P_FCT = 28;             // Flow control flag: 1 to initiate pipeline flush
parameter P_RDH = 23;             // MSB / LSB of RD address field 
parameter P_RDL = 16;

// ------ Architectural Registers ------

parameter N_ACR = 4;              // Number of architectural registers
parameter R_NUL = 8'h00;          // Null register
                                  //   READ : 0
                                  //   WRITE: no effect
parameter R_PTR = 8'h01;          // Instruction pointer register
                                  //   READ : address of current instruction
                                  //   WRITE: jump to designated instruction
parameter R_WCK = 8'h02;          // Wall clock time register
                                  //   READ : lower segment of wall clock time
                                  //   WRITE: reset the wall clock to designated value
                                  //   NOTE : Only support LDL instruction, immediate is sign extended
parameter R_TIM = 8'h03;          // Count down timer register
                                  //   READ : higher segment of wall clock time
                                  //   WRITE: initiate count down
                                  //   NOTE : First read WCK, then TIM
parameter N_MND = 9;              // Minimum allowed duration of TIM, in cycles

// ------ ALU Opcodes ------

// --- Basic ---
parameter O_ADD = 4'h0;
parameter O_AND = 4'h1;
parameter O_XOR = 4'h2;

// --- Compare ---
parameter O_CLU = 4'h3;
parameter O_CLS = 4'h4;
parameter O_CEQ = 4'h5;

// --- Set ---
parameter O_SGN = 4'h6;
parameter O_SNE = 4'h7;
parameter O_SMK = 4'h8;
parameter O_MOV = 4'h9;

// --- Shift ---
parameter O_SLL = 4'hA;
parameter O_SLA = 4'hB;
parameter O_SLC = 4'hC;
parameter O_REV = 4'hD;


// ######## Detailed List of Opcodes ########
//
// + R0 and R1 can be registers with address less than 64, other than MOV opcode.
// + Immediate R0 and R1 are sign extended to 32 bits.
// + "!" prefix stands for the inversion flag bit of corresponding register.
//
// + Inv: bitwise inversion, R = ~R
// + Neg: arithmetic negation, R = ~R + 1
//
// +------------------------------------------------------------------------------------------+
// | OPC |                    RD                    |  !R0  |  !R1  |           !RD           |
// +------------------------------------------------------------------------------------------+
// | ADD |  RD = R0 + R1                            |  Neg  |  Neg  |           Neg           |
// +------------------------------------------------------------------------------------------+
// | AND |  RD = R0 & R1                            |  Inv  |  Inv  |           Inv           |
// +------------------------------------------------------------------------------------------+
// | XOR |  RD = R0 ^ R1                            |  Inv  |  Inv  |           Inv           |
// +------------------------------------------------------------------------------------------+
// | CLU |  RD = (R0 < R1) ? 32'hFFFFFFFF : 32'h0   |  Neg  |  Neg  |           Inv           |
// |     |     + unsigned compare                   |       |       |                         |
// +------------------------------------------------------------------------------------------+
// | CLS |  RD = (R0 < R1) ? 32'hFFFFFFFF : 32'h0   |  Neg  |  Neg  |           Inv           |
// |     |     + signed compare                     |       |       |                         |
// +------------------------------------------------------------------------------------------+
// | CEQ |  RD = (R0 == R1) ? 32'hFFFFFFFF : 32'h0  |  Neg  |  Neg  |           Inv           |
// +------------------------------------------------------------------------------------------+
// | SGN |  RD = R0 * sign(R1)                      |  Neg  |  Neg  |     Not Applicable      |
// |     |     + NOTE: sign(0) == 1                 |       |       |                         |
// +------------------------------------------------------------------------------------------+
// | SNE |  RD = (R1 < 0) ? R0 : RD                 |  Inv  |  Neg  | RD = (R1 < 0) ? RD : R0 |
// +------------------------------------------------------------------------------------------+
// | SMK |  RD[i] = R1[i] ? R0[i] : RD[i]           |  Inv  |  Inv  |     Not Applicable      |
// +------------------------------------------------------------------------------------------+
// | MOV |  RD = R1                                 |       |       |                         |
// |     |     + R1 can be any register             |   /   |  Inv  |       RD = R1 + 1       |
// |     |     + Use !R1 along with !RD to          |       |       |                         |
// |     |       implement arithmetic negation      |       |       |                         |
// +------------------------------------------------------------------------------------------+
// |     |  RD = R0 << R1[4:0]                      |       |       |                         |
// | SLL |     + shift right for negtive R1         |  Inv  |  Neg  |    MSB filled with 1    |
// |     |     + LSB filled with LSB of R0          |       |       |                         |
// |     |     + MSB filled with 0                  |       |       |                         |
// +------------------------------------------------------------------------------------------+
// |     |  RD = R0 << R1[4:0]                      |       |       |                         |
// | SLA |     + shift right for negtive R1         |  Inv  |  Neg  |    LSB filled with 1    |
// |     |     + LSB filled with 0                  |       |       |                         |
// |     |     + MSB filled with MSB of R0          |       |       |                         |
// +------------------------------------------------------------------------------------------+
// |     |  RD = R0 << R1[4:0]                      |       |       | Either side filled with |
// | SLC |     + shift right for negtive R1         |  Inv  |  Neg  |   inverted bits from    |
// |     |     + cyclic shift                       |       |       |   the other side.       |
// +------------------------------------------------------------------------------------------+
// | REV |  RD[i] = R0[31-i]                        |  Inv  |   /   |     Not Applicable      |
// +------------------------------------------------------------------------------------------+
