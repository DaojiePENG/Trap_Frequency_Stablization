import numpy as np
import time
from tqdm import trange
from RTMQ_Interface import *
import RTMQ_Interface as rtmq
import datetime
import pyvisa
# -------- Core Configuration --------


CFG = RTMQ_Config()
CFG.ACR = ["NUL", "PTR", "WCK", "TIM",
           "ADR", "DAT", "RTS", "STK",
           "URT", "MUL", "MUH", "RND", 
           "DUTI", "DUTC", "NOW",
           "T_COND", "T_JUMP", "T_R0", "T_R1",
           "AR0", "AR1", "AR2", "AR3",
           "AR4", "AR5", "AR6", "AR7",
           "RT0", "RT1"]
CFG.N_GPR = 12
CFG.N_CTR = 8
CFG.FNR = ["LED", "SDAT", "SCTL", "TTL",
           "AIO0", "AIO1", "CADC",
           "SDA0", "SCT0", "SDA1", "SCT1",
           "CMN0", "CMN1"] + \
          [f"CNT{x}" for x in range(CFG.N_CTR)] + \
          ["ECTR", "ETRG", "CDDS", "CPBK",
           "PBK0", "PBK1", "TUN0", "TUN1",
           "R_PID00","R_PID01","R_PID02", "R_PIDR0",# PID参数寄存器：k_0, k_1, k_2, ref
           "R_PID10","R_PID11","R_PID12", "R_PIDR1",# PID参数寄存器：k_0, k_1, k_2, ref
           "R_SETA0","R_SETA1",
           "R_IIRA0","R_IIRA1","R_IIRA2","R_IIRA3",
           "R_IIRB0","R_IIRB1","R_IIRB2","R_IIRB3",
           "R_PIDOUT0","R_PIDOUT1", # PID 输出偏移量
           "R_PIDMIN0","R_PIDMAX0", # PID 输出幅度限制
           "R_PIDMIN1","R_PIDMAX1", # PID 输出幅度限制
           "R_PIDO0", # PID0 输出寄存器: output
           "R_PIDO1", # PID1 输出寄存器:output
           "R_FOLO1","R_IIRO1"
           ]
CFG.T_CYC = 5
CFG.L_MEM = 65536
CFG.BAUD = 4000000
# change this to the actual COM port
CFG.PORT = "COM9"
intf = RTMQ_Interface(CFG, glb=globals())


# -------- Top Level API --------

def MasterReset(sd=15, lmk=0x0B):
    """
    
    Reset all the peripherals of RTMQ Core.\n
    Just use the default values of the parameters.
    
    Parameters
    ----------
    sd : <int>, optional
        SYNC delay of DDS.
        The default is 30.
    lmk : <int>, optional
        Clock delay of DDS from LMK04832.
        The default is 0x0B.

    Returns
    -------
    None.

    """
    with ExperimentFlow():
        with UntimedTask():
            LMK_ResetDelay(dds=(lmk, lmk))
            Set(TTL, 0, bubble=False)
            Set(ECTR, 0, bubble=False)
            Set(LED, 0xFFFFFFFF, bubble=False)
            Set(AIO0, 0x8000)
            Set(AIO1, 0x8000)
            SetAtten("ATN0", 0b111111)
            SetAtten("ATN1", 0b111111)
            DDS_Init("DDS0", sd)
            DDS_Init("DDS1", sd)
            SerialSend(0)
    intf.run()

def DefineFunc():
    """
    
    Define library functions of RTMQ Core. \n
    Put it immediately after 'with ExperimentFlow():'.

    Returns
    -------
    None.

    """
    Def_UpdateProf()
    Def_CORDIC(16)
    Def_GenSBTemplate()
    Def_GaloisLFSR()

def NewPhaseOrigin(overhead=400):
    """
    
    Define phase origin (T=0) for output signal of DDS.

    Parameters
    ----------
    overhead : <int>, optional
        Make room for computational tasks before next timed task.
        The default is 400, in most cases this will be enough.

    Returns
    -------
    None.

    """
    with UntimedTask():
        ResetWallClock(-overhead - 3)
    StartTimedTask(overhead - 11)

def TTLStage(duration, state):
    """
    
    Output TTL signal and wait for some time.

    Parameters
    ----------
    duration : <int>, <float> or RTMQ Regs
        Duration of this TTL stage. \n
        <int> or RTMQ Regs: the duration is in unit of cycles (5ns). \n
        <float>: the duration is in unit of micro-second.
    state : <int> or RTMQ Regs
        Output state of the TTL channels.

    Returns
    -------
    None.

    """
    if type(duration) == float:
        duration = round(duration * 1000 / CFG.T_CYC)
    StartTimedTask(duration)
    Set(TTL, state, bubble=False)

def TTLOutput(state):
    """
    
    Set TTL output state without wait. \n
    Use it after 'DDSWave' if you want a TTL state change aligned with DDS wave segment. \n
    NOTE: never use it after 'TTLStage'.

    Parameters
    ----------
    state : <int> or RTMQ Regs
        Output state of the TTL channels.

    Returns
    -------
    None.

    """
    Set(TTL, state, bubble=False)

def WaitExtTrig():
    """
    
    Suspend the Core and wait for the external trigger.

    Returns
    -------
    None.

    """
    Set(ETRG, 0b000_0001)
    RawInstr("NOP H -")

def CntrStart(cntr):
    """
    
    Reset and activate the gated counters.

    Parameters
    ----------
    cntr : <list>
        List of counter channels (0~7) to be activated.

    Returns
    -------
    None.

    """
    msk = sum([1 << i for i in cntr])
    RawInstr(f"LDL - -  T_R0  {msk}")
    Pass()
    RawInstr(f"SMK - -  ECTR !NUL  T_R0")

def CntrStop(cntr):
    """
    
    Deactivate the gated counters.

    Parameters
    ----------
    cntr : <list>
        List of counter channels (0~7) to be deactivated. \n
        The counts can later be accessed with register CNTx (x=0~7).

    Returns
    -------
    None.

    """
    msk = sum([1 << i for i in cntr])
    RawInstr(f"LDL - -  T_R0  {msk}")
    Pass()
    RawInstr(f"SMK - -  ECTR  NUL  T_R0")
    Pass(6)

def GetADC(chn, dst):
    """
    
    Get ADC readings.

    Parameters
    ----------
    chn : <int>
        ADC channel to be accessed, can be 0 or 1.
    dst : RTMQ Regs
        The ADC reading is stored to this register.

    Returns
    -------
    None.

    """
    Set(dst, f"AIO{chn}")

def SetDAC(chn, val):
    """
    
    Set DAC output.

    Parameters
    ----------
    chn : <int>
        Destination DAC channel, can be 0 or 1.
    val : <int> or RTMQ Regs
        Output value, 16bit integer.
        The data format is binary offset.

    Returns
    -------
    None.

    """
    Set(f"AIO{chn}", val, bubble=False)

# --- Debug switches
WAV_DEBUG = False
DEBUG_UPD = (1, 1)

