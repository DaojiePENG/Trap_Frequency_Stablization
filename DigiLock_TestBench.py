import numpy as np
from tqdm import trange
from matplotlib import pyplot as plt
import DigiLock_API as dglk

# -------- Spectrum Analysis --------

def SpecAnalysis_Ref(car, sb, a, p, blen=16000):
    dglk.MasterReset()
    # wav = [[sb + 0.1, 0.1, 0],
    #         [sb + 0.3, 0.2, 0],
    #         [sb + 0.6, 0.3, 0],
    #         [sb + 0.8, 0.4, 0]]
    wav = [[sb, 0.5+a/2, 0], [-sb, 0.5-a/2, 0]]
    s, c = dglk.wave_iq(wav, blen)
    am, ph = dglk.iq_to_polar(s, c)
    dglk.Ex(dglk.SetPolarPlbk, True)("DDS0", am, ph)
    with dglk.ExperimentFlow():
        dglk.DefineFunc()        
        dglk.NewPhaseOrigin()
        dglk.SwitchMode("dual", "dual")
        dglk.DDSWave(400,
                     [car, 1.0, 0],
                     [car, 1.0, 0],
                     sbph0=0, sbph1=0)
    dglk.intf.run()


def SpecAnalysis(sd, lmk, car, sb, amp, da):
    dglk.MasterReset(sd, lmk)
    dglk.Dnld_SBTemplate(0, sb, da)
    # dglk.Dnld_SBTemplate(1, sb, da)
    with dglk.ExperimentFlow():
        dglk.DefineFunc()
        # with dglk.UntimedTask():
        #     dglk.Gen_SBTemplate(0, sb, da)
        #     dglk.Gen_SBTemplate(1, sb, da)            
        dglk.NewPhaseOrigin()
        dglk.SwitchMode("dual", "dual")
        dglk.DDSWave(400,
                     [car, amp, 0],
                     [car, amp, 0],
                     sbph0=0, sbph1=0)
    dglk.intf.run()

        


# -------- Profile Update Test --------

def DDS_ProfUpdate(dur, frq):
    dglk.WAV_DEBUG = True
    dglk.MasterReset()
    with dglk.ExperimentFlow():
        dglk.DefineFunc()
        with dglk.LoopForever():
            dglk.NewPhaseOrigin()
            dglk.SwitchMode("mono", "mono")
            dglk.DEBUG_UPD = (1, 1)
            dglk.DDSWave(34,
                          [frq, 0.1, 0],
                          [frq, 0.1, 0])
            dglk.TTLStage(dur, 1)
            dglk.DEBUG_UPD = (1, 0)
            dglk.DDSWave(dur,
                          [frq*2, 0.1, 0],
                          [frq, 0.1, 0])
            dglk.DEBUG_UPD = (1, 0)
            dglk.DDSWave(dur,
                          [frq, 0.1, 0],
                          [frq, 0.1, 0])
            dglk.Set(dglk.TTL, 0)
            dglk.DEBUG_UPD = (1, 1)
            dglk.DDSWave(dur,
                          [0, 0, 0],
                          [0, 0, 0])
    dglk.intf.run()
    dglk.WAV_DEBUG = False

# -------- AWG Test --------

def DDS_AWG(dur, frq, sf, da, pha, phs):
    dglk.WAV_DEBUG = True
    dglk.intf.open_port(2)
    dglk.MasterReset()
    amp = 0.2
    # dglk.Dnld_SBTemplate(1, sf, da)
    with dglk.ExperimentFlow():
        dglk.DefineFunc()
        with dglk.UntimedTask():
            dglk.Gen_SBTemplate(0, sf, da)
        with dglk.LoopForever():
            dglk.NewPhaseOrigin()

            dglk.SwitchMode("mono", "mono")
            dglk.DEBUG_UPD = (1, 1)
            dglk.DDSWave(dur*2,
                         [frq, amp, 0],
                         [frq, amp, 0])

            dglk.SwitchMode("dual", "mono")
            dglk.DEBUG_UPD = (1, 1)
            dglk.DDSWave(dur,
                         [frq, amp, pha],
                         [frq, amp, pha],
                         sbph0=0, sbph1=0)

            dglk.DDSWave(dur*2,
                          [frq, amp, 0],
                          [frq, amp, 0],
                          sbph0=phs, sbph1=phs)
            dglk.Set(dglk.TTL, 1)

            dglk.SwitchMode("mono", "mono")
            dglk.DDSWave(dur,
                         [frq, amp, 0],
                         [frq, amp, 0])
            dglk.Set(dglk.TTL, 0)
            dglk.DEBUG_UPD = (1, 1)

            dglk.DDSWave(dur,
                         [0, 0, 0],
                         [0, 0, 0])
    dglk.intf.run()
    dglk.intf.close_port()

