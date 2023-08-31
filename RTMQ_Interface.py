# -*- coding: utf-8 -*-
"""
Created on Fri Jun 17 11:02:25 2022

@author: ZJH
"""

import re
import serial
from uuid import uuid1


# -------- Module Interface --------


class RTMQ_Interface():
    def __init__(self, cfg, glb=None):
        global SEQ, PRG, CFG
        CFG = cfg
        CFG.generate_reg_list()
        SEQ = Sequence()
        PRG = RTMQ_Programmer(CFG)
        if glb is None:
            glb = globals()
        for r in CFG.REG:
            glb[r] = GPReg(r)

    def set_param(self, **params):
        glb = globals()
        for k, v in params.items():
            glb[k] = v

    def load_script(self, fn):
        with open(fn, "r") as f:
            exec(f.read(), globals())

    def open_port(self, tout):
        PRG.open_port(tout)

    def close_port(self):
        PRG.close_port()

    # download and run the program
    def run(self, ret=None, time=None):
        if time is None:
            time = SEQ.stk[0]["time"] * CFG.T_CYC / 1e9 + 5
        if ret is None:
            ret = SEQ.stk[0]["ret"]
        PRG.download(SEQ.assemble())
        res = PRG.run(ret, time)
        return res

    # run the program as configuration script
    def cfg_run(self, ret=None, time=None):
        if time is None:
            time = SEQ.stk[0]["time"] * CFG.T_CYC / 1e9 + 5
        if ret is None:
            ret = SEQ.stk[0]["ret"]
        PRG.cfg_sequence(SEQ.assemble())
        res = PRG.run(ret, time)
        return res

    # generate RAM init file for simulation
    def simulate(self, fn, seq=None):
        if seq is None:
            asm = PRG.compile(SEQ.assemble())
        else:
            asm = PRG.compile(seq)
        with open(fn, "w") as f:
            f.write(PRG.to_simulation(asm))


class RTMQ_Config:
    # ALU Opcode
    OPC = ["ADD", "AND", "XOR",
           "CLU", "CLS", "CEQ",
           "SGN", "SNE", "SMK", "MOV",
           "SLL", "SLA", "SLC", "REV"]
    # Instruction length in bytes
    XLEN = 4
    # Main memory pipeline latency
    N_PLM = 3
    # ALU Type-I pipeline latency
    N_PLI = 1
    # ALU Type-A pipeline latency
    N_PLA = 4
    # Data stack pop latency
    N_PLS = 3
    # Architectural registers / peripherals
    ACR = ["NUL", "PTR", "WCK", "TIM",
           "ADR", "DAT", "RTS", "STK",
           "URT", "MUL", "MUH", "NOW",
           "T_COND", "T_JUMP", "T_R0", "T_R1",
           "AR0", "AR1", "AR2", "AR3",
           "AR4", "AR5", "AR6", "AR7",
           "RT0", "RT1"]
    # Number of general purpose registers
    N_GPR = 12
    # Functional peripherals
    N_CTR = 8
    FNR = ["LED", "SDAT", "SCTL", "TTL",
           "AIO0", "AIO1", "CADC",
           "SDA0", "SCT0", "SDA1", "SCT1",
           "CDDS", "CMN0", "CMN1"] + \
          [f"CNT{x}" for x in range(N_CTR)] + \
          ["ECTR", "PBK0", "PBK1"]
    # nano-sec per cycle
    T_CYC = 5
    # Instruction memory capacity
    L_MEM = 65536
    # COM port
    PORT = "COM3"
    # Baud rate
    BAUD = 4000000

    SerialSendDelay = 4100
    
    def generate_reg_list(self):
        self.REG = [] + self.ACR
        for i in range(self.N_GPR):
            self.REG += [f"R{i:02X}"]
        self.REG += self.FNR


# --------- Assembler & Programmer ---------

# Bit structure concatenation
def concat(*args):
    dat = 0
    ln = len(args)
    for i in range(ln - 1):
        dat = dat + args[i][0] % (2 ** args[i][1])
        dat = dat * (2 ** args[i + 1][1])
    dat = dat + args[ln - 1][0] % (2 ** args[ln - 1][1])
    return dat


