module Core_CORDIC(clk, x, y, z, rx, ry, rz);

parameter MODE = 0;                     // Operation mode: 0-rotation, 1-vector
parameter W_NIO = 16;                   // Width of input / output numbers
parameter W_CAL = 32;                   // Width used in calculation, W_CAL <= 96
parameter N_ITR = 16;                   // Number of iterations, N_ITR <= 32
                                        // Pipeline latency: N_ITR + 5

input                clk;               // System clock
input  [W_NIO-1 : 0] x;                 // X input, signed
input  [W_NIO-1 : 0] y;                 // Y input, signed
input  [W_NIO-1 : 0] z;                 // Z input, signed, in unit of Pi
output [W_NIO-1 : 0] rx;                // X output, signed
output [W_NIO-1 : 0] ry;                // Y output, signed
output [W_NIO-1 : 0] rz;                // Z output, signed, in unit of Pi

localparam M_WID = 96;
localparam M_ITR = 32;
localparam [M_ITR*M_WID-1 : 0] Ei = {
  96'h00000000517CC1B727220A95, 96'h00000000A2F9836E4E441527, 96'h0000000145F306DC9C882A39, 
  96'h000000028BE60DB9391053CF, 96'h0000000517CC1B727220A285, 96'h0000000A2F9836E4E4411C4D, 
  96'h000000145F306DC9C880F2A6, 96'h00000028BE60DB9390F7B5B4, 96'h000000517CC1B727219DEEA6, 
  96'h000000A2F9836E4E40AFF73F, 96'h00000145F306DC9C6D00BE11, 96'h0000028BE60DB9383707F8B3, 
  96'h00000517CC1B726B5643D5F3, 96'h00000A2F9836E4ADEE26D055, 96'h0000145F306DC815E946C44B, 
  96'h000028BE60DB85FC3A56AB55, 96'h0000517CC1B6BA7BB2F723FE, 96'h0000A2F9836AE91158539DB4, 
  96'h000145F306C172F246AF4BFA, 96'h00028BE60CDFEC61994B7616, 96'h000517CC14A80CB70788F004, 
  96'h000A2F980091BA7B67F43A92, 96'h00145F2EBB30AB37B9341F2D, 96'h0028BE5346D0C336FC917A6F, 
  96'h00517C5511D442AEA2C306CB, 96'h00A2F61E5C28262984D6BF59, 96'h0145D7E159046278569C94DF, 
  96'h028B0D430E589AECC0CC0012, 96'h051111D41DDD9A1B7F9255CB, 96'h09FB385B5EE39E8DDF43F3CA, 
  96'h12E4051D9DF308665688F6DB, 96'h200000000000000000000000
};

// ------ Coarse Rotation ------

reg  [W_CAL-1 : 0] sx = 0;
reg  [W_CAL-1 : 0] sy = 0;
reg  [W_CAL-1 : 0] sz = 0;
reg  [N_ITR+3 : 0] f_inv = 0;
reg  [N_ITR+3 : 0] sgn_x = 0;