# -------- CORDIC & Template Generation Test --------

def _to_signed(v, wid=32):
    sgn = 2 ** (wid - 1)
    inv = 2 ** wid - 1
    if v & sgn:
        return -(v ^ inv) - 1
    else:
        return v

def CORDIC_Vfy(x, y, r, p, itr, show=False):
    vx = round(x * 0x7FFF_FFFF)
    vy = round(y * 0x7FFF_FFFF)
    vr = round(r * 0x7FFF_FFFF)
    vp = round(p * 0x8000_0000)
    with dglk.ExperimentFlow():
        dglk.Def_CORDIC(itr)
        with dglk.UntimedTask():
            dglk.PolToRec(vr, vp, dglk.R00, dglk.R01)
            dglk.RecToPol(vx, vy, dglk.R02, dglk.R03)
            dglk.SerialSend(dglk.R00)
            dglk.SerialSend(dglk.R01)
            dglk.SerialSend(dglk.R02)
            dglk.SerialSend(dglk.R03)
    res = dglk.intf.run()
    fx = round(r * np.cos(p * np.pi) * 0x7FFF_FFFF)
    rx = _to_signed(res[0])
    fy = round(r * np.sin(p * np.pi) * 0x7FFF_FFFF)
    ry = _to_signed(res[1])
    fr = round(np.sqrt(x*x + y*y) * 0x7FFF_FFFF)
    rr = _to_signed(res[2])
    fp = round(np.arctan2(y, x) / np.pi * 0x8000_0000)
    rp = _to_signed(res[3])
    ref = np.array([fx, fy, fr, fp])
    ret = np.array([rx, ry, rr, rp])
    if show:
        print(ref)
        print(ret)
        print(ref - ret)
    else:
        return abs(ref - ret)

def CORDIC_RndVfy(itr, cnt):
    m_err = [0] * 4
    dglk.intf.open_port(2)
    for i in range(cnt):
        r = np.random.random()
        p = np.random.random() * 2 - 1
        x = r * np.cos(p * np.pi)
        y = r * np.sin(p * np.pi)
        ex, ey, er, ep = CORDIC_Vfy(x, y, r, p, itr)
        m_err[0] = max(m_err[0], ex)
        m_err[1] = max(m_err[1], ey)
        m_err[2] = max(m_err[2], er)
        m_err[3] = max(m_err[3], ep)
    dglk.intf.close_port()
    return m_err

def CORDIC_Timing():
    with dglk.ExperimentFlow():
        dglk.DefineFunc()
        with dglk.UntimedTask():
            dglk.ResetWallClock(0)
            dglk.Set(dglk.AR0, 0, bubble=False)
            dglk.Set(dglk.AR1, 0x7FFF_FFFF, bubble=False)
            dglk.Set(dglk.AR2, 0, bubble=False)
            dglk.Set(dglk.AR3, 0, bubble=False)
            dglk.Call("CORDIC")
            dglk.SerialSend(dglk.WCK)
    print(dglk.intf.run()[0])

def TempGen_Vfy(frq, da, itr):
    am, ph = dglk.gen_wavetemplate(frq, da)
    cnt = len(am)
    with dglk.ExperimentFlow():
        dglk.Def_GenSBTemplate(debug=True)
        dglk.Def_CORDIC(itr)
        with dglk.UntimedTask():
            dglk.Gen_SBTemplate(0, frq, da)
    res = dglk.intf.run(ret=cnt)
    dif_a = 0
    dif_p = 0
    for j in range(cnt):
        a = res[j] // 256 % 256
        p = res[j] % 256
        ref_a = round(abs(am[j]) * 255)
        ref_p = round(ph[j] / np.pi / 2 % 1 * 256) % 256
        dif_a = max(abs(ref_a - a), dif_a)
        dif_p = max(min(abs(ref_p - p), 256 - abs(ref_p - p)), dif_p)
    return dif_a, dif_p