def DDSWave(dur, w0, w1, sbph0=None, sbph1=None):
    """
    
    Define DDS output waveform segments.

    Parameters
    ----------
    dur : <int>, <float> or RTMQ Regs
        Duration of this segment. \n
        <int> or RTMQ Regs: the duration is in unit of cycles (5ns). \n
        <float>: the duration is in unit of micro-second. \n
        NOTE: \n
            The minimum allowed duration is 1us / 200 cycles. \n
            If the next segment contains 'SwitchMode',
            then the minimum duration is 2us / 400 cycles.
    w0 : <list>
        Wave definition of DDS channel 0.
        w0 = [frq, amp, pha]
            frq: <int>, <float> or RTMQ Regs
                <int> or RTMQ Regs: 32bit frequency tuning word. \n
                <float>: frequency in MHz.
            amp: <int>, <float> or RTMQ Regs
                <int> or RTMQ Regs: 8bit amplitude scale factor. \n
                <float>: amplitude, within 0~1.
            pha: <int>, <float> or RTMQ Regs
                <int> or RTMQ Regs: 16bit phase offset word. \n
                <float>: phase offset in 2pi, within 0~1. \n
            NOTE: \n
                in dual-tone mode, 'frq' and 'pha' affect the carrier.
    w1 : <list>
        Wave definition of DDS channel 1.
    sbph0 : <float> or None, optional
        Inital phase of sideband signal of channel 0. \n
        Effective only in dual-tone mode. \n
        <float>: absolute inital phase in 2pi, within 0~1. \n
        None: No phase reset for this segement. \n
        The default is None.
    sbph1 : <float> or None, optional
        Inital phase of sideband signal of channel 1.
        The default is None.

    Returns
    -------
    None.

    """
    f0, a0, p0 = w0
    f1, a1, p1 = w1
    dur = round(dur * 1000 / CFG.T_CYC) if type(dur) == float else dur
    ftw0 = round((f0 / 800) * 0x1_0000_0000) if type(f0) == float else f0
    ftw1 = round((f1 / 800) * 0x1_0000_0000) if type(f1) == float else f1
    pow0 = round(p0 * 0x1_0000) % 0x1_0000 if type(p0) == float else p0
    pow1 = round(p1 * 0x1_0000) % 0x1_0000 if type(p1) == float else p1
    asf0 = round(a0 * 0xFF) if type(a0) == float else a0
    asf1 = round(a1 * 0xFF) if type(a1) == float else a1
    r0 = (sbph0 is not None)
    r1 = (sbph1 is not None)
    adr0 = phase_to_addr(F_SB[0], sbph0) if r0 else 0
    adr1 = phase_to_addr(F_SB[0], sbph1) if r1 else 0
    
    # --- debug ---
    pow0 = pow0 & 0xFF00
    pow1 = pow1 & 0xFF00
    #--------------
    
    if WAV_DEBUG:
        upd = DEBUG_UPD
    else:
        upd = (1, 1)

    # --- Experiment Flow ---
    Set(AR1, ftw0, bubble=False)
    RawInstr(f"LDL - -  AR2  {asf0}")
    RawInstr(f"LDL - -  AR3  {pow0}")
    Set(AR5, ftw1, bubble=False)
    RawInstr(f"LDL - -  AR6  {asf1}")
    RawInstr(f"LDL - -  AR7  {pow1}")
    Call("UpdateProf")
    Set(T_R1, 0xFFFF_0000, bubble=False)
    Set(T_R0, adr0 << 16)
    RawInstr("SMK - -  TUN0  T_R0  T_R1")
    Set(T_R0, adr1 << 16)
    RawInstr("SMK - -  TUN1  T_R0  T_R1")
    StartTimedTask(dur)
    DDS_Signal(upd=upd)
    Plbk_Signal(tupd=(1, 1), rrst=(int(r0), int(r1)))
    Plbk_Signal()
    DDS_Signal()

# Sideband definition:
#   +frq component with amplitude (1+da)/2
#   -frq component with amplitude (1-da)/2

# --- Sideband frequency cache
F_SB = [1, 1]

def Dnld_SBTemplate(chn, frq, da):
    """
    
    Download the sideband waveform template to the DDS peripheral.
    Used in dual-tone mode to generate the modulation signal.
    The download takes about 0.5s.

    Parameters
    ----------
    chn : <int>
        Destination DDS channel, can be 0 or 1.
    frq : <float>
        Sideband frequency in MHz.
    da : <float>
        Amplitude difference between the two sidebands, within -1~1. \n
        That is, \n
            +frq component with amplitude (1+da)/2, \n
            -frq component with amplitude (1-da)/2.

    Returns
    -------
    None.

    """
    F_SB[chn] = frq
    am, ph = gen_wavetemplate(frq, da)
    Ex(SetPolarPlbk, True)(f"DDS{chn}", am, ph)

def Gen_SBTemplate(chn, frq, da):
    """
    
    Generate the sideband waveform template for the DDS peripheral.
    Used in dual-tone mode to generate the modulation signal.
    The template is generated by the Core, takes about 63ms.

    Parameters
    ----------
    chn : <int>
        Destination DDS channel, can be 0 or 1.
    frq : <float>
        Sideband frequency in MHz.
    da : <float>
        Amplitude difference between the two sidebands, within -1~1. \n
        That is, \n
            +frq component with amplitude (1+da)/2, \n
            -frq component with amplitude (1-da)/2.

    Returns
    -------
    None.

    """
    F_SB[chn] = frq
    cyc, pts = template_param(frq)
    ar1 = round(cyc / pts * 0x1_0000_0000)
    ar2 = round(da * 0x7FFF_FFFF)

    # --- Experiment Flow ---
    Set(AR0, chn, bubble=False)
    Set(AR1, ar1, bubble=False)
    Set(AR2, ar2, bubble=False)
    Set(AR3, pts, bubble=False)
    Call("GenSBTemplate")

def SwitchMode(m0, m1):
    """
    
    Switch modes of DDS channels.
    Use it immediately before 'DDSWave' if the next segment is in different mode. \n
    NOTE: the duration of the segment before 'SwitchMode' should at least be 2us.

    Parameters
    ----------
    m0 : <str>
        New mode of DDS channel 0. \n
        Can be either 'dual' or 'mono'. \n
            'dual': dual-tone mode, to drive two-qubit gates. \n
            'mono': single-tone mode.
    m1 : <str>
        New mode of DDS channel 1. 

    Returns
    -------
    None.

    """
    mod = {"dual": 0x0141_08B0, "mono": 0x0141_08A0}

    # --- Experiment Flow ---
    DDS_Signal(iorst=(1, 1))
    DDS_Signal()
    Set(T_R1, 0x0040_0001, bubble=False)
    Set(SDA0, mod[m0], bubble=False)
    Set(SDA1, mod[m1], bubble=False)
    Set(SCT0, T_R1, bubble=False)
    Set(SCT1, T_R1, bubble=False)
    DDS_Prof(prof=(1, 1), pf=(3, 3))
    Plbk_State(txen=(1, 1), plbk=(1, 1))
    HardWait(81)

def RandomInt(reg):
    """
    
    Generate a 32bit random integer and store it to the destination register.

    Parameters
    ----------
    reg : RTMQ Regs
        Destination register.

    Returns
    -------
    None.

    """
    Set(reg, RND)

def RecToPol(x, y, r, phi):
    """
    
    Convert rectangular coordinate (x, y) to polar coordinate (r, phi). \n
    NOTE: If full precision is required, you should use 'Def_CORDIC(32)'.

    Parameters
    ----------
    x : <int> or RTMQ Regs
        32bit signed integer.
    y : <int> or RTMQ Regs
        32bit signed integer.
    r : RTMQ Regs
        32bit signed integer.
        r = sqrt(x*x + y*y)
    phi : RTMQ Regs
        32bit signed integer, in unit of 2*pi / (2 ** 32). \n
        phi = arctan2(y, x)

    Returns
    -------
    None.

    """
    # --- Experiment Flow ---
    Set(AR0, NUL, bubble=False)
    Set(AR1, x, bubble=False)
    Set(AR2, y, bubble=False)
    Set(AR3, NUL, bubble=False)
    Call("CORDIC")
    Set(r, RT0, bubble=False)
    Set(phi, RT1)

def PolToRec(r, phi, x, y):
    """
    
    Convert polar coordinate (r, phi) to rectangular coordinate (x, y). \n
    NOTE: If full precision is required, you should use 'Def_CORDIC(32)'.

    Parameters
    ----------
    r : <int> or RTMQ Regs
        32bit signed integer.
    phi : <int> or RTMQ Regs
        32bit signed integer, in unit of 2*pi / (2 ** 32). \n
    x : RTMQ Regs
        32bit signed integer. \n
        x = r*cos(phi)
    y : RTMQ Regs
        32bit signed integer. \n
        y = r*sin(phi)

    Returns
    -------
    None.

    """
    # --- Experiment Flow ---
    Set(AR0, ~NUL, bubble=False)
    Set(AR1, r, bubble=False)
    Set(AR2, NUL, bubble=False)
    Set(AR3, phi, bubble=False)
    Call("CORDIC")
    Set(x, RT0, bubble=False)
    Set(y, RT1)