class RTMQ_Assembler:

    def __init__(self, cfg):
        cfg.generate_reg_list()
        self.cfg = cfg
        self.label = dict()
        self.const = dict()
        self.alu_opc = dict()
        for i in range(len(cfg.OPC)):
            self.alu_opc[cfg.OPC[i]] = i
        self.regs = dict()
        for i in range(len(cfg.REG)):
            self.regs[cfg.REG[i]] = i

    # Operand conversion
    # Return value: (val, imm. flag, inv. flag)
    def cnv_opd(self, s):
        if s[0] == "!":
            s = s[1:]
            inv = 1
        else:
            inv = 0
        if s in self.regs.keys():
            return (self.regs[s], 0, inv)
        elif (re.fullmatch("0B[01_]+", s) or
              re.fullmatch("0X[0-9A-F_]+", s) or
              s.isdigit()):
            return (int(s, 0), 1, 0)
        elif (re.fullmatch("-0B[01]+", s) or
              re.fullmatch("-0X[0-9A-F]+", s) or
              re.fullmatch("-[0-9]+", s)):
            return ((2 ** 32 + int(s, 0)) % (2 ** 32), 1, 0)
        elif re.fullmatch("#[0-9A-Z_-]+", s):
            return (self.label[s], 1, 0)
        elif re.fullmatch("\$[0-9A-Z_]+", s):
            return ((2 ** 32 + int(self.const[s])) % (2 ** 32), 1, 0)
        raise RuntimeError(f"Invalid operand: {s}")

    # Compile instruction
    def cmp_ins(self, ins):
        c = re.split("[,< ]+", ins)
        for i in range(c.count("")):
            c.remove("")
        H = int(c[1] == "H")
        F = int(c[2] == "F")
        if c[0] == "NOP":
            return concat((0, 2), (H, 1), (F, 1), (0, 28))
        RD, tmp, nRD = self.cnv_opd(c[3])
        if tmp == 1:
            raise RuntimeError(f"Invalid RD: {c[3]}")
        imm, tmp = self.cnv_opd(c[4])[0:2]
        if c[0] in ["LDL", "LDH"] and tmp == 0:
            raise RuntimeError(f"Invalid operand for Type-I instruction: {c[4]}")
        if c[0] == "LDH":
            return concat((0, 2), (H, 1), (F, 1), (0, 4), (RD, 8),
                          (imm >> 20, 16))
        elif c[0] == "LDL":
            return concat((1, 2), (H, 1), (F, 1), (imm >> 16, 4),
                          (RD, 8), (imm, 16))
        if c[0] not in self.cfg.OPC:
            raise RuntimeError(f"Invalid instruction: {c[0]}")
        opc = self.alu_opc[c[0]]
        if c[0] == "MOV":
            R1, iR1, nR1 = self.cnv_opd(c[4])
            return concat((2 + nRD, 2), (H, 1), (F, 1), (opc, 4),
                          (RD, 8), (4, 3), (nR1, 1), (0, 4), (R1, 8))
        else:
            R0, iR0, nR0 = self.cnv_opd(c[4])
            if c[0] in ("ABS", "REV"):
                R1, iR1, nR1 = (0, 0, 0)
            else:
                R1, iR1, nR1 = self.cnv_opd(c[5])
            t0 = (R0 >> 6) % 2 if iR0 else nR0
            t1 = (R1 >> 6) % 2 if iR1 else nR1
            return concat((2 + nRD, 2), (H, 1), (F, 1), (opc, 4),
                          (RD, 8), (iR0, 1), (iR1, 1),
                          (t0, 1), (t1, 1), (R0, 6), (R1, 6))

    # Compile assembly
    def compile(self, ins):
        tmp = re.split("\n+", ins)
        self.label = {}
        self.const = {}
        lnum = 0
        lin = []
        for s in tmp:
            s = s.strip().upper()
            if re.fullmatch("#[0-9A-Z_-]+:", s):
                self.label[s[:-1]] = lnum
            elif re.match("\$[0-9A-Z_]+ *=", s):
                ts = re.split("=", s)
                val = eval(re.sub("\$[0-9A-Z]+",
                                  lambda m: str(self.const[m.group(0)]),
                                  ts[1].strip()))
                self.const[ts[0].strip()] = val
            elif not (s == "" or s.startswith("%")):
                lin += [s]
                lnum += 1
        asm = [0] * lnum
        for i in range(lnum):
            asm[i] = self.cmp_ins(lin[i])
        return asm

    # Convert assembly to printable machine code form
    def to_raw(self, asm):
        for i in asm:
            t = f"{i:032b}"
            c = t[0:4]
            o = int(t[4:8], 2)
            d = int(t[8:16], 2)
            f = t[16:20]
            if f[0] == "1":
                r0 = int(f[2] + t[20:26], 2)
                f = f"1{f[1]}_{f[3]}"
            else:
                r0 = int(t[20:26], 2)
            if f[1] == "1":
                r1 = int(f[3] + t[26:32], 2)
                f = f"{f[0]}1{f[2]}_"
            else:
                r1 = int(t[26:32], 2)
            if o == 9:
                r0 = 0
                r1 = int(t[24:32], 2)
            i = int(t[4:8] + t[16:32], 2)
            if t[0] == "0":
                s = f"C: {c}      RD: {d:02X}         I: {i:05X}"
            else:
                s = f"C: {c} O: {o:01X} RD: {d:02X} F: {f} R0: {r0:02X} R1: {r1:02X}"
            print(s)

    # Convert assembly to bram-init file for simulation
    def to_simulation(self, asm):
        seq = ""
        for i in asm:
            seq += f"{i:08X}\n"
        return seq


