module Core_SPIMaster(clk, dat_mosi, dat_miso,
                      cpol, cpha, clk_div, bit_cnt, f_snd, f_fin,
                      miso_ltn, mosi_cnt, bus_dir,
                      csb, sclk, mosi, miso);
/*
描述：
1.输出- 在f_snd跳动信号来时将待发送给主机的信号dat_mosi，存入发送缓存器txd_buf中；
  随后在f_stx & tck_dly时，按bit发送缓存器txd_buf中的最高位mosi并向左移位，用bit_cnt进行计数，为0时输出结束信号f_fin；
2.输入- 在f_stx & tck_dly也就是发送bit的同时，进行数据接收，将从机传来的1bit数据miso移位添加到接受寄存器rxd_buf的低位；
  接收过程持续到发送结束，在给出结束信号fin_pre的前一周期将缓存器中的数据传输到dat_miso中输出，以供读取；
3.时钟- 在整个过程中为从机提供时钟sclk;
4.注：clk_div、miso_ltn、mosi_cnt、bus_dir、csb
2023年2月18日01:01:15- PENG Daojie
*/

parameter W_DAT = 32;              // Width of data frame buffer
parameter W_CNT = 8;               // Width of bit counter & clock divider

input                clk;          // System clock
input  [W_DAT-1 : 0] dat_mosi;     // MOSI data frame
output [W_DAT-1 : 0] dat_miso;     // MISO data frame
input                cpol;         // Clock polarization
input                cpha;         // Clock phase
input  [W_CNT-1 : 0] clk_div;      // Clock divider
                                   //   + F_sclk = F_clk / (clk_div + 1) / 2
input  [W_CNT-1 : 0] bit_cnt;      // Number of bits in the transaction
input                f_snd;        // Send flag (one-cycle positive pulse)
output               f_fin;        // Transaction finish flag (one-cycle positive pulse)
input  [ 2      : 0] miso_ltn;     // MISO data latency 
input  [W_CNT-1 : 0] mosi_cnt;     // Number of MOSI bits (for 3-wire only)
                                   //   + For 3-wire read transaction, <mosi_cnt> is the
                                   //     number of address bits for slave register.
                                   //   + For write transaction, set <mosi_cnt> to -1.
output               bus_dir;      // Bus direction flag (for 3-wire only)
                                   //   + Connect <mosi> and <miso> to one tri-state port
                                   //     and use this signal as tri-state indicator.
                                   //   + <bus_dir> == 1 for MISO
                                   //   + Example: sdio = bus_dir ? 1'bz : mosi
output               csb;          // SPI signal: CSB
output               sclk;         // SPI signal: SCLK
output               mosi;         // SPI signal: MOSI
input                miso;         // SPI signal: MISO

// ------ Output Buffering ------

reg  bus_dir_buf = 0;              // Buffer register for <bus_dir>
reg  csb_buf = 1'b1;               // Buffer register for CSB
reg  sclk_buf = 0;                 // Buffer register for SCLK
reg  mosi_buf = 0;                 // Buffer register for MOSI
reg  bus_dir_iob = 0;              // IOB register for <bus_dir>
reg  csb_iob = 1'b1;               // IOB register for CSB
reg  sclk_iob = 0;                 // IOB register for SCLK
reg  mosi_iob = 0;                 // IOB register for MOSI
reg  miso_iob = 0;                 // IOB register for MISO
assign {bus_dir, csb, sclk, mosi} = {bus_dir_iob, csb_iob, sclk_iob, mosi_iob};
always @ (posedge clk)
  {bus_dir_iob, csb_iob, sclk_iob, mosi_iob, miso_iob} <= {bus_dir_buf, csb_buf, sclk_buf, mosi_buf, miso};

// ------ State Registers & Flags ------

reg  [W_DAT-1 : 0] dat_miso = 0;   // MISO data output
reg  [W_DAT-1 : 0] txd_buf = 0;    // Write data buffer
reg  [W_DAT-1 : 0] rxd_buf = 0;    // Read data buffer
reg  [W_CNT-1 : 0] ctr_bit = 0;    // Bit counter
reg  [W_CNT-1 : 0] ctr_div = 0;    // Clock divide counter
reg  [W_CNT-1 : 0] buf_div = 0;    // Clock divider buffer
reg  [W_CNT-1 : 0] ctr_mosi = 0;   // MOSI bit counter

reg  f_tck = 0;                    // Clock divider tick
reg  f_stx = 1'b1;                 // Tx buffer shift flag
reg  f_srx = 0;                    // Rx buffer sampling flag
reg  tck_dly = 0;                  // delayed <f_tck>
reg  f_fin = 0;                    // Transaction finish flag
wire f_bsy;                        // Busy state flag
wire w_fin = f_bsy & (ctr_bit == 0) & ~f_stx & tck_dly; // 这个条件是什么意思，为了检测什么状态？
// f_bsy:发送脉冲f_snd后的一个周期它是1，1状态保持到w_fin=0的下个周期；
// ctr_bit == 0：当比特数发送完后是1；
// ~f_stx: 未在发送状态，f_snd后的第一个f_tck的下一周期为1；
// tck_dly: 上一个f_tck为1时为1；也就是保证了只有在第一次f_tck时会产生有效；