def Multiply(a, b, hi, lo, signed_a=False, signed_b=False):
    """
    
    Calculate a*b, and store higher 32 bits to hi, lower 32 bits to lo.

    Parameters
    ----------
    a : <int> or RTMQ Regs
        32bit integer, signed or unsigned.
    b : <int> or RTMQ Regs
        32bit integer, signed or unsigned.
    hi : RTMQ Regs
        Higher part of the product.
    lo : RTMQ Regs
        Lower part of the product.
    signed_a : bool, optional
        True : a is signed. \n
        False: a is unsigned. \n
        The default is False.
    signed_b : bool, optional
        True : b is signed. \n
        False: b is unsigned. \n
        The default is False.

    Returns
    -------
    None.

    """
    Set(T_R0, a, bubble=False)
    Set(T_R1, b, bubble=False)
    Pass(3)
    if signed_a:
        Set(MUH, abs(T_R0), bubble=False)
    else:
        Set(MUH, T_R0, bubble=False)
    if signed_b:
        Set(MUL, abs(T_R1), bubble=False)
    else:
        Set(MUL, T_R1, bubble=False)
    if signed_a and signed_b:
        Set(T_R0, T_R0 ^ T_R1, bubble=False)
    elif signed_a:
        Pass()
    elif signed_b:
        Set(T_R0, T_R1, bubble=False)
    else:
        Set(T_R0, NUL, bubble=False)
    Pass(4)
    Set(T_R0, T_R0 >> 31, bubble=False)
    Pass(4)
    Set(hi, MUH ^ T_R0, bubble=False)
    Set(T_R1, MUL == NUL, bubble=False)
    RawInstr(f"SNE - - !T_R1  NUL  T_R0")
    RawInstr(f"SGN - -  {lo}  MUL  T_R0")
    Pass(3)
    Set(hi, hi - T_R1)

# -------- Common Subroutine Definition --------

def Def_UpdateProf():
    # DDS0:
    # AR1, AR2, AR3: ftw, asf, pow
    # DDS1:
    # AR5, AR6, AR7: ftw, asf, pow
    with Subroutine("UpdateProf"):
        Set(MUH, NOW, bubble=False)
        Set(MUL, AR1, bubble=False)
        Set(MUL, AR5, bubble=False)
        Set(T_R0, 0xFFFF_0000, bubble=False)
        Set(SDA0, AR1, bubble=False)
        Set(SDA1, AR5, bubble=False)
        Set(TUN0, AR2, bubble=False)
        Set(TUN1, AR6, bubble=False)
        Set(AR2, AR2 << 22, bubble=False)
        Set(AR6, AR6 << 22, bubble=False)
        Pass(1)
        Set(AR1, MUL >> 14, bubble=False)
        Set(AR5, MUL >> 14, bubble=False)
        Pass(1)
        DDS_Signal(iorst=(1, 1))
        DDS_Signal()
        Set(AR3, AR1 + AR3, bubble=False)
        Set(AR7, AR5 + AR7, bubble=False)
        RawInstr("SMK - -  AR3  AR2  T_R0")
        RawInstr("SMK - -  AR7  AR6  T_R0")
        Pass(1)
        Set(T_R0, 0x0080_000F, bubble=False)
        Set(SDA0, AR3, bubble=False)
        Set(SDA1, AR7, bubble=False)
        Set(SCT0, T_R0, bubble=False)
        Set(SCT1, T_R0, bubble=False)
        Set(T_R0, 0x0000_FF00)
        RawInstr("SMK - -  TUN0  AR3  T_R0")
        RawInstr("SMK - -  TUN1  AR7  T_R0")

def Def_CORDIC(itr=16):
    # AR1, AR2, AR3: x, y, z (signed)
    # NOTE: z in unit of 2*pi/(2**32)
    # AR0: mode
    #   AR0 >= 0: vector mode
    #       Output: RT0 = sqrt(x*x + y*y), RT1 = z + arctan(y/x)
    #   AR0 <  0: rotation mode
    #       Input : x = r, y = 0, z = phi
    #       Output: RT0 = r*cos(phi), RT1 = r*sin(phi)
    # Temp Regs:
    #   R00: flag of abs(z) > 0.5
    #   R01: sign of x
    #   R02: d_i in each iteration
    #   R03: temp. reg.
    fct = 0x8000_0000 / np.pi
    Ei = [round(np.arctan(2 ** -i) * fct) for i in range(itr)]
    K = 0x1_0000_0000
    for i in range(itr):
        K = K / np.sqrt(1 + 4 ** -i)
    K = int(K) - 8
    with Subroutine("CORDIC", [R00, R01, R02, R03]):
        Set(MUH, K, bubble=False)
        Set(MUL, abs(AR1), bubble=False)
        Set(MUL, abs(AR2), bubble=False)
        Set(T_R0, 0x8000_0000, bubble=False)
        Set(R00, AR3 << 1, bubble=False)
        Set(R01, AR1 & T_R0, bubble=False)
        Pass(3)
        Set(R00, R00 ^ AR3, bubble=False)
        RawInstr("SMK - -  R00  NUL !T_R0")
        RawInstr("SGN - -  AR1  MUH  AR1")
        RawInstr("SGN - -  AR2  MUH  AR2")
        Pass(2)
        Set(AR3, AR3 ^ R00, bubble=False)
        Pass(3)
        for i in range(itr):
            RawInstr("XOR - - !R02  AR1  AR2")
            RawInstr("SNE - -  R02  AR3  AR0")
            Set(T_R0, AR2 >> i, bubble=False)
            Set(T_R1, AR1 >> i, bubble=False)
            Set(R03, Ei[i], bubble=False)
            Pass(1)
            RawInstr("SGN - -  T_R0  T_R0  R02")
            RawInstr("SGN - -  T_R1  T_R1  R02")
            RawInstr("SGN - -  R03  R03  R02")
            Pass(2)
            Set(AR1, AR1 - T_R0, bubble=False)
            Set(AR2, AR2 + T_R1, bubble=False)
            Set(AR3, AR3 - R03, bubble=False)
            Pass(3)
        RawInstr("SGN - -  AR1  AR1  R00")
        RawInstr("SGN - -  AR2  AR2  R00")
        Set(RT0, abs(AR1), bubble=False)
        Set(RT1, AR3 ^ R01, bubble=False)
        Pass(1)
        RawInstr("SNE - -  RT0  AR1  AR0")
        RawInstr("SNE - -  RT1  AR2  AR0")

def Def_GenSBTemplate(debug=False):
    # AR0: destination DDS channel, 0 for DDS0, 1 for DDS1
    # AR1: FTW of sideband, unsigned
    #   AR1 = round((frq / 200) * (2 ** 32))
    # AR2: amplitude difference, signed
    #   AR2 = da * 0x7FFF_FFFF
    #   +frq component with amplitude (1+da)/2
    #   -frq component with amplitude (1-da)/2
    # AR3: length of template, less than 16384
    # Temp Regs:
    #   R00: buffered AR0
    #   R01: buffered AR1
    #   R02: abs(AR2) * 2, unsigned
    #   R03: sign of AR2
    #   R04: buffered AR3
    #   R05: loop variable
    #   R06: phase accumulator
    with Subroutine("GenSBTemplate",
                    [R00, R01, R02, R03, R04, R05, R06]):
        Set(R00, AR0 << 2, bubble=False)
        Set(R01, AR1, bubble=False)
        Set(R02, abs(AR2), bubble=False)
        Set(R03, AR2, bubble=False)
        Set(R04, AR3, bubble=False)
        Set(R00, R00 + AR0, bubble=False)
        Set(R06, NUL, bubble=False)
        Set(R02, R02 << 1, bubble=False)
        Pass(2)
        Set(CPBK, 1 << R00, bubble=False)
        Set(CPBK, NUL, bubble=False)
        with Repeat(R05, R04):
            Set(AR0, ~NUL, bubble=False)
            Set(AR1, 0x7FFF_FFFF, bubble=False)
            Set(AR2, NUL, bubble=False)
            Set(AR3, R06, bubble=False)
            Call("CORDIC")
            Set(MUH, R02, bubble=False)
            Set(MUL, abs(RT1), bubble=False)
            Pass(5)
            RawInstr("SGN - -  T_R0  RT1  R03")
            Pass(1)
            Set(AR0, NUL, bubble=False)
            Set(AR3, NUL, bubble=False)
            Set(AR1, RT0, bubble=False)
            RawInstr("SGN - -  AR2  MUH  T_R0")
            Call("CORDIC")
            Set(RT0, RT0 >> 15, bubble=False)
            Set(T_R0, 0xFFFF_FF00, bubble=False)
            Set(T_R1, RT1 >> 24, bubble=False)
            Pass(1)
            #--- dither ---
            # Set(T_COND, 0x0000_0001)
            # RawInstr("SMK - -  T_COND  RND  T_COND")
            # Pass(4)
            # Set(T_R1, T_R1 + T_COND)
            #--------------
            RawInstr("SMK - -  T_R1  RT0  T_R0")
            Set(AR0, R00 == 0, bubble=False)
            Set(AR1, R00 == 5, bubble=False)
            Set(AR2, R00 == 10, bubble=False)
            Set(AR3, R00 == 15, bubble=False)
            Pass(1)
            if debug:
                SerialSend(T_R1)
            else:
                RawInstr("SNE - -  PBK0  T_R1  AR0")
                RawInstr("SNE - -  PBK1  T_R1  AR1")
            Set(R06, R06 + R01, bubble=False)