class RTMQ_Programmer(RTMQ_Assembler):
    def __init__(self, cfg):
        super().__init__(cfg)
        self.ser = None
        self.port_cntr = 0

    # generate byte stream for programming
    def to_bytestream(self, asm):
        L = self.cfg.XLEN + 1
        ln = len(asm) - 1
        raw = bytearray(ln*L)
        for i in range(ln):
            raw[i*L:(i+1)*L] = \
                (asm[i] + 2 ** 32).to_bytes(L, "big", signed=False)
        raw[ln*L:(ln+1)*L] = \
            asm[ln].to_bytes(L, "big", signed=False)
        return raw

    # Execute using instruction injection
    def cfg_sequence(self, seq):
        self.seq = "NOP - - \n" + seq + "\nNOP - -"
        self.compiled = self.compile(self.seq)
        self.cmd = self.to_bytestream(self.compiled)

    def _dnld_ins(self, addr, ins):
        s_adr = f"LDL - - ADR {addr}\n"
        s_inh = f"LDH - - DAT {ins}\n"
        s_inl = f"LDL - - DAT {ins}\n"
        return s_adr + s_inh + s_inl

    # Generate download script
    def download(self, seq):
        tmp = self.compile(seq)
        if len(tmp) > self.cfg.L_MEM:
            raise RuntimeError("Program length exceeds memory capacity.")
        cmd = ""
        for i in range(len(tmp)):
            cmd += self._dnld_ins(i, tmp[i])
        cmd += "LDL - F PTR 0\n LDL H - TIM 10"
        self.cfg_sequence(cmd)

    def open_port(self, tout=5):
        if self.ser is None:
            self.ser = serial.Serial(self.cfg.PORT,
                                     self.cfg.BAUD,
                                     timeout=tout)
            self.ser.stopbits = serial.STOPBITS_ONE
        self.port_cntr += 1

    def close_port(self):
        self.port_cntr -= 1
        if self.port_cntr == 0:
            self.ser.close()
            self.ser = None

    def byt_to_int(self, byts):
        res = []
        tmp = 0
        i = 0
        for b in list(byts):
            tmp = tmp * 256 + b
            if i == self.cfg.XLEN - 1:
                res.append(tmp)
                tmp = 0
            i = (i + 1) % self.cfg.XLEN
        return res

    def read_data(self, ret_cnt):
        return self.byt_to_int(self.ser.read(ret_cnt * self.cfg.XLEN))

    def run(self, ret_cnt=0, tout=5):
        if len(self.cmd) == 0:
            raise RuntimeError("No sequence has been loaded.")
        self.open_port(tout)
        self.ser.write(self.cmd)
        if ret_cnt > 0:
            res = self.read_data(ret_cnt)
        else:
            res = None
        self.close_port()
        return res


# --------- Sequence Management ---------