def TempGen_RndVfy(cnt, itr, blen):
    dglk.intf.open_port(2)
    ma = 0
    mp = 0
    dglk.BUF_LEN = blen
    for i in trange(cnt):
        frq = np.random.random() * 10 + 0.5
        da = np.random.random() * 2 - 1
        ta, tp = TempGen_Vfy(frq, da, itr)
        ma = max(ta, ma)
        mp = max(tp, mp)
    print((ma, mp))
    dglk.intf.close_port()

def TempGen_Timing(pts):
    with dglk.ExperimentFlow():
        dglk.DefineFunc()
        with dglk.UntimedTask():
            dglk.ResetWallClock(0)
            dglk.Set(dglk.AR0, 0, bubble=False)
            dglk.Set(dglk.AR1, 0x0bcd_1234, bubble=False)
            dglk.Set(dglk.AR2, 0, bubble=False)
            dglk.Set(dglk.AR3, pts, bubble=False)
            dglk.Call("GenSBTemplate")
            dglk.SerialSend(dglk.WCK)
    print(dglk.intf.run()[0]*5/1000)

# -------- Pseudo-random Generation Test --------

def LFSR_Vfy(seed, tap, cnt):
    ret = []
    ref = []
    rnd = []
    for i in range(cnt):
        with dglk.ExperimentFlow():
            dglk.Def_GaloisLFSR()
            with dglk.UntimedTask():
                dglk.Set(dglk.AR0, seed)
                dglk.Set(dglk.AR1, tap)
                dglk.Call("GaloisLFSR")
                dglk.SerialSend(dglk.RT0)
                dglk.SerialSend(dglk.RT1)
        res = dglk.intf.run()
        for j in range(32):
            ar0 = (((seed >> 31) % 2 * -1) & tap) ^ seed
            ar0 = (ar0 << 1) % 2 ** 32 + (ar0 >> 31) % 2
            seed = ar0
        ret += [res[0]]
        rnd += [res[1]]
        ref += [ar0]
    return ret, ref, rnd

def LFSR_Timing(seed, tap, cnt):
    with dglk.ExperimentFlow():
        dglk.Def_GaloisLFSR()
        with dglk.UntimedTask():
            dglk.Set(dglk.AR0, seed)
            dglk.Set(dglk.AR1, tap)
            dglk.Set(dglk.RT0, 0)
            dglk.ResetWallClock(-19)
            with dglk.Repeat(dglk.R00, cnt):
                dglk.Call("GaloisLFSR")
                dglk.Set(dglk.AR0, dglk.RT0, bubble=False)
            dglk.ReadWallClock(dglk.R01, dglk.R00)
            dglk.SerialSend(dglk.R01)
            dglk.SerialSend(dglk.R00)
    res = dglk.intf.run()
    return res[0] * 2 ** 32 + res[1]

# -------- Multiplier Test --------

def Mult_Vfy(a, b, sa, sb):
    with dglk.ExperimentFlow():
        with dglk.UntimedTask():
            dglk.Multiply(a, b, dglk.R00, dglk.R01, sa, sb)
            dglk.SerialSend(dglk.R00)
            dglk.SerialSend(dglk.R01)
    res = dglk.intf.run()
    ans = (res[0] << 32) + res[1]
    print((hex(res[0]), hex(res[1])))
    if sa or sb:
        ans = _to_signed(ans, 64)
    return a*b, ans, a*b==ans

# -------- DDS Data Integrity Test --------

RegLen = [4, 4, 4, 4, 4, 6, 6, 4,
          2, 4, 4, 8, 8, 4, 8, 8,
          8, 8, 8, 8, 8, 8, 4, 0, 2, 2]

