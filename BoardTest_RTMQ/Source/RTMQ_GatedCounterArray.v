module RTMQ_GatedCounterArray(clk, alu_out, pulse, reg_ctr);

`include "RTMQ_Peripheral.v"

localparam W_OCT = N_CTR * W_REG;

input                clk;           // System clock
input  [W_ALU-1 : 0] alu_out;       // ALU output bus
input  [N_CTR-1 : 0] pulse;         // Counting pulses input
output [W_OCT-1 : 0] reg_ctr;       // All counters' output

wire [N_CTR-1 : 0] f_ena;           // Counter enable
RTMQ_GPRegister #(.ADDR(R_ECTR))
  ECTR(.clk(clk), .alu_out(alu_out), .reg_out(f_ena), .f_trg());

reg  [N_CTR-1 : 0] pls_iob = 0;
reg  [N_CTR-1 : 0] pls_ppl = 0;
wire [N_CTR-1 : 0] f_rst;
wire [N_CTR-1 : 0] f_smp;
wire [N_CTR-1 : 0] f_pls;
always @ (posedge clk) {pls_ppl, pls_iob} <= {pls_iob, pulse};
EdgeIdfr #(.Edg("pos"), .W(N_CTR), .PUS(0)) ERST(.clk(clk), .sig(f_ena), .out(f_rst));
EdgeIdfr #(.Edg("neg"), .W(N_CTR), .PUS(0)) ESMP(.clk(clk), .sig(f_ena), .out(f_smp));
EdgeIdfr #(.Edg("pos"), .W(N_CTR), .PUS(0)) EPLS(.clk(clk), .sig(pls_ppl), .out(f_pls));

genvar i;
generate
  for (i = 0; i < N_CTR; i = i + 1)
  begin: GCTR
    
    Core_GatedCounter #(.W_CTR(W_REG))
      iCTR(.clk(clk), .in(f_pls[i]), .rst(f_rst[i]), .smp(f_smp[i]), .out(reg_ctr[W_REG*(i+1)-1 : W_REG*i]));

  end
endgenerate

endmodule