class Sequence():
    def __init__(self):
        self.depth = 50
        self.stk = [0] * self.depth
        for i in range(self.depth):
            self.stk[i] = {"seq": [], "time": 0, "ret": 0}
        self.ptr = 0
        self.sub = {}
        self.assem = ""

    def new_context(self):
        self.ptr += 1
        self.stk[self.ptr] = {"seq": [], "time": 0, "ret": 0}

    def pack_context(self):
        i = self.ptr
        self.ptr -= 1
        return (self.stk[i]["seq"],
                self.stk[i]["time"],
                self.stk[i]["ret"])

    def append_cmd(self, cmd, time=1, ret=0):
        i = self.ptr
        if isinstance(cmd, str):
            self.stk[i]["seq"].append(cmd)
        else:
            self.stk[i]["seq"].extend(cmd)
        self.stk[i]["time"] += time
        self.stk[i]["ret"] += ret

    def prepend_cmd(self, cmd, time=1, ret=0):
        i = self.ptr
        if isinstance(cmd, str):
            self.stk[i]["seq"][0:0] = [cmd]
        else:
            self.stk[i]["seq"][0:0] = cmd
        self.stk[i]["time"] += time
        self.stk[i]["ret"] += ret

    def new_subroutine(self, tag, cmd, time, ret=0):
        tmp = {"seq": [f"#{tag}:"] + cmd,
               "time": time, "ret": ret}
        self.sub[tag] = tmp

    def assemble(self):
        tmp = []
        for k, v in self.sub.items():
            tmp.append("\n".join(v["seq"]))
        all_sub = "\n\n".join(tmp)
        all_seq = "\n".join(self.stk[0]["seq"])
        self.assem = all_seq + "\n\n" + all_sub + "\n"
        return self.assem


# -------- Register Implementation --------


class GPReg():
    def __init__(self, name):
        self.name = name

    def __str__(self):
        return self.name

    def __round__(self):
        return self

    def __lt__(self, other):
        return ["CLU", self.name, str(round(other)), 0, 0, 0]

    def __le__(self, other):
        return ["CLU", str(round(other)), self.name, 1, 0, 0]

    def __gt__(self, other):
        return ["CLU", str(round(other)), self.name, 0, 0, 0]

    def __ge__(self, other):
        return ["CLU", self.name, str(round(other)), 1, 0, 0]
    
    def __eq__(self, other):
        return ["CEQ", self.name, str(round(other)), 0, 0, 0]

    def __ne__(self, other):
        return ["CEQ", self.name, str(round(other)), 1, 0, 0]

    def __add__(self, other):
        return ["ADD", self.name, str(round(other)), 0, 0, 0]

    def __sub__(self, other):
        return ["ADD", self.name, str(round(other)), 0, 0, 1]

    def __and__(self, other):
        return ["AND", self.name, str(round(other)), 0, 0, 0]

    def __or__(self, other):
        return ["AND", self.name, str(round(other)), 1, 1, 1]

    def __xor__(self, other):
        return ["XOR", self.name, str(round(other)), 0, 0, 0]

    def __invert__(self):
        return ["MOV", self.name, "NUL", 0, 1, 0]

    def __abs__(self):
        return ["SGN", self.name, self.name, 0, 0, 0]
    
    def __neg__(self):
        return ["ADD", self.name, "NUL", 0, 1, 0]

    def __lshift__(self, other):
        return ["SLA", self.name, str(round(other)), 0, 0, 0]

    def __rshift__(self, other):
        return ["SLA", self.name, str(round(other)), 0, 0, 1]

    def __radd__(self, other):
        return ["ADD", str(round(other)), self.name, 0, 0, 0]

    def __rsub__(self, other):
        return ["ADD", str(round(other)), self.name, 0, 0, 1]

    def __rand__(self, other):
        return ["AND", str(round(other)), self.name, 0, 0, 0]

    def __ror__(self, other):
        return ["AND", str(round(other)), self.name, 1, 1, 1]

    def __rxor__(self, other):
        return ["XOR", str(round(other)), self.name, 0, 0, 0]

    def __rlshift__(self, other):
        return ["SLA", str(round(other)), self.name, 0, 0, 0]

    def __rrshift__(self, other):
        return ["SLA", str(round(other)), self.name, 0, 0, 1]