def Def_GaloisLFSR():
    # AR0: Last state of LFSR
    # AR1: Feedback tap, example: 0x57
    # RT0: New state of LFSR
    # RT1: Generated random number
    with Subroutine("GaloisLFSR", [R00]):
        Set(T_R1, 0x8000_0000, bubble=False)
        with Repeat(R00, 32):
            Set(T_R0, AR0 >> 31, bubble=False)
            RawInstr("SMK - -  T_R0  NUL !AR1")
            Set(RT1, RT1 >> 1, bubble=False)
            Pass(3)
            Set(T_R0, T_R0 ^ AR0)
            RawInstr("SLC - -  AR0  T_R0  1")
            RawInstr("SMK - -  RT1  T_R0  T_R1")
        Set(RT0, AR0)


# -------- Helper Function --------


def Ex(func, cfg=False):
    def _wrapped(*args, **kwargs):
        with ExperimentFlow(cfg):
            if not cfg:
                with UntimedTask():
                    func(*args, **kwargs)
            else:
                func(*args, **kwargs)
        if not cfg:
            ret = intf.run()
        else:
            ret = intf.cfg_run()
        if ret is not None:
            return ret
    return _wrapped

# Ex(DDS_RegRead)("DDS0", 0x0a)
# Ex(DDS_Prof)("DDS0", 1, 200, 1, 0)
# Ex(SerialSend)(AIO0)

def concat(*args):
    '''
    功能：按指定位数将数据串联起来。
    如：hex(concat((5,8),(1,4),(6,4)))->'0x516'
    '''
    dat = 0
    ln = len(args)
    for i in range(ln - 1):
        # 将数据(a,b)中的数据a按数据b进行移位
        dat = dat + args[i][0]
        dat = dat << args[i + 1][1]
    dat = dat + args[ln - 1][0]
    return dat

def sig_msk(dev, val=1, oth=0):
    '''
    功能：单独将ret[ch, ch]其中的一个值改变为value的值，默认初始化为other的值。
    '''
    ret = [oth, oth]
    ret[int(dev[-1])] = val
    return ret

def SPI_Send(slv_adr, dst_reg, adr_len, dat_len, clk_div, ltn=0, wait=True):
    '''
    功能：将配置数据通过SPI传递给DDS的内部BUFF里面，随后通过更新指令DDS会将指令配置到内部控制寄存器中。
    
    '''
    slv_lst = {"LMK": 0, "ROM": 1, "ATN0": 2, "ATN1": 3}
    slv = 0
    # 获取从机地址
    if slv_adr == "DDS0":
        # 可以是DDS的串行SingleTone通道，DDS0对应Verilog，SCT0寄存器
        dst = SCT0
    elif slv_adr == "DDS1":
        dst = SCT1
    else:
        # 或者是控制指令配置
        dst = SCTL
        slv = slv_lst[slv_adr]
    # 32bit待发送的控制字
    val = concat((clk_div, 8), (dat_len, 4), (adr_len, 1),
                 (slv, 3), (ltn, 4), (dst_reg, 12))
    # --- Experiment Flow ---
    Set(dst, val)
    if wait:
        HardWait((clk_div + 1) * (16 * (dat_len + adr_len + 2)))


# -------- DDS Interface --------


RegLen = [4, 4, 4, 4, 4, 6, 6, 4,
          2, 4, 4, 8, 8, 4, 8, 8,
          8, 8, 8, 8, 8, 8, 4, 0, 2, 2]
CDiv_DDSW = 0
CDiv_DDSR = 10
CurProf = [0, 0]
CurPF = [0, 0]
CurSft = [0,0]

def DDS_Prof(prof=(None, None), pf=(None, None), sft=(None, None)):
    global CurProf, CurPF, CurSft
    p0 = CurProf[0] if prof[0] is None else prof[0]
    p1 = CurProf[1] if prof[1] is None else prof[1]
    CurProf = [p0, p1]
    f0 = CurPF[0] if pf[0] is None else pf[0] # parallel dest, 00: 14-bit amplitude, 01: 16-bit phase,
    f1 = CurPF[1] if pf[1] is None else pf[1] # 10: 32-bit frequency, 11: 8-bit amplitude and 8-bit phase
    CurPF = [f0, f1]# 当前的parallel Profile
    s0 = CurSft[0] if sft[0] is None else sft[0]
    s1 = CurSft[1] if sft[0] is None else sft[0]
    CurSft = [s0,s1] # 跟新CurSft的值，当前的PID后register移位数量
    val = concat((s1,4),(s0,4),(0,2),(p1, 3), (f1, 2), (p0, 3), (f0, 2))

    # --- Experiment Flow ---
    RawInstr(f"LDL - -  CDDS  {val}")

def DDS_Signal(iorst=(0, 0), rst=(0, 0), upd=(0, 0)):
    '''按要求将输入输出，复位，更新的26bit指令给CDDS寄存器高位，主要控制高6位'''
    val = concat((0,6),
                 (iorst[1], 1), (rst[1], 1), (upd[1], 1),
                 (iorst[0], 1), (rst[0], 1), (upd[0], 1),
                 (0, 20)
                 )
    # --- Experiment Flow ---
    RawInstr(f"LDH - -  CDDS  {val}")

Txen=[0, 0]
def Plbk_State(txen=(None, None), plbk=(0, 0)):
    '''按要求将playback的26bit状态控制指令给CPBK寄存器高位，主要控制高6位'''
    global Txen
    txen0= Txen[0] if txen[0] is None else txen[0]
    txen1= Txen[1] if txen[1] is None else txen[1]
    Txen = [txen0, txen1]
    val = concat((0, 1), (txen1, 1), (plbk[1], 1),
                 (0, 1), (txen0, 1), (plbk[0], 1),
                 (0, 20))
    # --- Experiment Flow ---
    RawInstr(f"LDH - -  CPBK  {val}")

def Plbk_Signal(tupd=(0, 0), rrst=(0, 0), wrst=(0, 0)):
    '''按要求将playback的26bit信号控制指令给CPBK寄存器高位，主要控制高6位'''
    val = concat((0, 2), (tupd[1], 1), (rrst[1], 1), (wrst[1], 1),
                 (0, 2), (tupd[0], 1), (rrst[0], 1), (wrst[0], 1))

    # --- Experiment Flow ---
    RawInstr(f"LDL - -  CPBK  {val}")