always @ (posedge clk)
begin
  f_inv <= {f_inv[N_ITR+2 : 0], z[W_NIO-1] ^ z[W_NIO-2]};
  sgn_x <= {sgn_x[N_ITR+2 : 0], x[W_NIO-1]};
  sx <= {x, {(W_CAL - W_NIO){1'b0}}};
  sy <= {y, {(W_CAL - W_NIO){1'b0}}};
  sz <= {z[W_NIO-2], z[W_NIO-2 : 0], {(W_CAL - W_NIO){1'b0}}};
end

// ------ Prescale ------

reg  [3*W_CAL-1 : 0] sz_ppl = 0;
always @ (posedge clk) sz_ppl <= {sz_ppl[2*W_CAL-1 : 0], sz};

wire [W_CAL-1 : 0] scld_x;
wire [W_CAL-1 : 0] scld_y;

CORDIC_MultK #(.W_CAL(W_CAL))
  SCLX(.clk(clk), .inp(sx), .out(scld_x));
CORDIC_MultK #(.W_CAL(W_CAL))
  SCLY(.clk(clk), .inp(sy), .out(scld_y));

// ------ Iterations ------

wire [W_CAL-1 : 0] w_x [0 : N_ITR];
wire [W_CAL-1 : 0] w_y [0 : N_ITR];
wire [W_CAL-1 : 0] w_z [0 : N_ITR];

assign w_x[0] = scld_x;
assign w_y[0] = scld_y;
assign w_z[0] = sz_ppl[3*W_CAL-1 : 2*W_CAL];

genvar i;
generate
  for (i = 1; i <= N_ITR; i = i + 1)
  begin: ITER
    
    CORDIC_Iter #(.MODE(MODE), .W_CAL(W_CAL), .S_ITR(i-1))
      ITRX(.clk(clk), .x(w_x[i-1]), .y(w_y[i-1]), .z(w_z[i-1]),
           .Ei(Ei[M_WID*i-1 : M_WID*i-W_CAL]),
           .rx(w_x[i]), .ry(w_y[i]), .rz(w_z[i]));
    
  end
endgenerate

// ------ Output ------

reg  [W_CAL-1 : 0] fx = 0;
reg  [W_CAL-1 : 0] fy = 0;
reg  [W_CAL-1 : 0] fz = 0;
wire [W_NIO-1 : 0] rx = fx[W_CAL-1 : W_CAL-W_NIO];
wire [W_NIO-1 : 0] ry = fy[W_CAL-1 : W_CAL-W_NIO];
wire [W_NIO-1 : 0] rz = fz[W_CAL-1 : W_CAL-W_NIO];

always @ (posedge clk)
begin
  fx <= ({{W_CAL{f_inv[N_ITR+3]}}} ^ w_x[N_ITR]) + f_inv[N_ITR+3];
  fy <= ({{W_CAL{f_inv[N_ITR+3]}}} ^ w_y[N_ITR]) + f_inv[N_ITR+3];
  fz <= {sgn_x[N_ITR+3], {(W_CAL-1){1'b0}}} ^ w_z[N_ITR];
end

endmodule


module CORDIC_Iter(clk, x, y, z, Ei, rx, ry, rz);

parameter MODE = 0;                     // Operation mode: 0-rotation, 1-vector
parameter W_CAL = 32;                   // Width used in calculation
parameter S_ITR = 0;                    // Current stage of iteration

input                clk;               // System clock
input  [W_CAL-1 : 0] x;                 // X input, signed
input  [W_CAL-1 : 0] y;                 // Y input, signed
input  [W_CAL-1 : 0] z;                 // Z input, signed, in unit of Pi
input  [W_CAL-1 : 0] Ei;
output [W_CAL-1 : 0] rx;                // X output, signed
output [W_CAL-1 : 0] ry;                // Y output, signed
output [W_CAL-1 : 0] rz;                // Z output, signed, in unit of Pi

reg  [W_CAL-1 : 0] rx = 0;
reg  [W_CAL-1 : 0] ry = 0;
reg  [W_CAL-1 : 0] rz = 0;

wire sign = MODE ? (x[W_CAL-1] ^ y[W_CAL-1]) : (~z[W_CAL-1]);
wire [W_CAL-1 : 0] sx = {{(S_ITR+1){x[W_CAL-1]}}, x[W_CAL-2 : S_ITR]};
wire [W_CAL-1 : 0] sy = {{(S_ITR+1){y[W_CAL-1]}}, y[W_CAL-2 : S_ITR]};

always @ (posedge clk)
if (sign)
begin
  rx <= x - sy;
  ry <= y + sx;
  rz <= z - Ei;
end
else
begin
  rx <= x + sy;
  ry <= y - sx;
  rz <= z + Ei;
end

endmodule


module CORDIC_MultK(clk, inp, out);

// Constant Booth Multiplier
// K = 2^(-1) + 2^(-3) - 2^(-6) - 2^(-9) - 2^(-12) + 2^(-14) + 2^(-16) - 2^(-20)
// Pipeline latency: 3

parameter W_CAL = 32;

input                clk;
input  [W_CAL-1 : 0] inp;
output [W_CAL-1 : 0] out;

wire [W_CAL+19 : 0] sgn_ext = {{20{inp[W_CAL-1]}}, inp[W_CAL-1 : 0]};
wire [W_CAL- 1 : 0] rs01 = sgn_ext[W_CAL    :  1];
wire [W_CAL- 1 : 0] rs03 = sgn_ext[W_CAL+ 2 :  3];
wire [W_CAL- 1 : 0] rs06 = sgn_ext[W_CAL+ 5 :  6];
wire [W_CAL- 1 : 0] rs09 = sgn_ext[W_CAL+ 8 :  9];
wire [W_CAL- 1 : 0] rs12 = sgn_ext[W_CAL+11 : 12];
wire [W_CAL- 1 : 0] rs14 = sgn_ext[W_CAL+13 : 14];
wire [W_CAL- 1 : 0] rs16 = sgn_ext[W_CAL+15 : 16];
wire [W_CAL- 1 : 0] rs20 = sgn_ext[W_CAL+19 : 20];

reg  [W_CAL-1 : 0] ps0_0 = 0;
reg  [W_CAL-1 : 0] ps0_1 = 0;
reg  [W_CAL-1 : 0] ps0_2 = 0;
reg  [W_CAL-1 : 0] ps0_3 = 0;
reg  [W_CAL-1 : 0] ps1_0 = 0;
reg  [W_CAL-1 : 0] ps1_1 = 0;
reg  [W_CAL-1 : 0] out = 0;

always @ (posedge clk)
begin
  ps0_0 <= rs01 + rs03;
  ps0_1 <= rs06 + rs09;
  ps0_2 <= rs12 + rs20;
  ps0_3 <= rs14 + rs16;
  ps1_0 <= ps0_0 - ps0_1;
  ps1_1 <= ps0_2 - ps0_3;
  out <= ps1_0 - ps1_1;
end

endmodule