SRFlag #(.Pri("set"), .PUS(1'b0))
  FBSY(.clk(clk), .set(f_snd), .rst(w_fin), .flg(f_bsy));

// ------ Divided Clock Generation ------

reg  [ 7 : 0] f_srx_ppl = 0;
always @ (posedge clk)
begin
  if (f_snd) buf_div <= clk_div; // 1.发送信号f_snd来时，将输入的clk_div传到缓存器buf_div中
  f_tck <= f_bsy & ((ctr_div == 1) | (buf_div == 0));
  if (f_snd)
  // 1.发送信号f_snd来时，clk_div通过一个延时传递给时钟分频计数器ctr_div
    ctr_div <= clk_div;
  else if (f_tck)
  // 2.如果是时钟分频跳动信号f_tck来时，clk_div通过buf_div延时两个时钟周期后传递给时钟分频计数器ctr_div
    ctr_div <= buf_div;
  else
  // 3.其它情况时钟分频计数器ctr_div进行-1倒计数，计数到1时配合忙碌状态信号f_bsy给出一个时钟分频跳动f_tck
    ctr_div <= ctr_div - 1;

  if (f_snd)
  // 1.当脉冲发送信号f_snd来时，传输信号置1
    f_stx <= 1'b1;
  else
  // 2.非发送状态时，传输信号跟随f_tck状态变化
    f_stx <= f_stx ^ f_tck;// 为什么要这样？为了检测什么事件？到下一个脉冲来时从1翻转到0，下次再反转；

  tck_dly <= f_tck;
  f_srx_ppl <= {f_srx_ppl, f_stx & tck_dly};// 将状态放入缓存其中
  f_srx <= f_srx_ppl[miso_ltn];// 取出接收信号f_srx
end

// ------ Buffers & Counters ------

always @ (posedge clk)
if (f_snd)
// 1.在外部输入的f_snd信号作用下将输入的dat_mosi数据加入发送缓存器中，同时将比特计数器ctr_bit和ctr_mosi装载；
begin
  txd_buf <= dat_mosi;
  ctr_bit <= bit_cnt;
  ctr_mosi <= mosi_cnt;
end
else if (f_stx & tck_dly)
// 2.当缓存器移位使能且tck_dly有效时，按bit移动缓存器发送数据，同时控制比特ctr_bit和ctr_mosi进行-1计数
begin
  txd_buf <= txd_buf << 1;
  ctr_bit <= ctr_bit - 1;
  ctr_mosi <= ctr_mosi - 1;
end
// 3.其它情况状态保持不变
else {rxd_buf, txd_buf, ctr_bit, ctr_mosi} <= {rxd_buf, txd_buf, ctr_bit, ctr_mosi};

always @ (posedge clk)
if (f_snd)
// 1.发送信号f_snd来时，将接收缓存器清零
  rxd_buf <= 0;
else if (f_srx)
// 2.接受信号f_srx来时，接收缓存器左移位寄存1比特miso_iob
  rxd_buf <= {rxd_buf, miso_iob};
else
// 3.其它情况状态保持不变
  rxd_buf <= rxd_buf;

// ------ Output Behavior ------

reg           fin_pre = 0;
reg  [ 7 : 0] fin_ppl = 0;
always @ (posedge clk)
// 生成结束信号f_fin
begin
  fin_ppl <= {fin_ppl, w_fin};
  fin_pre <= fin_ppl[miso_ltn];// 好像突然想到为什么要miso时延了，可能因为不同slave来的信号可能不一样这个需要做成可调节的
  f_fin <= fin_pre;
  if (fin_pre)
  // 1.结束前一周期把接受结果传入从机向主机发送到数据寄存器dat_miso中，在下一周期与结束信号f_fin同时被输出
    dat_miso <= rxd_buf;
  else
  // 2.在结束前一直保持前一次接受的数据dat_miso输出
    dat_miso <= dat_miso;
end

always @ (posedge clk)
// 主机输出1比特mosi生成器，发送缓存器的最高位；
if (~f_stx & tck_dly)
  mosi_buf <= txd_buf[W_DAT-1];
else
  mosi_buf <= mosi_buf;

wire f_tmp = (ctr_bit == 0) | (ctr_bit == {{(W_CNT){1'b1}}});
always @ (posedge clk)
// 从机时钟信号生成器
if (f_snd | (f_tmp & tck_dly))
  sclk_buf <= cpol;// 时钟极化？
else if (tck_dly)
  sclk_buf <= f_stx ^ cpha ^ cpol;// 发送信号、时钟极化、时钟相位？
else
  // 正常情况下保持不变
  sclk_buf <= sclk_buf;

always @ (posedge clk)
// 总线方向标志bus_dir生成
if (f_snd)
  bus_dir_buf <= 0;
else if ((ctr_mosi == 0) & ~f_stx & tck_dly)
  bus_dir_buf <= ~bus_dir_buf;
else
  bus_dir_buf <= bus_dir_buf;

always @ (posedge clk) csb_buf <= ~f_bsy;

endmodule