def Set(dst: GPReg, expr, H="-", F="-", bubble=True):
    '''
    功能：给目标寄存器赋值。
    dst: destination register; type of which is GPReg;
    expr: expression; it can be a number or a string 
    '''
    if not isinstance(dst, GPReg) and not isinstance(dst, str):
        raise TypeError("Invalid destination register.")
    if isinstance(dst, str):
        if dst.upper() not in CFG.REG:
            raise TypeError("Invalid destination register.")
    if isinstance(expr, str):
        isreg = (expr.upper() in CFG.REG)
    else:
        isreg = isinstance(expr, GPReg)
    if isinstance(expr, list):
        opc, r0, r1, ird, ir0, ir1 = expr
        if r0 in CFG.REG:
            sr0 = f"{'!' if ir0 else ' '}{r0}"
        elif abs(int(r0, 0)) >= 64:
            SEQ.append_cmd([f"LDH - -  T_R0  {r0}",
                            f"LDL - -  T_R0  {r0}",
                             "NOP - -"], 3)
            sr0 = f"{'!' if ir0 else ' '}T_R0"
        elif r0.startswith("-"):
            sr0 = f"{' ' if ir0 else '-'}{r0[1:]}"
        else:
            sr0 = f"{'-' if ir0 else ' '}{r0}"
        if r1 in CFG.REG:
            sr1 = f"{'!' if ir1 else ' '}{r1}"
        elif abs(int(r1, 0)) >= 64:
            SEQ.append_cmd([f"LDH - -  T_R1  {r1}",
                            f"LDL - -  T_R1  {r1}",
                             "NOP - -"], 3)
            sr1 = f"{'!' if ir1 else ' '}T_R1"
        elif r1.startswith("-"):
            sr1 = f"{' ' if ir1 else '-'}{r1[1:]}"
        else:
            sr1 = f"{'-' if ir1 else ' '}{r1}"
        srd = f"{'!' if ird else ' '}{dst}"
        SEQ.append_cmd(f"{opc} {H} {F} {srd} {sr0} {sr1}")
        if bubble:
            Pass(CFG.N_PLA)
    elif isreg:
        SEQ.append_cmd(f"MOV {H} {F}  {dst}  {expr}")
        if bubble:
            Pass(CFG.N_PLA)
    else:
        SEQ.append_cmd(f"LDH - -  {dst}  {expr}")
        SEQ.append_cmd(f"LDL {H} {F}  {dst}  {expr}")
        if bubble:
            Pass(CFG.N_PLI)


def SetMasked(dst, r0, msk, bubble=True):
    Set(dst, ["SMK", str(r0), str(msk), 0, 0, 0], bubble=bubble)


# -------- Architectural Peripheral Functions --------


def SerialSend(dat, wait=True):
    Set("URT", dat, bubble=False)
    if wait:
        Wait(CFG.SerialSendDelay)
    SEQ.append_cmd("", 0, 1)


def MemRead(addr):
    Set("ADR", addr)
    Pass(CFG.N_PLM)


def MemWrite(addr, dat):
    Set("ADR", addr, bubble=False)
    Set("DAT", dat, bubble=False)


def Wait(time):
    if isinstance(time, int):
        est_time = time
    else:
        est_time = 100000 // CFG.T_CYC
    Set("TIM", time, H="H", bubble=False)
    SEQ.append_cmd("", est_time, 0)


def ResetWallClock(ofs):
    SEQ.append_cmd(f"LDL - -  WCK  {ofs}")


def ReadWallClock(h, l):
    Set(l, "WCK", bubble=False)
    Set(h, "TIM")


# -------- Flow Control Structures --------


def _uid():
    return str(uuid1(0))[0:-13]


def RawInstr(ins):
    '''将汇编指令添加到指令队列后'''
    SEQ.append_cmd(ins)


def Pass(n=1):
    for i in range(n):
        SEQ.append_cmd("NOP - -")


def HardWait(n):
    
    cyc = CFG.N_PLA + CFG.N_PLM + 2 # 这个计算结果是什么？
    rep = n // cyc
    if rep == 0:
        Pass(n)
    else:
        Set("T_COND", 1 - rep)
        SEQ.append_cmd(["SNE - -  PTR  PTR  T_COND",
                        "ADD - -  T_COND  T_COND  1"],
                        n - cyc, 0)
        Pass(cyc + n % cyc - 2)


def Label(label):
    SEQ.append_cmd(f"#{label}:", 0)


def Jump(label):
    if isinstance(label, str):
        tmp = f"#{label}"
    else:
        tmp = str(label)
    SEQ.append_cmd(f"LDL - F  PTR  {tmp}", 
                   CFG.N_PLI + CFG.N_PLM + 1, 0)