def DDS_RegWrite(dds, reg, dat, clk=CDiv_DDSW, wait=True, ioupd=True):
    tln = len(dat)
    dat = dat + ([0] * (-tln % 4))
    ln = len(dat) // 4
    ins = [0] * ln
    for i in range(ln):
        # 将信号恢复回来，ins[0]:frequency, ins[1]:amplitude, ins[2]: phase
        ins[i] = concat((dat[i*4], 8), (dat[i*4+1], 8),
                        (dat[i*4+2], 8), (dat[i*4+3], 8))
    dst = f"SDA{dds[-1]}" # 匹配DDS的倒数第一个数，选择SDA通道进行初始配置
    # --- Experiment Flow ---
    DDS_Signal(iorst=sig_msk(dds))
    DDS_Signal() # 这里为什么要两个 DDS_Signal？一个给Reset置1另一个复位0
    for i in range(ln):
        # 先将数据写入SPI位移寄存器中
        Set(dst, ins[ln-i-1])
    # SPI_Send(slv_adr, dst_reg, adr_len, dat_len, clk_div, ltn=0, wait=True):
    SPI_Send(dds, reg, 0, tln, clk, ltn=0, wait=wait)
    if ioupd:
        DDS_Signal(upd=sig_msk(dds))
        DDS_Signal()

