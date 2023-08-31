module FuncMod_DDS(clk, fclk, instr, exec, d_in,
                   prof_1, io_upd_1, io_rst_1, m_rst_1,
                   prof_0, io_upd_0, io_rst_0, m_rst_0,
                   tx_en_1, pf_1, pdat_1,
                   tx_en_0, pf_0, pdat_0);

`include "Config.v"

input  clk;                        // System clock
input  fclk;                       // Fast output clock
input  [InsWid-1 : 0] instr;       // Current instruction
input  exec;                       // Flag of instruction execution
input  [RegWid-1 : 0] d_in;        // Data input
output [2 : 0] prof_1;             // Profile
output io_upd_1;                   // I/O update
output io_rst_1;                   // I/O reset
output m_rst_1;                    // Master reset
output [2 : 0] prof_0;             // Profile
output io_upd_0;                   // I/O update
output io_rst_0;                   // I/O reset
output m_rst_0;                    // Master reset
output tx_en_1;                    // Tx enable
output [1 : 0] pf_1;               // Parallel data type
output [15 : 0] pdat_1;            // Parallel data
output tx_en_0;                    // Tx enable
output [1 : 0] pf_0;               // Parallel data type
output [15 : 0] pdat_0;            // Parallel data

wire [RegWid-1 : 0] cds;
assign io_rst_1 = cds[9];
assign io_rst_0 = cds[1];
DgLk_GPRegister #(A_CDDS) iREG_CDDS(clk, instr, exec, d_in, cds);

// assign {1'b0, prof_mono_1, 1'b0, io_upd_1, io_rst_1, m_rst_1,
//         1'b0, prof_mono_0, 1'b0, io_upd_0, io_rst_0, m_rst_0} = cds;

wire [RegWid-1 : 0] cpb;
wire [1 : 0] nil;
wire [3 : 0] plbk_ctrl_1;
wire [3 : 0] plbk_ctrl_0;
assign {plbk_ctrl_1, nil[1], pf_1, tx_en_1,
        plbk_ctrl_0, nil[0], pf_0, tx_en_0} = cpb;
DgLk_GPRegister #(A_CPBK) iREG_CPBK(clk, instr, exec, d_in, cpb);

wire [RegWid-1 : 0] plbk_dat_1;
wire [RegWid-1 : 0] plbk_dat_0;
DgLk_Playback #(A_PBK1, RegWid) PBK1(clk, fclk, instr, exec, d_in, plbk_ctrl_1, plbk_dat_1);
DgLk_Playback #(A_PBK0, RegWid) PBK0(clk, fclk, instr, exec, d_in, plbk_ctrl_0, plbk_dat_0);

reg [ 2 : 0] prof_buf_1 = 0;
reg [ 2 : 0] prof_buf_0 = 0;
always @(posedge fclk) prof_buf_1 <= plbk_ctrl_1[1] ? plbk_dat_1[2:0] : cds[14:12];
always @(posedge fclk) prof_buf_0 <= plbk_ctrl_0[1] ? plbk_dat_0[2:0] : cds[ 6: 4];

wire [20 : 0] abus1_i = {plbk_dat_1, prof_buf_1, cds[10], cds[8]};
wire [20 : 0] abus0_i = {plbk_dat_0, prof_buf_0, cds[ 2], cds[0]};
wire [20 : 0] abus1_o;
wire [20 : 0] abus0_o;
DgLk_AlignedBus #(A_ABS1, 21, 84) BUS1(clk, fclk, instr, exec, d_in, abus1_i, abus1_o);
DgLk_AlignedBus #(A_ABS0, 21, 84) BUS0(clk, fclk, instr, exec, d_in, abus0_i, abus0_o);

assign {pdat_1, prof_1, io_upd_1, m_rst_1} = abus1_o;
assign {pdat_0, prof_0, io_upd_0, m_rst_0} = abus0_o;

endmodule