def JumpIf(cond, label, inv=False):
    if inv:
        cond[3] = cond[3] ^ 1
    Set("T_COND", cond, bubble=False)
    Set("T_JUMP", f"#{label}")
    SEQ.append_cmd(["NOP - - ",
                    "SNE - F  PTR  T_JUMP  T_COND"],
                   CFG.N_PLA + CFG.N_PLM + 1, 0)


def StartTimedTask(time):
    if isinstance(time, int):
        SEQ.append_cmd(["NOP H -", 
                        f"LDH - -  TIM  {time}",
                        f"LDL - -  TIM  {time}",
                        f"LDH - -  NOW  {time}",
                        f"LDL - -  NOW  {time}",
                        "NOP - -",
                        "ADD - -  NOW  NOW  WCK"], time, 0)
    
    if isinstance(time, GPReg) or isinstance(time, str):
        SEQ.append_cmd(["NOP H -", "NOP - -",
                        f"MOV - -  TIM  {time}",
                        "NOP - -", "NOP - -", "NOP - -",
                        f"ADD - -  NOW  WCK  {time}"], 100, 0)


def Call(label):
    if label not in SEQ.sub.keys():
        t, r = (0, 0)
    else:
        t = SEQ.sub[label]["time"]
        r = SEQ.sub[label]["ret"]
    SEQ.append_cmd(["ADD - -  RTS  PTR  2",
                    f"LDL - F  PTR  #{label}"],
                   CFG.N_PLI + CFG.N_PLM + t + 2, r)


def Return():
    SEQ.append_cmd("MOV - F  PTR  RTS",
                   CFG.N_PLA + CFG.N_PLM + 1, 0)


class LoopForever:
    def __init__(self):
        self.tag = f"LoopForever_{_uid()}"

    def __enter__(self):
        SEQ.new_context()

    def __exit__(self, exc_type, exc_val, exc_tb):
        Jump(self.tag)
        s, t, r = SEQ.pack_context()
        Label(self.tag)
        SEQ.append_cmd(s)


class LoopWhile:
    def __init__(self, cond):
        self.cond = cond
        self.tag = f"LoopWhile_{_uid()}"
        self.tb = self.tag + "_Begin"
        self.te = self.tag + "_End"
        self.est_rep = 100

    def __enter__(self):
        Label(self.tb)
        JumpIf(self.cond, self.te, True)
        SEQ.new_context()

    def __exit__(self, exc_type, exc_val, exc_tb):
        Jump(self.tb)
        s, t, r = SEQ.pack_context()
        SEQ.append_cmd(s, t * self.est_rep, r * self.est_rep)
        Label(self.te)


class Scan:
    def __init__(self, reg: GPReg, ini, fin, stp):
        if not isinstance(reg, GPReg):
            raise TypeError("Invalid loop register.")
        self.r = reg
        self.i = ini
        self.f = fin
        self.s = stp
        self.tag = f"Scan_{_uid()}"
        self.tb = self.tag + "_Begin"
        self.te = self.tag + "_End"
        all_int = isinstance(ini, int) and \
                  isinstance(fin, int) and \
                  isinstance(stp, int)
        if all_int:
            self.rep = (abs(fin - ini) - 1) // abs(stp) + 1
            if (fin - ini) * stp <= 0:
                self.rep = 0
        else:
            self.rep = 1

    def __enter__(self):
        Set(self.r, self.i)
        Label(self.tb)
        cnd10 = ["CLS", str(self.f), str(self.r), 0, 0, 0]
        cnd11 = ["CLS", str(self.r), str(self.f), 0, 0, 0]
        Set("T_COND", cnd10, bubble=False)
        Set("T_JUMP", cnd11, bubble=False)
        cnd2 = ["SNE", "NUL", str(self.s), 0, 0]
        Set("T_COND", cnd2 + [1], bubble=False)
        Set("T_JUMP", cnd2 + [0])
        cnd3 = ["AND", "T_COND", "T_JUMP", 0, 1, 1]
        JumpIf(cnd3, self.te)
        SEQ.new_context()

    def __exit__(self, exc_type, exc_val, exc_tb):
        Set(self.r, self.r + self.s, bubble=False)
        Jump(self.tb)
        s, t, r = SEQ.pack_context()
        SEQ.append_cmd(s, t * self.rep, r * self.rep)
        Label(self.te)