def DDS_SPI_Bmk(dds, rep, w_div=0, r_div=0, r_ltn=2, sd=15, lmk=0x0B, show=True):
    dglk.intf.open_port(2)
    fal = 0
    for i in trange(rep, disable=not show):
        dglk.MasterReset(sd, lmk)
        reg = np.random.randint(4, 9)
        ln = RegLen[reg]
        dat = list(np.random.randint(0, 255, ln))
        with dglk.ExperimentFlow():
            with dglk.UntimedTask():
                dglk.DDS_RegWrite(dds, 0x1, [0x01, 0x40, 0x08, 0xA0])
                dglk.DDS_RegWrite(dds, reg, dat, w_div)
                dglk.DDS_RegRead(dds, reg, r_div, r_ltn)
        tmp = dglk.intf.run()
        res = dglk.fmt_regval(reg, tmp)
        fal += (res != dat) * 1
        if (res != dat) and show:
            print(res)
            print(dat)
    dglk.intf.close_port()
    if show:
        print(f"{dds} SPI Benchmark complete.")
        print(f"Failed: {fal}\n")
    else:
        return fal

def SegCompare(smp, pool):
    for i in smp:
        if i not in pool:
            return True
    return False

def DDS_Prof_Bmk(dds, rep, sd, lmk, show=True):
    dglk.intf.open_port(2)
    fal = 0
    dcnt = 10
    gap = 3
    scn = max(500 // (gap + 1), 10)
    dst = f"SDA{dds[-1]}"
    for r in trange(rep, disable=not show):
        dglk.MasterReset(sd, lmk)
        f1 = list(np.random.randint(0, 256, 4))
        f2 = list(np.random.randint(0, 256, 4))
        p1 = np.random.randint(0, 8)
        p2 = 7 - p1
        with dglk.ExperimentFlow():
            with dglk.UntimedTask():
                for i in range(8):
                    dglk.DDS_ProfWrite(dds, i, 0, 0, 0)
                dglk.DDS_RegWrite(dds, 0x0E + p1, [0] * 4 + f1)
                dglk.DDS_RegWrite(dds, 0x0E + p2, [0] * 4 + f2)
                with dglk.Repeat(dglk.R02, dcnt):
                    dglk.Set(dglk.R01, dglk.R02 << 4)
                    dglk.DDS_RegRead(dds, 7, wait=False)
                    dglk.Wait(dglk.R01 + dglk.R02)
                    for i in range(scn):
                        dglk.DDS_Prof(dglk.sig_msk(dds, p1, None))
                        dglk.Pass(gap)
                        dglk.DDS_Prof(dglk.sig_msk(dds, p2, None))
                        dglk.Pass(gap)
                    dglk.SerialSend(dst)
        ret = dglk.intf.run()
        for i in range(dcnt):
            tmp = SegCompare(dglk.fmt_regval(7, [ret[i]]), f1 + f2)
            fal += tmp * 1
    dglk.intf.close_port()
    if show:
        print(f"{dds} Profile Switching Benchmark complete.")
        print(f"Failed: {fal}\n")
    else:
        return fal

def DDS_PDAT_Bmk(dds, rep, sd, lmk, show=True):
    dglk.intf.open_port(2)
    fal = 0
    dcnt = 13
    tun = f"TUN{dds[-1]}"
    scn = 10
    sig = dglk.sig_msk(dds, 1, 0)
    frq = list(np.random.randint(0, 0x1_0000, dcnt))
    ref = []
    for r in trange(rep, disable=not show):
        dglk.MasterReset(sd, lmk)
        with dglk.ExperimentFlow():
            with dglk.UntimedTask():
                dglk.SetRawPlbk(dds, frq)
                dglk.DDS_RegWrite(dds, 0x01, [0x01, 0x41, 0x08, 0xB0])
                dglk.Set(tun, 0x0000_00FF)
                dglk.DDS_Prof(prof=(0, 0), pf=(2, 2))
                dglk.Plbk_Signal(tupd=sig, rrst=sig)
                dglk.Plbk_Signal()
                dglk.Plbk_State(txen=sig, plbk=sig)
                with dglk.Repeat(dglk.R02, scn):
                    dglk.DDS_RegRead(dds, 7)
                dglk.Plbk_State()
        ret = dglk.intf.run()
        if ref == []:
            ref = ret
        fal += (ref != ret)
        ref = ret
    dglk.intf.close_port()
    if show:
        print(f"{dds} PDAT Benchmark complete.")
        print(f"Failed: {fal}\n")
    else:
        return fal

def DScan_ClkPhase(dds, lmk, rep):
    dglk.intf.open_port(2)
    p_syn = []
    p_pdc = []
    for d in trange(64):
        ts = 0
        tp = 0
        for r in range(rep):
            dglk.MasterReset(d, lmk)
            with dglk.ExperimentFlow():
                with dglk.UntimedTask():
                    dglk.DDS_RegWrite(dds, 0x1, [0x01, 0x41, 0x08, 0xB0])
                    dglk.Wait(200)
                    dglk.DDS_GetClockPhase(dds, 2000)
            res = dglk.intf.run()
            ts += (res[0] // 0x1_0000)
            tp += (res[0] % 0x1_0000)
        p_syn += [ts // rep]
        p_pdc += [tp // rep]
    dglk.intf.close_port()
    plt.plot(range(64), p_syn, range(64), p_pdc)

def DScan(dds, func, lmk, rep):
    res = []
    dglk.intf.open_port(2)
    for d in trange(64):
        res += [func(dds, rep, sd=d, lmk=lmk, show=False)]
    dglk.intf.close_port()
    plt.plot(range(64), res)

def DDS_IntgTest(rep, sd=15, lmk=0x0B):
    DDS_SPI_Bmk("DDS0", rep * 3, sd=sd, lmk=lmk)
    DDS_SPI_Bmk("DDS1", rep * 3, sd=sd, lmk=lmk)
    DDS_Prof_Bmk("DDS0", rep, sd=sd, lmk=lmk)
    DDS_Prof_Bmk("DDS1", rep, sd=sd, lmk=lmk)
    DDS_PDAT_Bmk("DDS0", rep, sd=sd, lmk=lmk)
    DDS_PDAT_Bmk("DDS1", rep, sd=sd, lmk=lmk)

# -------- PDAT Pipeline Test --------

SIM_FN = "D:/FPGA/Xilinx/DigiLock/BoardTest_RTMQ/ins_mem.txt"

def ppln_test():
    frq = [0xdead, 0x1234, 0xface, 0x5678, 0xcafe, 0x3927]
    sig = (1, 0)
    with dglk.ExperimentFlow():
        with dglk.UntimedTask():
            dglk.SetRawPlbk("DDS0", frq)
            dglk.Set(dglk.TUN0, 0x0000_00FF)
            dglk.Plbk_Signal(tupd=sig, rrst=sig)
            dglk.Plbk_Signal()
            dglk.Plbk_State(txen=sig, plbk=sig)
    dglk.intf.simulate(SIM_FN)




# -------- DAC Test --------

def DAC_Sine(frq):
    ftw = round((frq / 0.5) * 0x1_0000_0000)
    with dglk.ExperimentFlow():
        dglk.Def_CORDIC(16)
        dglk.Set(dglk.R00, 0)
        dglk.Set(dglk.R01, ftw)
        with dglk.LoopForever():
            dglk.PolToRec(0x7FFF_FFFF, dglk.R00, dglk.R02, dglk.R03)
            dglk.Set(dglk.R02, dglk.R02 ^ 0x8000_0000, bubble=False)
            dglk.Set(dglk.R03, dglk.R03 ^ 0x8000_0000, bubble=False)
            dglk.StartTimedTask(400)
            dglk.Set(dglk.AIO0, dglk.R02 >> 16, bubble=False)
            dglk.Set(dglk.AIO1, dglk.R03 >> 16, bubble=False)
            dglk.Set(dglk.R00, dglk.R00 + dglk.R01)
    dglk.intf.run()

def DAC_Noise(seed, tap, src):
    with dglk.ExperimentFlow():
        dglk.Def_GaloisLFSR()
        dglk.Set(dglk.AR0, seed)
        dglk.Set(dglk.AR1, tap)
        with dglk.LoopForever():
            dglk.Call("GaloisLFSR")
            dglk.Set(dglk.AR0, dglk.RT0)
            dglk.StartTimedTask(2000)
            if src == "rnd":
                dglk.Set(dglk.AIO0, dglk.RND)
                dglk.Set(dglk.AIO1, dglk.RND)
            else:
                dglk.Set(dglk.AIO0, dglk.RT1)
                dglk.Set(dglk.AIO1, dglk.RT1 >> 16)
    dglk.intf.run()

# -------- Counter Test --------

def Cntr_Vfy(cnt):
    with dglk.ExperimentFlow():
        with dglk.UntimedTask():
            dglk.TTLOutput(0)
            dglk.CntrStart(range(8))
            with dglk.Repeat(dglk.R00, cnt):
                dglk.TTLOutput(dglk.R00)
            dglk.TTLOutput(0)
            dglk.CntrStop(range(8))
            dglk.SerialSend(dglk.CNT0)
            dglk.SerialSend(dglk.CNT1)
            dglk.SerialSend(dglk.CNT2)
            dglk.SerialSend(dglk.CNT3)
            dglk.SerialSend(dglk.CNT4)
            dglk.SerialSend(dglk.CNT5)
            dglk.SerialSend(dglk.CNT6)
            dglk.SerialSend(dglk.CNT7)
    res = dglk.intf.run()
    print(res)

# -------- Trigger Manager Test --------

def UART_Trig():
    with dglk.ExperimentFlow():
        with dglk.UntimedTask():
            dglk.SerialSend(0xdeadface, wait=False)
            dglk.Set(dglk.ETRG, 0b0000010)
            dglk.WaitExtTrig()
            dglk.SerialSend(0xeffecabe, wait=False)
    res = dglk.intf.run()
    print(res)

def SPI_Trig(reg):
    dglk.MasterReset()
    with dglk.ExperimentFlow():
        dglk.StartTimedTask(100000000)
        dglk.Set(dglk.LED, 0)
        dglk.DDS_RegRead("DDS0", reg, wait=False)
        dglk.Set(dglk.ETRG, 0b0001000)
        dglk.WaitExtTrig()
        dglk.SerialSend(dglk.SDA0, wait=False)
        dglk.StartTimedTask(100)
        dglk.Set(dglk.LED, 0xFFFF)
    res = dglk.intf.run()
    print(dglk.fmt_regval(reg, res))

# -------- DUT: ExtUART Test --------

def ExtUART_Bmk(rep, b_rx, b_tx):
    baud = (b_rx << 16) + b_tx
    dly = max(b_rx, b_tx) * 13 + 20
    dglk.intf.open_port(2)
    fal = 0;
    for i in trange(rep):
        dat = np.random.randint(0, 2 ** 31 - 1, rep)
        with dglk.ExperimentFlow():
            with dglk.UntimedTask():
                dglk.Set(dglk.DUTC, baud)
                for j in range(len(dat)):
                    dglk.Set(dglk.DUTI, dat[j])
                    dglk.Wait(dly)
                    dglk.SerialSend(dglk.DUTI)
        res = dglk.intf.run()
        
        if res != list(dat):
            fal += 1
            print(res)
            print(dat)
    print(f"\nFailed: {fal}")
    dglk.intf.close_port()

def Comm_Test_Srv(b_rx, b_tx):
    baud = (b_rx << 16) + b_tx
    
    # --- DigiLock Board ---
    with dglk.ExperimentFlow():
        with dglk.UntimedTask():
            dglk.Set(dglk.DUTC, baud)
            with dglk.LoopForever():
                dglk.Set(dglk.ETRG, 0b010_0000)
                dglk.WaitExtTrig()
                dglk.Pass(20)
                dglk.Set(dglk.DUTI, dglk.DUTI)
    dglk.intf.run()

def Comm_Srv_Tx(b_rx, b_tx):
    baud = (b_rx << 16) + b_tx
    dat = [0xDEAD_BEEF, 0x1234_5678, 0xEFFE_CAFE, 0x5555_5555,
           0xCABE_9966, 0xAAAA_AAAA, 0x1349_6028, 0xFACE_6789]

    # --- DigiLock Board ---
    with dglk.ExperimentFlow():
        with dglk.UntimedTask():
            dglk.Set(dglk.DUTC, baud)
            with dglk.LoopForever():
                for i in range(len(dat)):
                    dglk.WaitExtTrig()
                    dglk.Set(dglk.DUTI, dat[i])
    dglk.intf.run()