def DDS_RegRead(dds, reg, clk=CDiv_DDSR, ltn=2, wait=True):
    dst = f"SDA{dds[-1]}"
    # --- Experiment Flow ---
    DDS_Signal(iorst=sig_msk(dds))
    DDS_Signal()
    SPI_Send(dds, reg + 128, 0, RegLen[reg], clk, ltn=ltn, wait=wait)
    ln = RegLen[reg] + (-RegLen[reg] % 4)
    if wait:
        for i in range(ln // 4):
            SerialSend(dst)

def fmt_regval(reg, dat):
    ln = len(dat)
    res = [0] * (ln * 4)
    for i in range(ln):
        for j in range(4):
            res[(ln-i)*4-j-1] = (dat[i] >> (j * 8)) % 256
    h = -RegLen[reg] % 4
    return res[h:]

def DDS_ProfWrite(dds, prof, frq, amp, pha):
    '''
    dds: 目标DDS的寄存器
    prof: profile, 
    frq: frequency, 目标频率
    amp: amplitude, 目标幅值
    pha: phase, 目标相位
    '''
    # 将数值映射到芯片寄存器数值，to_bytes转换成16进制表示的字
    ftw = round((frq / 800) * (2 ** 32)).to_bytes(4, "big")
    asf = round(amp * 16383).to_bytes(2, "big")
    phw = round(pha * 65536).to_bytes(2, "big")
    # --- Experiment Flow ---
    # +14为功能寄存器起始地址；list(*)将字转化为数组用来赋值
    DDS_RegWrite(dds, prof + 14, list(asf + phw + ftw))
    
    
# Ex(DDS_ProfWrite)("DDS0", 1, 200, 1, 0)




def DUC_ProfWrite(dds, prof, ccir, s_inv, i_cci, frq, amp, pha):
    ctr = concat((ccir, 6), (s_inv, 1), (i_cci, 1)).to_bytes(1, "big")
    ftw = round((frq / 800) * (2 ** 32)).to_bytes(4, "big")
    asf = round(amp * 255).to_bytes(1, "big")
    phw = round(pha * 65536).to_bytes(2, "big")
    # --- Experiment Flow ---
    DDS_RegWrite(dds, prof + 14, list(ctr + asf + phw + ftw))

def DDS_Init(dds, sd):
    '''
    dds:目标DDS寄存器
    sd:
    '''
    sdg = sd // 2   # Output sync generator delay[4:0]
    sdr = sd - sdg  # Input sync receiver delay[4:0]
    # --- Experiment Flow ---
    sig = sig_msk(dds)              # 获取控制目标DDS的掩码
    Plbk_State()                    # 将plbk状态复位
    Plbk_Signal(rrst=sig, wrst=sig) # 选择相应的DDS信号进行控制
    Plbk_Signal()                   # 恢复相应的DDS信号
    DDS_Prof(sig_msk(dds, 0, None)) # 复位DDSprofile
    DDS_Signal(rst=sig)             # 选择相应DDS进行复位
    DDS_Signal()                    # 恢复相应的DDS
    DDS_RegWrite(dds, 0x0, [0x01, 0x41, 0x20, 0x02])        # 设置控制寄存器1
    DDS_RegWrite(dds, 0x1, [0x01, 0x41, 0x08, 0xA0])        # 设置控制寄存器2
    # DDS_RegWrite(dds, 0x1, [0x01, 0x41, 0x08, 0xbf])        # 设置控制寄存器2，使能并行数据,权重设为最大
    DDS_RegWrite(dds, 0x2, [0x00, 0x00, 0xC0, 0x00])        # 设置控制寄存器3
    DDS_RegWrite(dds, 0x3, [0x00, 0x00, 0x00, 0x00])        # 设置辅助寄存器
    DDS_RegWrite("DDS0", 0xA, [0x0C, 0x00, sdg*8, sdr*8])   # 设置Multichip寄存器
    DDS_RegWrite("DDS1", 0xA, [0x0C, 0x00, sdg*8, sdr*8])

def Signal_In_Bits(dat):
    ln = len(dat) // 4
    ins = [0] * ln
    for i in range(ln):
        # 将信号恢复回来，ins[0]:frequency, ins[1]:amplitude, ins[2]: phase
        ins[i] = concat((dat[i*4], 8), (dat[i*4+1], 8),
                        (dat[i*4+2], 8), (dat[i*4+3], 8))
    return bin(ins[0])
# Ex(DDS_Init)('DDS0',15)


def DDS_GetClockPhase(dds, dur):
    dst = "CMN" + dds[-1]
    # --- Experiment Flow ---
    RawInstr(f"LDL - -  {dst}  0")
    Wait(dur + 2)
    SerialSend(dst)


# -------- DDS Playback Interface --------

# AD9910 polar modulation sample rate in MHz
F_SAMP = 200

# Wave template buffer length
BUF_LEN = 16384

def template_param(frq):
    r = frq / F_SAMP
    cyc = int(BUF_LEN * r)
    rt = round(cyc / r)
    it = int(cyc / r)
    it = it + (rt == it)
    t0 = np.gcd(cyc, rt)
    t1 = np.gcd(cyc, it)
    pts = rt if t0 <= t1 else it
    # df = frq - cyc * F_SAMP / pts
    return cyc, pts

def phase_to_addr(frq, phi):
    cyc, pts = template_param(frq)
    gcd = np.gcd(cyc, pts)
    mod = np.arange(pts) * cyc % pts
    base = min(np.arange(pts)[(mod == gcd)])
    adr = round(phi * pts / gcd) * base % pts
    # dp = phi - adr * cyc / pts % 1
    # dp = (1 - dp) if abs(1 - dp) < abs(dp) else dp
    return adr

def gen_wavetemplate(frq, da):
    cyc, pts = template_param(frq)
    # pts = 10000
    # cyc = 50
    x = np.linspace(0, cyc / frq, pts, False)
    # x = np.linspace(0, cyc, pts, False)
    s, c = calc_iq(frq, 1, 0, x)
    am, ph = iq_to_polar(da * s, c)
    return am, ph

def calc_iq(f, a, p, x):
    s = a * np.sin(2 * np.pi * (f * x + p))
    c = a * np.cos(2 * np.pi * (f * x + p))
    return s, c

def wave_iq(w, buf_len=BUF_LEN):
    x = np.linspace(0, buf_len / F_SAMP, buf_len, False)
    s, c = calc_iq(*(w[0]), x)
    for i in range(1, len(w)):
        ts, tc = calc_iq(*(w[i]), x)
        s += ts
        c += tc
    return s, c

def iq_to_polar(s, c):
    am = np.sqrt(s ** 2 + c ** 2)
    ph = np.arctan2(s, c)
    return am, ph

def _dither(v):
    i = int(v)
    f = v - int(v)
    if (f == 0) or (np.random.random() > abs(f)):
        return i
    else:
        return i + int(v > 0) * 2 - 1

def SetIQPlbk(dds, di, dq):
    cnt = len(di)
    dst = "PBK" + dds[-1]
    # --- Experiment Flow ---
    Plbk_State()
    Plbk_Signal(rrst=sig_msk(dds), wrst=sig_msk(dds))
    Plbk_Signal()
    for j in range(cnt):
        i = _dither(di[j] * 0x1FFFF)
        q = _dither(dq[j] * 0x1FFFF)
        RawInstr(f"LDL - -  {dst}  {i}")
        RawInstr(f"LDL - -  {dst}  {q}")

def SetPolarPlbk(dds, amp, pha):
    cnt = len(amp)
    dst = "PBK" + dds[-1]
    # --- Experiment Flow ---
    Plbk_State()
    Plbk_Signal(rrst=sig_msk(dds), wrst=sig_msk(dds))
    Plbk_Signal()
    for j in range(cnt):
        a = _dither(abs(amp[j]) * 255)
        p = _dither(pha[j] / np.pi / 2 % 1 * 256) % 256
        # a = int(abs(amp[j]) * 255)
        # p = int(pha[j] / np.pi / 2 % 1 * 256) % 256
        val = concat((a, 8), (p, 8))
        RawInstr(f"LDL - -  {dst}  {val}")

def SetRawPlbk(dds, dat):
    cnt = len(dat)
    dst = "PBK" + dds[-1]
    # --- Experiment Flow ---
    Plbk_State()
    Plbk_Signal(rrst=sig_msk(dds), wrst=sig_msk(dds))
    Plbk_Signal()
    for i in range(cnt):
        RawInstr(f"LDL - -  {dst}  {round(dat[i])}")

def Start_Playback(plbk=(0, 0)):
    # --- Experiment Flow ---
    Plbk_Signal(rrst=plbk)
    Plbk_Signal()
    Plbk_State(txen=plbk, plbk=plbk)

# -------- Attenuator Interface --------

def SetAtten(atn, lvl):
    # --- Experiment Flow ---
    SPI_Send(atn, lvl, 0, 0, 50, wait=True)

# -------- LMK Interface --------

CDiv_LMK = 50
FN = "D:/ControlSystem/RTMQ/LMK_dualloop.txt"


def LMK_RegWrite(reg, dat, clk=CDiv_LMK):
    # --- Experiment Flow ---
    Set(SDAT, concat((dat, 8), (0, 24)))
    SPI_Send("LMK", reg, 1, 1, clk, True)

def LMK_RegRead(reg, clk=CDiv_LMK):
    # --- Experiment Flow ---
    SPI_Send("LMK", reg + 2048, 1, 1, clk, True)
    SerialSend(SDAT)

def parse_regmap(fn):
    with open(fn, "r") as f:
        txt = f.readlines()
    cnt = len(txt)
    rm = [0] * cnt
    for i in range(cnt):
        tmp = int((txt[i].split("\t"))[1][0:-1], 16)
        rm[i] = [tmp // 0x100, tmp % 0x100]
    return rm

def Apply_RegMap(fn):
    rm = parse_regmap(fn)
    with ExperimentFlow():
        for i in rm[1:]:
            LMK_RegWrite(i[0], i[1])
    intf.run()

def LMK_ResetDelay(dds=(0x0A, 0x0A), adc=(0x0A, 0x0A)):
    # --- Experiment Flow ---
    # ------ Set delay ---
    LMK_RegWrite(0x101, dds[0])
    LMK_RegWrite(0x111, dds[1])
    LMK_RegWrite(0x109, adc[0])
    LMK_RegWrite(0x119, adc[1])
    # ------ Start SYNC ---
    LMK_RegWrite(0x144, 0x80)
    LMK_RegWrite(0x140, 0x01)
    LMK_RegWrite(0x143, 0x51)
    LMK_RegWrite(0x143, 0x71)
    LMK_RegWrite(0x143, 0x40)
    LMK_RegWrite(0x140, 0x0D)
    LMK_RegWrite(0x144, 0xFF)
    Wait(5000)

def LMK_DynDelay(dly, dds=(0, 0), adc=(0, 0)):
    flg = concat((adc[1], 1), (dds[1], 1), (adc[0], 1), (dds[0], 1))
    # --- Experiment Flow ---
    LMK_RegWrite(0x141, flg)
    LMK_RegWrite(0x142, dly)
    Wait(20)
    LMK_RegWrite(0x141, 0)

# -------- ADC Interface --------

def ADC_Config(mode=(0, 0), rand=(0, 0), dith=(0, 0)):
    cfg = concat((mode[1], 1), (rand[1], 1), (dith[1], 1), (0, 1),
                 (mode[0], 1), (rand[0], 1), (dith[0], 1), (0, 1))
    # --- Experiment Flow ---
    Set("CADC", cfg)

def rand_recover(dat):
    ln = len(dat)
    res = [0] * ln
    for i in range(ln):
        res[i] = dat[i] ^ (0xFFFE * (dat[i] % 2))
    return res



# ======== PID相关函数 begin ========
# ------ 数字转换器 ------
def num2hex(num, n_bit=16):
    '''
    功能：将输入的数转换成标准的16进制补码格式。支持8,16,32位格式输出。
    num: input any number
    n_bit: input the aiming bit number of ouput format. 
    '''
    if n_bit==4:
        hex_num=hex(num & 0xf)
    elif n_bit==8:
        hex_num=hex(num & 0xff)
    elif n_bit==16:
        hex_num=hex(num & 0xffff)
    elif n_bit==32:
        hex_num=hex(num & 0xffff_ffff)
    elif n_bit==64:
        hex_num=hex(num & 0xffff_ffff_ffff_ffff)
    else:
        print('Error, Only support 4, 8, 16, 32 and 64 bits format.')
    return hex_num

# ------ PID参数转换器 ------
def PID_par_converter(k_p, k_i, k_d, n_bit=16):
    '''
    功能：将PID的k_p，k_i，k_d参数转化为硬件内部的k_0，k_1，k_2参数，并用16进制数表示；
    
    注：k_p,k_i,k_d为PID的三个参数，可为任意整数，可正可负；
        n_bit为预期的输出格式bit位数，可为4,8,16,32,64；
    '''
    k_0=k_p+k_i+k_d
    k_1=-k_p-2*k_d
    k_2=k_d
    return num2hex(k_0, n_bit),num2hex(k_1, n_bit),num2hex(k_2, n_bit)

# ------ PID参数设置器 ------

def PID_set_par(k_p, k_i, k_d, ref, dds='DDS0',n_bit=32):
    '''
    功能：设置PID参数。
    1.将输入的k_p，k_i，k_d参数转化为硬件内部的PID增量模式参数k_0，k_1，k_2参数，并用n_bit位16进制数表示；
    2.与测控板交互设置板上PID参数；
    注：k_p, k_i, k_d, ref当前仅支持整数,；设置格式默认为16位16进制数
    '''
    [k_0,k_1,k_2]=PID_par_converter(k_p,k_i,k_d, n_bit) # 转换PID参数
    if dds=='DDS0':
        Ex(Set)('R_PID00',k_0) # 设置k_0
        Ex(Set)('R_PID01',k_1) # 设置k_1
        Ex(Set)('R_PID02',k_2) # 设置k_2
        Ex(Set)('R_PIDR0',ref) # 设置Reference
        #PID Reset             # PID复位，自动在IO Update时复位
        Ex(DDS_Signal)(upd=sig_msk("DDS0"))
        Ex(DDS_Signal)() # 给出一个先1后0的跳变Update信号，该信号同时可以复位PID
    elif dds=='DDS1':
        Ex(Set)('R_PID10',k_0) # 设置k_0
        Ex(Set)('R_PID11',k_1) # 设置k_1
        Ex(Set)('R_PID12',k_2) # 设置k_2
        Ex(Set)('R_PIDR1',ref) # 设置Reference
        #PID Reset             # PID复位，自动在IO Update时复位
        Ex(DDS_Signal)(upd=sig_msk("DDS0"))
        Ex(DDS_Signal)() # 给出一个先1后0的跳变Update信号，该信号同时可以复位PID
    else:
        print("DDS not found, please choose between 'DDS0' and 'DDS1'.")
    ans='k_p: {}, k_i: {}, k_d: {}; \nk_0: {}, k_1: {}, k_2: {}; \nref: {}'
    print(ans.format(k_p, k_i, k_d, k_0, k_1, k_2, ref))
    return k_p, k_i, k_d, k_0, k_1, k_2, ref

# ------ PID参数查看器 ------
# "R_PID0","R_PID1","R_PID2", # PID参数寄存器：k_0, k_1, k_2
# "R_PID3","R_PID4","PID_OUT" # PID 输入寄存器: input, reference, output
def PID_readpara(dds='DDS0', n_bit=16):
    '''
    功能：PID状态读取，可以获得PID的k_x参数、参考值、输入和输出状态；
    dds: destination DDS
    n_bit: bits number of PID parameters
    输出顺序：k_p, k_i, k_d, k_0，k_1，k_2、PID参考值、PID输入值、PID输出值；
    注：由于通信速率，读出值非实时状态
    '''
    if dds=='DDS0':
        PID_k0=Ex(SerialSend)('R_PID00') # PID parameter k_0
        PID_k1=Ex(SerialSend)('R_PID01') # PID parameter k_1
        PID_k2=Ex(SerialSend)('R_PID02') # PID parameter k_2
        PID_ref_l=Ex(SerialSend)('R_PIDR0') # PID reference
        
        PID_in_l=Ex(SerialSend)('AIO0') # PID 输入input
        PID_out_l=Ex(SerialSend)('R_PIDO0') # PID输出结果out; 只读
    elif dds=='DDS1':
        PID_k0=Ex(SerialSend)('R_PID10') # PID parameter k_0
        PID_k1=Ex(SerialSend)('R_PID11') # PID parameter k_1
        PID_k2=Ex(SerialSend)('R_PID12') # PID parameter k_2
        PID_ref_l=Ex(SerialSend)('R_PIDR1') # PID reference
        
        PID_in_l=Ex(SerialSend)('AIO1') # PID 输入input
        PID_out_l=Ex(SerialSend)('R_PIDO1') # PID输出结果out; 只读
    else:
        print("DDS not found, please choose between 'DDS0' and 'DDS1'.")
    
    ''''''
    list_par=[PID_k0, PID_k1, PID_k2]
    for i in range(len(list_par)):
        # 准备用来代替下面的一大段内容
        list_par[i][0] = list_par[i][0]%(2**n_bit)# 按给定位数截断
        if list_par[i][0]>2**(n_bit-1):# 数字还原成16位补码形式
            list_par[i][0] = -((list_par[i][0]+1)^0xFFFF)
    
    PID_ref_l[0]=PID_ref_l[0] # 参考值采用无符号式显示
    PID_in_l[0]=PID_in_l[0]-0x7fff # 为了方便对比，输入采用无符号数显示
    if PID_out_l[0]>2**(2*n_bit-1):
        # 数字还原成32位补码形式，输出为32位的，需要特别对待
        PID_out_l[0] = -((PID_out_l[0]-1)^0xFFFF_FFFF)
    
    # 从k参数计算pid参数
    PID_kp=-list_par[1][0]-2*list_par[2][0]
    PID_ki=list_par[0][0]+list_par[1][0]+list_par[2][0]
    PID_kd=list_par[2][0]
    
    ans='PID_kp: {}, PID_ki: {}, PID_kd: {};\nPID_k0: {}, PID_k1: {}, PID_k2: {};\nReference: {}, Input: {}, Output: {}'
    print(ans.format(PID_kp, PID_ki, PID_kd, list_par[0][0], list_par[1][0], list_par[2][0], PID_ref_l[0], PID_in_l[0], PID_out_l[0]))
    return PID_kp, PID_ki, PID_kd, list_par[0][0], list_par[1][0], list_par[2][0], PID_ref_l[0], PID_in_l[0], PID_out_l[0]

# ======== PID相关函数 end ========
# ======== Filter相关函数 begin ========
def Filter_Seta(dds='DDS0',a=0.5):
    '''功能：设置多阶低通滤波器的a参数, a in (0,1)
    滤波器的输入输出关系为：𝑦(𝑛)=𝑎_0 𝑥(𝑛)+(1−𝑎_0 )𝑦(𝑛−𝑘)
    '''
    reg_a=round(2**15*a)
    if dds=='DDS0':
        Ex(Set)('R_SETA0',reg_a) # 设置Filter的a参数滤波器
    elif dds=='DDS1':
        Ex(Set)('R_SETA1',reg_a) # 设置Filter的a参数滤波器
        b=1-a;
        a_reg=round(a*2**15);
        b_reg=round(b*2**15);
        Ex(Set)('R_IIRA1',a_reg) # 测试设置IIR滤波器
        Ex(Set)('R_IIRB1',b_reg) # 测试设置IIR滤波器
    else:
        print("DDS not found, please choose between 'DDS0' and 'DDS1'.")
        
def IIR_FilterSet(fac_a=0.5, a_1=0.5, b_1=0.5):
    '''功能：设置IIR滤波器参数
    首先对a, b参数进行整体归一化，然后在将其拓展2^15倍取整后设置到寄存器
    '''
    fac_b=1-fac_a
    a_0=(1-a_1)/2
    a_2=a_0
    b_0=(1-b_1)/2
    b_2=b_0
    norm_a0=round(fac_a*a_0*2**15)# 系数归一化后拓展2**15倍
    norm_a1=round(fac_a*a_1*2**15)
    norm_a2=round(fac_a*a_2*2**15)
    norm_b0=round(fac_b*b_0*2**15)
    norm_b1=round(fac_b*b_1*2**15)
    norm_b2=round(fac_b*b_2*2**15)
    check=norm_a0+norm_a1+norm_a2+norm_b0+norm_b1+norm_b2 # 检查是否正确
    
    Ex(Set)('R_IIRA0',norm_a0) # 测试设置IIR滤波器
    Ex(SerialSend)('R_IIRA0') # 查看设置情况
    Ex(Set)('R_IIRA1',norm_a1) # 测试设置IIR滤波器
    Ex(SerialSend)('R_IIRA1') # 查看设置情况
    Ex(Set)('R_IIRA2',norm_a2) # 测试设置IIR滤波器
    Ex(SerialSend)('R_IIRA2') # 查看设置情况
    Ex(Set)('R_IIRA3',0) # 测试设置IIR滤波器
    Ex(SerialSend)('R_IIRA3') # 查看设置情况
    
    Ex(Set)('R_IIRB0',norm_b0) # 测试设置IIR滤波器
    Ex(SerialSend)('R_IIRB0') # 查看设置情况
    Ex(Set)('R_IIRB1',norm_b1) # 测试设置IIR滤波器
    Ex(SerialSend)('R_IIRB1') # 查看设置情况
    Ex(Set)('R_IIRB2',norm_b2) # 测试设置IIR滤波器
    Ex(SerialSend)('R_IIRB2') # 查看设置情况
    Ex(Set)('R_IIRB3',0) # 测试设置IIR滤波器
    return check
# ======== Filter相关函数 end ========

# ======== DDS parallel 相关函数 begin ========
def DDS_ParF_Init(frq=200, amp=0.5, pha=0, dds="DDS0", FM=15, prof=0, sd=15, lmk=0x0B):
    '''DDS parllel frequency tune initialization
    fre: starting freqeuncy for parllel freqeuncy tuning
    amp: amplitude 
    pha: phase 
    dds: the destination DDS channel;
    FM(0-15): set Frequency Modulate weight; 
    prof: effective auxiliary Single Tone Mode for amplitude and phase setting;
    
    the result of set frequency tune word is FTW=fre<<FM=fre*2**FM;
    relation of FTW and output frequency is f_out=(FTW/2**32)f_sysclk;
    注意： 并行频率调制为16位有效，根据FM左移连接，此时Single tone的频率决定调制的中心频率；
    '''
    sdg = sd // 2
    sdr = sd - sdg
    sig = sig_msk(dds)              # 获取控制目标DDS的掩码
    
    with ExperimentFlow():
        with UntimedTask():
            LMK_ResetDelay(dds=(lmk, lmk))
            Set(TTL, 0, bubble=False)
            Set(ECTR, 0, bubble=False)
            Set(LED, 0xFFFFFFFF, bubble=False)
            Set(AIO0, 0x8000)
            Set(AIO1, 0x8000)
            SetAtten("ATN0", 0b111111)
            SetAtten("ATN1", 0b111111)

            Plbk_State()                    # 将plbk状态复位
            Plbk_Signal(rrst=sig, wrst=sig) # 选择相应的DDS信号进行控制
            Plbk_Signal()                   # 恢复相应的DDS信号
            DDS_Prof(sig_msk(dds, 0, None)) # 复位DDSprofile
            DDS_Signal(rst=sig)             # 选择相应DDS进行复位
            DDS_Signal()                    # 恢复相应的DDS
            #DDS_RegWrite(dds, 0x0, [0x01, 0x41, 0x20, 0x02])     # 设置控制寄存器1
            DDS_RegWrite(dds, 0x0, [0x01, 0x41, 0x20, 0x02])     # 设置控制寄存器1
            DDS_RegWrite(dds, 0x1, [0x01, 0x41, 0x08, 0xb0+FM])  # 设置控制寄存器2，使能并行数据,权重设为最大
            DDS_RegWrite(dds, 0x2, [0x00, 0x00, 0xC0, 0x00])     # 设置控制寄存器3
            DDS_RegWrite(dds, 0x3, [0x00, 0x00, 0x00, 0x00])     # 设置辅助寄存器
            DDS_RegWrite(dds, 0xA, [0x0C, 0x00, sdg*8, sdr*8])# 设置Multichip寄存器
            ftw = round((frq / 800) * (2 ** 32)).to_bytes(4, 'big')
            DDS_RegWrite(dds, 0x7, list(ftw))    #设置频率调制字寄存器FTW
            
            # 通过SingleTone0设置幅度调频幅度和相位
            asf = round(amp * 16383).to_bytes(2, "big")
            phw = round(pha * 65536).to_bytes(2, "big")
            # --- Experiment Flow ---
            # +14为功能寄存器起始地址；list(*)将字转化为数组用来赋值
            DDS_RegWrite(dds, prof + 14, list(asf + phw + ftw))

            if dds=='DDS0':
                Plbk_State(txen=(1, None))# 信息有效使能,需要保持在高位并行数据才有效
                DDS_Prof(prof=(prof, None), pf=(2, 2), sft=(0,0))
                #DDS_Prof(prof=(None, None), pf=(None, None), sft=(None, None))
            elif dds=='DDS1':
                Plbk_State(txen=(None, 1))# 信息有效使能,需要保持在高位并行数据才有效
                DDS_Prof(prof=(None, prof), pf=(2, 2), sft=(0,0))
            else:
                Plbk_State(txen=(None, None))# 信息有效使能,需要保持在高位并行数据才有效
                DDS_Prof(prof=(None, None), pf=(2, 2), sft=(0,0))
                print('Txen no update.')
            DDS_Signal(upd=sig_msk(dds))# 2.频率数据更新IOUpdate
            DDS_Signal() # 给出一个先1后0的跳变Update信号，该信号同时可以复位PID
    intf.run()
    return 'Parallel frequency data has been run.'

def DDS_ParA_Init(frq=200, amp=0.5, pha=0, dds="DDS0", FM=15, prof=0, sd=15, lmk=0x0B):
    '''DDS parllel Amplitude tune initialization
    fre: freqeuncy for parllel amplitude tuning
    amp: no function 
    pha: phase 
    dds: the destination DDS channel;
    FM(0-15): set Frequency Modulate weight; 
    prof: effective auxiliary Single Tone Mode for frequency and phase setting;
    
    the result of set amplitude tune word is ASF=par_amp<<2=par_amp*4;
    注意： 并行幅度调制为高14位有效，且此时Single tone的幅度不起作用；
    '''
    sdg = sd // 2
    sdr = sd - sdg
    sig = sig_msk(dds)              # 获取控制目标DDS的掩码
    
    with ExperimentFlow():
        with UntimedTask():
            LMK_ResetDelay(dds=(lmk, lmk))
            Set(TTL, 0, bubble=False)
            Set(ECTR, 0, bubble=False)
            Set(LED, 0xFFFFFFFF, bubble=False)
            Set(AIO0, 0x8000)
            Set(AIO1, 0x8000)
            SetAtten("ATN0", 0b111111)
            SetAtten("ATN1", 0b111111)

            Plbk_State()                    # 将plbk状态复位
            Plbk_Signal(rrst=sig, wrst=sig) # 选择相应的DDS信号进行控制
            Plbk_Signal()                   # 恢复相应的DDS信号
            DDS_Prof(sig_msk(dds, 0, None)) # 复位DDSprofile
            DDS_Signal(rst=sig)             # 选择相应DDS进行复位
            DDS_Signal()                    # 恢复相应的DDS
            #DDS_RegWrite(dds, 0x0, [0x01, 0x41, 0x20, 0x02])     # 设置控制寄存器1
            DDS_RegWrite(dds, 0x0, [0x01, 0x41, 0x20, 0x02])     # 设置控制寄存器1
            DDS_RegWrite(dds, 0x1, [0x01, 0x41, 0x08, 0xb0+FM])  # 设置控制寄存器2，使能并行数据,权重设为最大
            DDS_RegWrite(dds, 0x2, [0x00, 0x00, 0xC0, 0x00])     # 设置控制寄存器3
            DDS_RegWrite(dds, 0x3, [0x00, 0x00, 0x00, 0x00])     # 设置辅助寄存器
            DDS_RegWrite(dds, 0xA, [0x0C, 0x00, sdg*8, sdr*8])# 设置Multichip寄存器
            ftw = round((frq / 800) * (2 ** 32)).to_bytes(4, 'big')
            
            # 通过SingleTone0设置幅度调频幅度和相位
            asf = round(amp * 16383).to_bytes(2, "big")
            phw = round(pha * 65536).to_bytes(2, "big")
            DDS_RegWrite(dds, prof + 14, list(asf + phw + ftw))# +14为功能寄存器起始地址；list(*)将字转化为数组用来赋值

            if dds=='DDS0':
                Plbk_State(txen=(1, None))# 信息有效使能,需要保持在高位并行数据才有效
                DDS_Prof(prof=(prof, None), pf=(0, 0), sft=(0,0)) # PID结果左移2位，因为并行幅度调制为高14位有效
            elif dds=='DDS1':
                Plbk_State(txen=(None, 1))# 信息有效使能,需要保持在高位并行数据才有效
                DDS_Prof(prof=(None, prof), pf=(0, 0), sft=(0,0))# PID结果不左移2位，相当于除4，好像设置这个不管用
            else:
                Plbk_State(txen=(None, None))# 信息有效使能,需要保持在高位并行数据才有效
                DDS_Prof(prof=(None, None), pf=(None, None), sft=(0,0))
                print('Txen no update.')
            DDS_Signal(upd=sig_msk(dds))# 2.频率数据更新IOUpdate
            DDS_Signal() # 给出一个先1后0的跳变Update信号，该信号同时可以复位PID
    intf.run()
    return 'Parallel frequency data has been run.'

def DDS_soft_VCO(ad="AIO0",dds="DDS0",f_sys=800):
    '''软硬件结合利用DDS的SingleTone Mode实现VCO，当频率<10Mhz或大于390MHz时退出循环。'''
    Ex(MasterReset)() # single tone mode
    while_key=True
    while while_key:
        d_ad=Ex(SerialSend)(ad)     # 采集AD的数据
        f_set=(d_ad[0]%2**16)*f_sys/2**16;  # 从AD的数据计算相应的频率
        Ex(DDS_ProfWrite)(dds, 0, f_set, 1, 0) # 设置DDS输出频率
        if f_set>390 or f_set<10:
            while_key=False
            # Ex(DDS_ProfWrite)("DDS0", 0, 200, 1, 0) # 设置DDS输出频率
    return 0
    
# ======== DDS parallel 相关函数 end ========

# ======== DSG815 相关函数 begin ========
def DSG815_Set_RF(fre='10kHz',amp='-8dBm', RF='OFF'):
    rm = pyvisa.ResourceManager();#实例化资源管理器
    inst = rm.open_resource('USB0::0x1AB1::0x099C::DSG8A232700168::INSTR');# 实例化设备
    inst.write("*IDN?")
    print(inst.read())
    cmd_fre_str=':SOURce:FREQuency '+fre
    cmd_amp_str=':SOURce:LEVel '+amp
    cmd_key_str=':OUTPut:STATe '+RF
    inst.write(cmd_fre_str);#设置频率
    inst.write(cmd_amp_str);#设置幅度
    inst.write(cmd_key_str);#打开RF开关
    rm.close();# 关闭设备
# ======== DSG815 相关函数 end ========