class Repeat():
    def __init__(self, reg: GPReg, rep):
        self.r = reg
        self.p = rep
        self.tag = f"Repeat_{_uid()}"
        self.tb = self.tag + "_Begin"
        self.te = self.tag + "_End"
        all_int = isinstance(rep, int)
        if all_int:
            self.rep = rep
        else:
            self.rep = 1

    def __enter__(self):
        Set(self.r, 0)
        Label(self.tb)
        SEQ.new_context()
        JumpIf(self.r >= self.p, self.te)

    def __exit__(self, exc_type, exc_val, exc_tb):
        Set(self.r, self.r + 1, bubble=False)
        Jump(self.tb)
        s, t, r = SEQ.pack_context()
        SEQ.append_cmd(s, t * self.rep, r * self.rep)
        Label(self.te)


class Subroutine:
    def __init__(self, tag, protect=[]):
        self.tag = tag
        self.prt = protect

    def __enter__(self):
        SEQ.new_context()
        if self.prt != []:
            for r in self.prt:
                Set("STK", r, bubble=False)

    def __exit__(self, exc_type, exc_val, exc_tb):
        if self.prt != []:
            self.prt.reverse()
            for r in self.prt:
                Set(r, "STK")
        Return()
        SEQ.new_subroutine(self.tag, *SEQ.pack_context())


class If:
    def __init__(self, cond):
        self.cond = cond
        uid = _uid()
        self.tag_els = f"If_Else_{uid}"
        self.tag_ret = f"If_Retn_{uid}"

    def __enter__(self):
        JumpIf(self.cond, self.tag_els, inv=True)
        SEQ.new_context()

    def __exit__(self, exc_type, exc_val, exc_tb):
        Jump(self.tag_ret)
        s, t, r = SEQ.pack_context()
        SEQ.append_cmd(s, t, r)
        Label(self.tag_els)
        Label(self.tag_ret)


class Elif:
    def __init__(self, cond):
        self.cond = cond
        self.tag_els = f"Elif_Else_{_uid()}"
        if not SEQ.stk[SEQ.ptr]["seq"][-1].startswith("#If_Retn_"):
            raise RuntimeError("ElIf should be immediately after If or ElIf.")
        self.tag_ret = SEQ.stk[SEQ.ptr]["seq"][-1][1:-1]
        del SEQ.stk[SEQ.ptr]["seq"][-1]

    def __enter__(self):
        JumpIf(self.cond, self.tag_els, inv=True)
        SEQ.new_context()

    def __exit__(self, exc_type, exc_val, exc_tb):
        Jump(self.tag_ret)
        s, t, r = SEQ.pack_context()
        SEQ.append_cmd(s, 0, 0)
        Label(self.tag_els)
        Label(self.tag_ret)


class Else:
    def __init__(self):
        if not SEQ.stk[SEQ.ptr]["seq"][-1].startswith("#If_Retn_"):
            raise RuntimeError("Else should be immediately after If or ElIf.")
        self.tag_ret = SEQ.stk[SEQ.ptr]["seq"][-1][1:-1]
        del SEQ.stk[SEQ.ptr]["seq"][-1]

    def __enter__(self):
        SEQ.new_context()

    def __exit__(self, exc_type, exc_val, exc_tb):
        s, t, r = SEQ.pack_context()
        SEQ.append_cmd(s, 0, 0)
        Label(self.tag_ret)


class UntimedTask:
    def __init__(self):
        pass

    def __enter__(self):
        SEQ.append_cmd("NOP H -")
        SEQ.new_context()

    def __exit__(self, exc_type, exc_val, exc_tb):
        s, t, r = SEQ.pack_context()
        SEQ.append_cmd(s, t, r)
        Set("TIM", 10, bubble=False)


class ExperimentFlow:
    def __init__(self, cfg_seq=False):
        SEQ.__init__()
        self.cfg = cfg_seq
        if not cfg_seq:
            Set("TIM", 10, bubble=False)

    def __enter__(self):
        pass

    def __exit__(self, exc_type, exc_val, exc_tb):
        if not self.cfg:
            SEQ.append_cmd(["NOP H -", "NOP H -"])
