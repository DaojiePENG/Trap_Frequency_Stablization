`include "RTMQ_Header.v"

parameter F_CLK = 200000000;      // System clock rate in Hz

// ######### Architectural Peripherals #########

// --- Main Memory ---
// R_ADR: main memory data port address register
// R_DAT: Main memory data port read/write register
//   Read : data in main memory at R_ADR
//   Write: write data to main memory at R_ADR

parameter R_ADR = 8'h04;
parameter R_DAT = 8'h05;
parameter N_MEM = 65536;

// --- Return Address Stack ---
// Read : pop the top element out
// Write: push the value into the stack

parameter R_RTS = 8'h06;
parameter N_RTS = 32;             // Return stack depth

// --- Data Stack ---
// Read : pop the top element out
// Write: push the value into the stack

parameter R_STK = 8'h07;
parameter N_STK = 4096;           // Data stack depth

// --- UART Interface ---
// Read : data frame received (currently used as override instruction)
// Write: send data out through UART

parameter R_URT = 8'h08;
parameter F_BDR = 4000000;        // Baud rate in Hz

// --- Unsigned Multiplier ---
// Read : result output of the multiplier (MUH: higher seg. / MUL: lower seg.)
// Write: operand input

parameter R_MUL = 8'h09;
parameter R_MUH = 8'h0A;

// --- 64bit Combined Tausworthe Generator ---
// RND: Random number (read only)

parameter R_RND = 8'h0B;




// !!! DUT: ExtUART ---

parameter R_DUTI = 8'h0C;
parameter R_DUTC = 8'h0D;

// --------------------


// --- General Purpose Register (GPR) ---

parameter R_GPR = 8'h0E;          // Start address of GPR
parameter N_GPR = 27;             // Number of GPRs

// ######### Functional Peripherals #########

parameter S_FPR = R_GPR + N_GPR;  // Start address of Functional Peripheral Registers

// --- LED ---

parameter R_LED = S_FPR + 8'h00;

// ------ SPI Master ------

// SDAT: SPI data register (shift register)
//   Read : data returned from slaves 
//   Write: data to be sent to slaves
// SCTL: SPI control register
//   Read : value of SCTL
//   Write: send data to slaves
//   Structure:
//     SCTL[31 : 24]: SPI clock divider
//     SCTL[23 : 20]: data frame length in bytes (excluding reg. addr.)
//     SCTL[19]     : slave register address length (0: 1 byte / 1: 2 bytes)
//     SCTL[18 : 16]: target slave address
//     SCTL[15]     : Reserved
//     SCTL[14 : 12]: MISO latency
//     SCTL[11 :  0]: destination register address in slave

parameter R_SDAT = S_FPR + 8'h01;
parameter R_SCTL = S_FPR + 8'h02;

// --- SPI Parameters ---

parameter N_SDAT = 4;             // Length of SDAT in words

parameter SPI_CPOL = 1;
parameter SPI_CPHA = 1;

parameter SA_LMK  = 0;
parameter SA_ROM  = 1;
parameter SA_ATN0 = 2;
parameter SA_ATN1 = 3;

// --- TTL Output ---

parameter R_TTL = S_FPR + 8'h03;

// --- ADC / DAC ---
// AIOx: ADCx / DACx interface register
//   Read : sample from ADCx
//   Write: sample to DACx
// CADC: Configuration signals for ADCx
//   Structure:
//     {MODE_1, RAND_1, DITH_1, SHDN_1, MODE_0, RAND_0, DITH_0, SHDN_0}

parameter R_AIO0 = S_FPR + 8'h04;
parameter R_AIO1 = S_FPR + 8'h05;
parameter R_CADC = S_FPR + 8'h06;

parameter W_AIO = 16;             // AD/DA data bus width

// ------ DDS ------
// SDAx: SPI data register for DDSx
// SCTx: SPI control register for DDSx
// PBKx: Playback data for DDSx
//   For 9910 polar modulation:
//     PBKx[15 :  8]: Amplitude
//     PBKx[ 7 :  0]: Phase
// TUNx: Playback tune register
//   Structure:
//     TUNx[31 : 16]: Playback start address
//     TUNx[15 :  8]: Phase offset
//     TUNx[ 7 :  0]: Amplitude scale factor
// CDDS: Configuration signals for DDS
//   Structure:
//     --- Higher Seg ---
//     CDDS[31 : 29]: {IO_RST, M_RST, IO_UPD} -- DDS3
//     CDDS[28 : 26]: {IO_RST, M_RST, IO_UPD} -- DDS2
//     CDDS[25 : 23]: {IO_RST, M_RST, IO_UPD} -- DDS1
//     CDDS[22 : 20]: {IO_RST, M_RST, IO_UPD} -- DDS0
//     --- Lower Seg ---
//     CDDS[19 : 15]: {PROF[2:0], F[1:0]} -- DDS3
//     CDDS[14 : 10]: {PROF[2:0], F[1:0]} -- DDS2
//     CDDS[ 9 :  5]: {PROF[2:0], F[1:0]} -- DDS1
//     CDDS[ 4 :  0]: {PROF[2:0], F[1:0]} -- DDS0
// CPBK: Configuration signals for Playback
//   Structure:
//     --- Higher Seg ---
//     CDDS[31 : 29]: {1'b0, TX_EN, PLBK_EN} -- DDS3
//     CDDS[28 : 26]: {1'b0, TX_EN, PLBK_EN} -- DDS2
//     CDDS[25 : 23]: {1'b0, TX_EN, PLBK_EN} -- DDS1
//     CDDS[22 : 20]: {1'b0, TX_EN, PLBK_EN} -- DDS0
//     --- Lower Seg ---
//     CDDS[19 : 15]: {2'b0, TUNE_UPD, R_RST, W_RST} -- DDS3
//     CDDS[14 : 10]: {2'b0, TUNE_UPD, R_RST, W_RST} -- DDS2
//     CDDS[ 9 :  5]: {2'b0, TUNE_UPD, R_RST, W_RST} -- DDS1
//     CDDS[ 4 :  0]: {2'b0, TUNE_UPD, R_RST, W_RST} -- DDS0
//
// CMNx: Clock monitor for DDSx
//   Structure:
//     SYCx[31 : 16]: SYNC_CLK phase monitor
//     SYCx[15 :  0]: PDCLK phase monitor
//   LDL to CMNx resets the counters

parameter R_SDA0 = S_FPR + 8'h07;
parameter R_SCT0 = S_FPR + 8'h08;
parameter R_SDA1 = S_FPR + 8'h09;
parameter R_SCT1 = S_FPR + 8'h0A;
parameter R_CMN0 = S_FPR + 8'h0B;
parameter R_CMN1 = S_FPR + 8'h0C;

parameter W_APB = 14;               // Playback buffer address width
parameter W_PBK = 16;               // Playback word width

// ------ Gated Counter Array ------
// ECTR: Counter enable register
// CTRx: Start address of counters

parameter N_CTR = 8;
parameter R_CNTx = S_FPR + 8'h0D;
parameter R_ECTR = S_FPR + N_CTR + 8'h0D;

// ------ Trigger Manager ------
// ETRG: Trigger enable register (write only)
//   Write: enable the corresponding channels and arm the trigger
//   Structure:
//      6: DUT - ExtUART Tx
//      5: DUT - ExtUART Rx
//      4: SPI-DDS1 interface Rx/Tx finished
//      3: SPI-DDS0 interface Rx/Tx finished
//      2: SPI-General interface Rx/Tx finished
//      1: USB-UART interface Tx finished
//      0: External trigger input

parameter R_ETRG = S_FPR + N_CTR + 8'h0E;

// ------ Write-only Regs for DDS ------

parameter R_CDDS = S_FPR + N_CTR + 8'h0F;
parameter R_CPBK = S_FPR + N_CTR + 8'h10;
parameter R_PBK0 = S_FPR + N_CTR + 8'h11;
parameter R_PBK1 = S_FPR + N_CTR + 8'h12;
parameter R_TUN0 = S_FPR + N_CTR + 8'h13;
parameter R_TUN1 = S_FPR + N_CTR + 8'h14;

// ------ config register for PID ------
parameter R_PID00 = S_FPR + N_CTR + 8'h15;// k_0
parameter R_PID01 = S_FPR + N_CTR + 8'h16;// k_1
parameter R_PID02 = S_FPR + N_CTR + 8'h17;// k_2
parameter R_PID0r = S_FPR + N_CTR + 8'h18;// reference
parameter R_PID10 = S_FPR + N_CTR + 8'h19;// k_0
parameter R_PID11 = S_FPR + N_CTR + 8'h1A;// k_1
parameter R_PID12 = S_FPR + N_CTR + 8'h1B;// k_2
parameter R_PID1r = S_FPR + N_CTR + 8'h1C;// reference
parameter R_SETA0 = S_FPR + N_CTR + 8'h1D;// filter0
parameter R_SETA1 = S_FPR + N_CTR + 8'h1E;// filter1
parameter R_IIRA0 = S_FPR + N_CTR + 8'h1F;// IIR Filter a0
parameter R_IIRA1 = S_FPR + N_CTR + 8'h20;// IIR Filter a1
parameter R_IIRA2 = S_FPR + N_CTR + 8'h21;// IIR Filter a2
parameter R_IIRA3 = S_FPR + N_CTR + 8'h22;// IIR Filter a3
parameter R_IIRB0 = S_FPR + N_CTR + 8'h23;// IIR Filter b0
parameter R_IIRB1 = S_FPR + N_CTR + 8'h24;// IIR Filter b1
parameter R_IIRB2 = S_FPR + N_CTR + 8'h25;// IIR Filter b2
parameter R_IIRB3 = S_FPR + N_CTR + 8'h26;// IIR Filter b3
parameter R_PID0O = S_FPR + N_CTR + 8'h27;// PID output bais
parameter R_PID1O = S_FPR + N_CTR + 8'h28;// PID output bais
parameter R_PIDMin0 = S_FPR + N_CTR + 8'h29;// PID output Min
parameter R_PIDMax0 = S_FPR + N_CTR + 8'h2A;// PID output Max
parameter R_PIDMin1 = S_FPR + N_CTR + 8'h2B;// PID output Min
parameter R_PIDMax1 = S_FPR + N_CTR + 8'h2C;// PID output Max