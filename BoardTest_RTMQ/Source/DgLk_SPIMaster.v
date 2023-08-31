module DgLk_SPIMaster(clk, alu_out, reg_sdat, reg_sctl, slv_adr, f_spi_done, csb, sclk, mosi, miso);
/*
描述：提供SPI的发送数据和读取接收来的SPI数据。

*/
parameter R_SDA = 0;
parameter R_SCT = 0;

`include "RTMQ_Peripheral.v"

input                clk;           // System clock
input  [W_ALU-1 : 0] alu_out;       // ALU output bus
output [W_REG-1 : 0] reg_sdat;      // Data output
output [W_REG-1 : 0] reg_sctl;      // Control output
output [ 2      : 0] slv_adr;       // Target slave address
output               f_spi_done;    // SPI Rx/Tx finish flag
output csb;
output sclk;
output mosi;
input  miso;

wire [W_REG-1 : 0] reg_sctl;        // SPI control fields
wire               f_snd;           // SPI send flag

wire [ 7      : 0] clk_div;         // SPI clock divider
wire [ 3      : 0] frm_len;         // Data frame length
wire               adr_len;         // Dest. reg. adr. length
wire [ 2      : 0] slv_adr;         // Target slave address
wire               resv;            // Placeholder
wire [ 2      : 0] miso_ltn;        // MISO latency
wire [11      : 0] dst_adr;         // Dest. reg. adr.

assign {clk_div, frm_len, adr_len, slv_adr, resv, miso_ltn, dst_adr} = reg_sctl;
RTMQ_GPRegister #(.ADDR(R_SCT)) // 0.输出控制字reg_sctl
  RCTL(.clk(clk), .alu_out(alu_out), .reg_out(reg_sctl), .f_trg(f_snd));

localparam W_SPI = W_REG * N_SDAT;
wire [W_SPI-1 : 0] d_spi_out; // 2.将该地址上的数据（N_SDAT个字）移位输出到d_spi_out
RTMQ_OutputSR #(.ADDR(R_SDA), .N_SRL(N_SDAT))
// 通过SPI发送数据
  ROSR(.clk(clk), .alu_out(alu_out), .dat_out(d_spi_out));

wire [W_SPI-1 : 0] d_spi_ret;
wire               f_spi_rcv;
RTMQ_InputSR #(.ADDR(R_SDA), .N_SRL(N_SDAT))
// 读取SPI接受到的数据
  // 3.1 在本地址被选时，输出上次N_SDAT个字的缓存d_spi_ret中的最低字为reg_sdat
  // 3.2 在f_spi_rcv信号的作用下装载数据 d_spi_ret ，该数据从SPI来
  // 3.3 SPI_Core中接收完从机的数据就会给出f_spi_rcv信号，将输出结果d_spi_ret装载入输入位移寄存器中；
  // 3.4 接着在寄存器的每一次访问，移位给出缓存器中的数；
  RISR(.clk(clk), .alu_out(alu_out), .reg_isr(reg_sdat),
       .dat_in(d_spi_ret), .f_load(f_spi_rcv));

localparam W_INS = W_SPI + 16;// 为什么要多16位呢？ ins_buf 多了这16个dst_adr[11], 4'h0, dst_adr[10:0]
wire [W_INS-1 : 0] t_spi_ret;
reg  [W_INS-1 : 0] ins_buf = 0;
reg  [ 7      : 0] d_clk_div = 0;
reg  [ 7      : 0] d_bit_cnt = 0;
reg  [ 2      : 0] d_miso_ltn = 0;
reg                f_snd_dly = 0;
reg                f_spi_done = 0;
assign d_spi_ret = t_spi_ret[W_SPI-1 : 0];
always @ (posedge clk)
begin
  f_spi_done <= f_spi_rcv;
  f_snd_dly <= f_snd;
  d_clk_div <= clk_div;
  d_bit_cnt <= (frm_len + adr_len + 1) << 3;
  d_miso_ltn <= miso_ltn;
  ins_buf <= adr_len ? {dst_adr[11], 4'h0, dst_adr[10:0], d_spi_out} : {dst_adr[7:0], d_spi_out, 8'h00};
end

Core_SPIMaster #(.W_DAT(W_INS), .W_CNT(8))
  // 4.1 SPI是一种主设备和从设备互换数据的通信方式；
  // 4.2
  SPIM(.clk(clk), .dat_mosi(ins_buf), .dat_miso(t_spi_ret),
       .cpol(SPI_CPOL), .cpha(SPI_CPHA), .clk_div(d_clk_div), .bit_cnt(d_bit_cnt),
       .f_snd(f_snd_dly), .f_fin(f_spi_rcv), .miso_ltn(d_miso_ltn), .mosi_cnt(0), .bus_dir(),
       .csb(csb), .sclk(sclk), .mosi(mosi), .miso(miso));

endmodule
