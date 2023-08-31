// ------ Set-Reset Flag ------
//   Assert <flg> when <set> is high.
//   Deassert <flg> when <rst> is high.
//   Latency: set --> flg: 1 cycle
// ----------------------------

module SRFlag(clk, set, rst, flg);// 目的应该是防止set和rst冲突

parameter Pri = "set";    // or "rst", determines the priority of <set> and <rst> when both are high
parameter PUS = 0;        // Power-up state of <flg>

input  clk;
input  set;
input  rst;
output flg;

reg  flg = PUS;
always @ (posedge clk) 
case (Pri)
  "rst": flg <= (set | flg) & ~rst;// 当set和rst都为高时听rst的，结果flg为低
  "set": flg <=  set | (flg & ~rst);// 当set和rst都为高时听set的，结果flg为高
  default: flg <= PUS;
endcase

endmodule

// ------ Edge Identifier ----------
//   Convert edges in <sig> to 1-cycle pulses.
//   Latency: <sig> edge --> <out> valid: 2 cycles
// ---------------------------

module EdgeIdfr(clk, sig, out);

parameter Edg = "pos";   // or "neg", "both", sensitive edge types
parameter W = 1;         // Width of <sig>
parameter PUS = 0;       // Power-up state of <sig>

input            clk;
input  [W-1 : 0] sig;
output [W-1 : 0] out;

reg [W-1 : 0] dly = PUS;
reg [W-1 : 0] out = 0;
always @ (posedge clk) dly <= sig;

always @ (posedge clk) 
case (Edg)
  "pos"  : out <=  sig & ~dly;
  "neg"  : out <= ~sig &  dly;
  "both" : out <=  sig ^  dly;
  default: out <=  0;
endcase

endmodule

// ------ Wide Bus Multiplexer ------
//   Multiplexes 1-D bus in words.
//   Totally combinatorial.
// ----------------------------------

module WideMux(bus, sel, out);

parameter W_WRD = 32;           // Data word width
parameter W_SEL = 5;            // Width of <sel>

localparam N_WRD = 1 << W_SEL;  // Bus width in number of words

input  [N_WRD*W_WRD-1 : 0] bus;
input  [W_SEL-1       : 0] sel;
output [W_WRD-1       : 0] out;

wire [W_WRD-1 : 0] tmp [0 : N_WRD-1];

genvar i;
generate
  for (i = 0; i < N_WRD; i = i + 1)
  begin
    // 将bus打包成内存格式，以供选择信号片选
    assign tmp[i] = bus[W_WRD*(i+1)-1 : W_WRD*i];
    
  end
endgenerate

assign out = tmp[sel];

endmodule
