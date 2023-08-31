# -*- coding: utf-8 -*-
"""
Created on Sat Feb 11 21:25:49 2023

@author: Jack
"""
import numpy as np
import time
from tqdm import trange
from RTMQ_Interface import *
import RTMQ_Interface as rtmq

import datetime
import re
res=re.findall('0xf.+', '0x7fff')
# 将字符串以十进制的形式转化为数
PID_in = int(PID_in_l[0],10) 
PID_ref = int(PID_ref_l[0],10) 
PID_out = int(PID_out_l[0],10)


#0xffff/2=32767
Ex(MasterReset)()
Ex(SerialSend)('AIO0')
Ex(SerialSend)('AIO1')
Ex(Set)('LED',0xffff) # 关闭LED灯

Ex(SetDAC)(0, AIO0)
Ex(SetDAC)(0, 0x7214+0x000f+0xfff)
Ex(SetDAC)(1, 0x0000)

# Ex(SetDAC)(0, 0x7fff-0x0deb) # DA0输出为零；0x7fff-0x0deb~0x7214

Ex(GetADC)(1, 'URT')



# PID 测试
Ex(Set)('R_PID0',0x0000_0001) # k_0
Ex(Set)('R_PID1',0x0000_fff6) # k_1
Ex(Set)('R_PID2',0x0000_0000) # k_2

Ex(Set)('R_PID3',0x0000_0000) # PID input
Ex(Set)('R_PID4',0x0000_000f) # PID reference

Ex(SerialSend)('R_PID0') # PID
Ex(SerialSend)('R_PID1') # PID
Ex(SerialSend)('R_PID2') # PID
Ex(SerialSend)('R_PID3') # PID input
Ex(SerialSend)('R_PID4') # PID reference
Ex(SerialSend)('R_PID5') # PID output

def test():
    with ExperimentFlow():
        with UntimedTask():
            Set("URT", 'R_PID0', bubble=False)
    return intf.run(1) # 要加上1，显式赋值

# 求已知数的补码
bin(-10 & 0xffff)
hex(-10 & 0xffff)
hex(-0b1010 & 0xffff)

num2hex(65526, n_bit=16)



# PID 参数只能设置1次？再次设置就会算出错误的结果，为什么会这样？
# 而且要首先设置它，晚一点就不行;而且有时候行有时候不行
setting=PID_set_par(1, 0, 0, 31295)

readpara=PID_readpara()
readpinner=PID_readinner()

load_par()
readpara=PID_readpara()
readpinner=PID_readinner()


Ex(MasterReset)()
Ex(DDS_ProfWrite)("DDS0", 0, 200, 1, 0) # 设置DDS输出

Ex(MasterReset)() # 初始化DDS
setting=PID_set_par(10, 0, 0) # 设置PID参数


PID_looptime_test(1)        # 单次频率设置    

# ====== DDS para test ======
Ex(MasterReset)()

Ex(DDS_Init)("DDS0", 15) # 初始化DDS

Ex(DDS_RegWrite)("DDS0", 0x1, [0x01, 0x41, 0x08, 0xA0])        # 设置控制寄存器2，恢复初始
Ex(DDS_RegWrite)("DDS0", 0x1, [0x01, 0x41, 0x08, 0xb0+10])        # 设置控制寄存器2，使能并行数据,权重设为最大
dat=0x1000
Ex(Set)('R_DS0',0x1000_0000+dat) # DDS0 parallel input and Update=0# Update 的上升沿载入数据
Ex(Set)('R_DS0',0x1012_0000+dat) # DDS0 parallel input and Update=1
hex(Ex(SerialSend)('R_DS0')[0]) # DDS0 parallel input


DDS_ParaFre(40, amp=0.5, pha=0, FM=15,f_sys=800)

DDS_ParaFre(50) # DDS parallel 频率设置测试函数


DDS_ParaAmp(amp=0.1)    # DDS parallel 幅度设置测试函数
DDS_ParaPha(pha=40) # DDS parallel 相位设置测试函数

# test AD->PID->DDS
Ex(MasterReset)()
setting=PID_set_par(3, 0, 0, 0)
DDS_ParInit(dds="DDS0",FM=15)
readpara=PID_readpara(dds='DDS0')

# new version
DDS_ParF_Init(dds="DDS0",FM=8,sd=15, lmk=0x0B)
pid_setting=setting=PID_set_par(30, 0, 0, 0, dds='DDS0')# parallel data
readpara=PID_readpara(dds='DDS0')

DDS_ParF_Init(dds="DDS1",FM=15,sd=15, lmk=0x0B)
pid_setting=setting=PID_set_par(30, 0, 0, 0, dds='DDS1')# parallel data
readpara=PID_readpara(dds='DDS1')



Ex(DDS_Prof)(prof=(None, None), pf=(2, None), sft=(0, None))
Ex(DDS_Signal)(upd=sig_msk("DDS0"))
Ex(DDS_Signal)() # 测试移位DDS连接


Ex(DDS_Prof)(prof=(None, None), pf=(0, 2), sft=(0,0))

Ex(DDS_Signal)(upd=sig_msk(dds))# 2.频率数据更新IOUpdate
Ex(DDS_Signal)() # 给出一个先1后0的跳变Update信号，该信号同时可以复位PID

frq=210
ftw = round((frq / 800) * (2 ** 32)).to_bytes(4, 'big')
Ex(DDS_RegWrite)(dds, 0x7, list(ftw))    #设置频率调制字寄存器FTW
Ex(DDS_Signal)(upd=sig_msk(dds))# 2.频率数据更新IOUpdate
Ex(DDS_Signal)() # 给出一个先1后0的跳变Update信号，该信号同时可以复位PID

Ex(MasterReset)() # single tone mode
Ex(DDS_ProfWrite)("DDS0", 0, 0.6, 0.5, 0) # 设置DDS输出

DDS_soft_VCO(ad="AIO0") # VCO with Single Tone

dds_setting=DDS_ParF_Init(dds="DDS1",FM=15,sd=15, lmk=0x0B) # DDS1 并行口直接连接的PID_Input 寄存器
Ex(Set)('R_PID3',0x0000_8000) # PID input
Ex(SerialSend)('R_PID3') # PID input

shift_n=0
Ex(DDS_Signal)(upd=sig_msk("DDS0"),shift_n=shift_n)
Ex(DDS_Signal)(shift_n=shift_n) # 测试移位DDS连接
Ex(SerialSend)("CDDS")

# 2023年3月2日12:08:47
# 测试并行幅度调节
dds="DDS0"
dds_setting=DDS_ParF_Init(frq=198, amp=1, pha=0, dds=dds, FM=4, prof=0, sd=15, lmk=0x0B)
pid_setting=setting=PID_set_par(k_p=5, k_i=0, k_d=0, ref=0, dds=dds)# parallel data
Filter_Seta(dds='DDS0',a=0.04) # 设置滤波器参数
readpara=PID_readpara(dds=dds)

def Filter_sweep_a():
    for i in range(300):
        Filter_Seta(dds='DDS0',a=i*100) # 设置滤波器参数
        print(i*100)
dds="DDS1"
dds_setting=DDS_ParF_Init(frq=198, amp=1, pha=0, dds=dds, FM=4, prof=0, sd=15, lmk=0x0B)
pid_setting=setting=PID_set_par(k_p=4, k_i=0, k_d=0, ref=0, dds=dds)# parallel data
Filter_Seta(dds='DDS1',a=0.04) # 设置滤波器参数
readpara=PID_readpara(dds=dds)


Ex(Set)('R_SETA0',30000) # 测试滤波器
Ex(SerialSend)('R_SETA0') # PID output


# 2023年3月2日16:21:24
# 测试并行幅度调制
Ex(DDS_ParA_Init)(frq=200, amp=0.5, pha=0, dds=dds, FM=15, prof=0, sd=15, lmk=0x0B)
pid_setting=setting=PID_set_par(k_p=2, k_i=0, k_d=0, ref=0, dds=dds)# parallel data
readpara=PID_readpara(dds=dds)

# 2023年3月9日09:22:11
FM=4;
par_range=2**(16+FM)
fre_range=2**(16+FM-32)*400 # MHz
delta=20
delta_f=fre_range*delta/2**16

# 2023年3月12日23:26:20

# tuning reg range
FM=4;
tr_range=2**(FM+16)-2**FM;
tf_range=tr_range*800/2**32


# 2023年3月17日11:12:34 set IIR filter
Ex(MasterReset)()
Filter_Seta(dds='DDS0',a=0.05) # 设置滤波器参数
Filter_Seta(dds='DDS1',a=0.05) # 设置滤波器参数
a=0.05;
b=1-a;

IIR_FilterSet(fac_a=0.96, a_1=0.6, b_1=0.9)


Ex(SerialSend)('AIO0')
Ex(SerialSend)('AIO1')

# 射频信号源控制
DSG815_Set_RF(fre='200kHz',amp='12dBm', RF='ON')

# ======================== 光功率锁定 =====================================
# 2023年4月18日21:46:41 光功率稳定
dds="DDS0"
dds_setting=DDS_ParA_Init(frq=220, amp=0.5, pha=0, dds=dds, FM=4, prof=0, sd=15, lmk=0x0B)
Filter_Seta(dds='DDS0',a=0.4) # 设置滤波器参数
Ex(DDS_Prof)(prof=(None, None), pf=(None, None), sft=(10,0)) # 设置PID缩放
pid_setting=setting=PID_set_par(k_p=2**10, k_i=0, k_d=0, ref=15000, dds=dds)# parallel data

pid_setting=setting=PID_set_par(k_p=2**8, k_i=1, k_d=1, ref=15000, dds=dds)# parallel data
pid_setting=setting=PID_set_par(k_p=0, k_i=0, k_d=0, ref=9000, dds=dds)# parallel data
# 从这个结果来看，DDS的输出结果只和k_p的数值和AD的输入有关。输入越大幅度越小，同时k_p越大幅度越小。幅度调制是以1为中心进行反向调制的。

readpara=PID_readpara(dds=dds)

Ex(MasterReset)() # single tone mode
Ex(DDS_ProfWrite)("DDS0", 0, 220, 0.8, 0) # 设置DDS输出4000/2**14

Ex(Set)('R_PIDOUT0',round(2**16*0.1)) # 设置PID0输出偏移
Ex(SerialSend)('R_PIDOUT0')

Ex(Set)('R_PIDOUT0',round(2**16*0.01)) # 设置PID0输出偏移
Ex(Set)('R_PIDOUT0',round(2**16*0.05)) # 设置PID0输出偏移
Ex(Set)('R_PIDOUT0',round(2**16*0.1)) # 设置PID0输出偏移
Ex(Set)('R_PIDOUT0',round(2**16*0.15)) # 设置PID0输出偏移
Ex(Set)('R_PIDOUT0',round(2**16*0.2)) # 设置PID0输出偏移
Ex(Set)('R_PIDOUT0',round(2**16*0.25)) # 设置PID0输出偏移
Ex(Set)('R_PIDOUT0',round(2**16*0.3)) # 设置PID0输出偏移
Ex(Set)('R_PIDOUT0',round(2**16*0.35)) # 设置PID0输出偏移
Ex(Set)('R_PIDOUT0',round(2**16*0.4)) # 设置PID0输出偏移
Ex(Set)('R_PIDOUT0',round(2**16*0.45)) # 设置PID0输出偏移
Ex(Set)('R_PIDOUT0',round(2**16*0.5)) # 设置PID0输出偏移
Ex(Set)('R_PIDOUT0',round(2**16*0.55)) # 设置PID0输出偏移
Ex(Set)('R_PIDOUT0',round(2**16*0.6)) # 设置PID0输出偏移
Ex(Set)('R_PIDOUT0',round(2**16*0.65)) # 设置PID0输出偏移
Ex(Set)('R_PIDOUT0',round(2**16*0.7)) # 设置PID0输出偏移
Ex(Set)('R_PIDOUT0',round(2**16*0.75)) # 设置PID0输出偏移
Ex(Set)('R_PIDOUT0',round(2**16*0.8)) # 设置PID0输出偏移
Ex(Set)('R_PIDOUT0',round(2**16*0.85)) # 设置PID0输出偏移
Ex(Set)('R_PIDOUT0',round(2**16*0.9)) # 设置PID0输出偏移
Ex(Set)('R_PIDOUT0',round(2**16*0.95)) # 设置PID0输出偏移
Ex(Set)('R_PIDOUT0',round(2**16*0.99999)) # 设置PID0输出偏移

# ======================== 光功率锁定 =====================================


# ======================== 拍频锁定 =====================================
# 2023年5月19日17:41:51

dds="DDS0" # 选择DDS口
Filter_Seta(dds='DDS0',a=0.04) # 设置滤波器参数
Ex(DDS_Prof)(prof=(None, None), pf=(None, None), sft=(0,0)) # 设置PID缩放
dds_setting=DDS_ParF_Init(frq=220, amp=0.5, pha=0, dds=dds, FM=16, prof=0, sd=15, lmk=0x0B)
dds_setting=DDS_ParF_Init(frq=220, amp=0.5, pha=0, dds=dds, FM=14, prof=0, sd=15, lmk=0x0B)
dds_setting=DDS_ParF_Init(frq=220, amp=0.5, pha=0, dds=dds, FM=12, prof=0, sd=15, lmk=0x0B)
dds_setting=DDS_ParF_Init(frq=220, amp=0.5, pha=0, dds=dds, FM=10, prof=0, sd=15, lmk=0x0B)
dds_setting=DDS_ParF_Init(frq=220, amp=0.5, pha=0, dds=dds, FM=8, prof=0, sd=15, lmk=0x0B)
dds_setting=DDS_ParF_Init(frq=220, amp=0.5, pha=0, dds=dds, FM=7, prof=0, sd=15, lmk=0x0B)
dds_setting=DDS_ParF_Init(frq=220, amp=0.5, pha=0, dds=dds, FM=6, prof=0, sd=15, lmk=0x0B)
dds_setting=DDS_ParF_Init(frq=220, amp=0.5, pha=0, dds=dds, FM=4, prof=0, sd=15, lmk=0x0B)
dds_setting=DDS_ParF_Init(frq=220, amp=0.5, pha=0, dds=dds, FM=2, prof=0, sd=15, lmk=0x0B)
dds_setting=DDS_ParF_Init(frq=220, amp=0.5, pha=0, dds=dds, FM=1, prof=0, sd=15, lmk=0x0B)
dds_setting=DDS_ParF_Init(frq=220, amp=0.5, pha=0, dds=dds, FM=0, prof=0, sd=15, lmk=0x0B)
dds_setting=DDS_ParF_Init(frq=221, amp=0.5, pha=0, dds=dds, FM=6, prof=0, sd=15, lmk=0x0B)
jh#Ex(DDS_ParA_Init)(frq=220, amp=0.5, pha=0, dds=dds, FM=0, prof=0, sd=15, lmk=0x0B) # 初始化频率调制

dds_setting=DDS_ParF_Init(frq=220, amp=0.5, pha=0, dds="DDS1", FM=16, prof=0, sd=15, lmk=0x0B)
dds_setting=DDS_ParF_Init(frq=220, amp=0.5, pha=0, dds="DDS1", FM=14, prof=0, sd=15, lmk=0x0B)
dds_setting=DDS_ParF_Init(frq=220, amp=0.5, pha=0, dds="DDS1", FM=12, prof=0, sd=15, lmk=0x0B)
dds_setting=DDS_ParF_Init(frq=220, amp=0.5, pha=0, dds="DDS1", FM=10, prof=0, sd=15, lmk=0x0B)
dds_setting=DDS_ParF_Init(frq=220, amp=0.5, pha=0, dds="DDS1", FM=8, prof=0, sd=15, lmk=0x0B)
dds_setting=DDS_ParF_Init(frq=220, amp=0.5, pha=0, dds="DDS1", FM=7, prof=0, sd=15, lmk=0x0B)
dds_setting=DDS_ParF_Init(frq=220, amp=0.5, pha=0, dds="DDS1", FM=6, prof=0, sd=15, lmk=0x0B)
dds_setting=DDS_ParF_Init(frq=220, amp=0.5, pha=0, dds="DDS1", FM=4, prof=0, sd=15, lmk=0x0B)
dds_setting=DDS_ParF_Init(frq=220, amp=0.5, pha=0, dds="DDS1", FM=2, prof=0, sd=15, lmk=0x0B)
dds_setting=DDS_ParF_Init(frq=220, amp=0.5, pha=0, dds="DDS1", FM=1, prof=0, sd=15, lmk=0x0B)
dds_setting=DDS_ParF_Init(frq=220, amp=0.5, pha=0, dds="DDS1", FM=0, prof=0, sd=15, lmk=0x0B)
Ex(SetDAC)(1, 0x7000)
 


Ex(Set)('R_PIDOUT0',round(2**16*0.1)) # 设置PID0输出偏移
Ex(Set)('R_PIDOUT0',round(0)) # 设置PID0输出偏移
Ex(Set)('R_PIDOUT0',round(100)) # 设置PID0h输出偏移
aEx(Set)('R_PIDOUT0',round(200)) # 设置PID0输出偏移
Ex(Set)('R_PIDOUT0',round(300)) # 设置PID0输出偏移
Ex(Set)('R_PIDOUT0',round(400)) # 设置PID0输出偏移
Ex(Set)('R_PIDOUT0',round(500)) # 设置PID0输出偏移
Ex(Set)('R_PIDOUT0',round(1000)) # 设置PID0输出偏移
Ex(Set)('R_PIDOUT0',round(2000)) # 设置PID0输出偏移
Ex(Set)('R_PIDOUT0',round(3000)) # 设置PID0输出偏移
Ex(Set)('R_PIDOUT0',round(4000)) # 设置PID0输出偏移

Ex(Set)('R_PIDOUT0',round(0)) # 设置PID0输出偏移
Ex(Set)('R_PIDOUT0',round(15000)) # 设置PID0输出偏移
Ex(Set)('R_PIDOUT0',round(20000)) # 设置PID0输出偏移
Ex(Set)('R_PIDOUT0',round(32768)) # 设置PID0输出偏移


Ex(DDS_Prof)(prof=(None, None), pf=(None, None), sft=(0,0)) # 设置PID缩放
pid_setting=setting=PID_set_par(k_p=300, k_i=0, k_d=0, ref=-1600, dds=dds)# 设置PID参数
pid_setting=setting=PID_set_par(k_p=300, k_i=0, k_d=0, ref=-1575, dds=dds)# 设置PID参数
pid_setting=setting=PID_set_par(k_p=300, k_i=0, k_d=0, ref=-1550, dds=dds)# 设置PID参数
pid_setting=setting=PID_set_par(k_p=300, k_i=0, k_d=0, ref=-1525, dds=dds)# 设置PID参数
pid_setting=setting=PID_set_par(k_p=100, k_i=0, k_d=0, ref=-1498, dds=dds)# 设置PID参数
pid_setting=setting=PID_set_par(k_p=100, k_i=0, k_d=0, ref=-1475, dds=dds)# 设置PID参数
pid_setting=setting=PID_set_par(k_p=300, k_i=0, k_d=0, ref=-1450, dds=dds)# 设置PID参数
pid_setting=setting=PID_set_par(k_p=300, k_i=0, k_d=0, ref=-1425, dds=dds)# 设置PID参数
pid_setting=setting=PID_set_par(k_p=300, k_i=0, k_d=0, ref=-1400, dds=dds)# 设置PID参数

pid_setting=setting=PID_set_par(k_p=3000, k_i=0, k_d=0, ref=-1498, dds=dds)# 设置PID参数
pid_setting=setting=PID_set_par(k_p=-3000, k_i=0, k_d=0, ref=-1498, dds=dds)# 设置PID参数

pid_setting=setting=PID_set_par(k_p=300, k_i=0, k_d=0, ref=0, dds=dds)# 设置PID参数
pid_setting=setting=PID_set_par(k_p=300, k_i=0, k_d=0, ref=1498, dds=dds)# 设置PID参数

pid_setting=setting=PID_set_par(k_p=0, k_i=0, k_d=0, ref=-0, dds=dds)# 
pid_setting=setting=PID_set_par(k_p=0, k_i=0, k_d=0, ref=1000, dds=dds)# 

Ex(DDS_Prof)(prof=(None, None), pf=(None, None), sft=(10,0)) # 设置PID缩放
pid_setting=setting=PID_set_par(k_p=100, k_i=1, k_d=0, ref=-1498, dds=dds)# 设置PID参数

Ex(DDS_Prof)(prof=(None, None), pf=(None, None), sft=(8,0)) # 设置PID缩放，这套参数似乎不错
pid_setting=setting=PID_set_par(k_p=100, k_i=200, k_d=10, ref=-1498, dds=dds)# 设置PID参数


Ex(DDS_Prof)(prof=(None, None), pf=(None, None), sft=(0,0)) # 设置PID缩放，这套参数似乎不错
pid_setting=setting=PID_set_par(k_p=1, k_i=1, k_d=0, ref=-1498, dds=dds)# 设置PID参数


# see ki
Ex(DDS_Prof)(prof=(None, None), pf=(None, None), sft=(0,0)) # 设置PID缩放
pid_setting=setting=PID_set_par(k_p=0, k_i=0, k_d=0, ref=-1498, dds=dds)# 
pid_setting=setting=PID_set_par(k_p=30000, k_i=0, k_d=0, ref=-1498, dds=dds)# 设置PID参数，有error数据
pid_setting=setting=PID_set_par(k_p=20000, k_i=0, k_d=0, ref=-1498, dds=dds)
pid_setting=setting=PID_set_par(k_p=10000, k_i=0, k_d=0, ref=-1498, dds=dds)
pid_setting=setting=PID_set_par(k_p=5000, k_i=0, k_d=0, ref=-1498, dds=dds)
pid_setting=setting=PID_set_par(k_p=1000, k_i=0, k_d=0, ref=-1498, dds=dds)
pid_setting=setting=PID_set_par(k_p=500, k_i=0, k_d=0, ref=-1498, dds=dds)
pid_setting=setting=PID_set_par(k_p=1, k_i=1, k_d=0, ref=-1498, dds=dds)





pid_setting=setting=PID_set_par(k_p=30000, k_i=1, k_d=0, ref=-1498, dds=dds)# 设置PID参数，
pid_setting=setting=PID_set_par(k_p=30000, k_i=2, k_d=0, ref=-1498, dds=dds)# 设置PID参数，
pid_setting=setting=PID_set_par(k_p=30000, k_i=3, k_d=0, ref=-1498, dds=dds)# 设置PID参数，
pid_setting=setting=PID_set_par(k_p=30000, k_i=5, k_d=0, ref=-1498, dds=dds)# 设置PID参数，
pid_setting=setting=PID_set_par(k_p=30000, k_i=10, k_d=0, ref=-1498, dds=dds)# 设置PID参数
pid_setting=setting=PID_set_par(k_p=30000, k_i=20, k_d=0, ref=-1498, dds=dds)# 设置PID参数
pid_setting=setting=PID_set_par(k_p=30000, k_i=30, k_d=0, ref=-1498, dds=dds)# 设置PID参数，
pid_setting=setting=PID_set_par(k_p=30000, k_i=40, k_d=0, ref=-1498, dds=dds)# 设置PID参数，
pid_setting=setting=PID_set_par(k_p=30000, k_i=50, k_d=0, ref=-1498, dds=dds)# 设置PID参数，

pid_setting=setting=PID_set_par(k_p=30000, k_i=50, k_d=0, ref=-1498, dds=dds)# 设置PID参数，
pid_setting=setting=PID_set_par(k_p=15000, k_i=25, k_d=0, ref=-1498, dds=dds)# 设置PID参数，
pid_setting=setting=PID_set_par(k_p=7500, k_i=12, k_d=0, ref=-1498, dds=dds)# 设置PID参数，
pid_setting=setting=PID_set_par(k_p=3750, k_i=6, k_d=0, ref=-1498, dds=dds)# 设置PID参数，
pid_setting=setting=PID_set_par(k_p=1875, k_i=3, k_d=0, ref=-1498, dds=dds)# 设置PID参数，



pid_setting=setting=PID_set_par(k_p=30000, k_i=60, k_d=0, ref=-1498, dds=dds)# 设置PID参数，
pid_setting=setting=PID_set_par(k_p=30000, k_i=70, k_d=0, ref=-1498, dds=dds)# 设置PID参数，
pid_setting=setting=PID_set_par(k_p=30000, k_i=80, k_d=0, ref=-1498, dds=dds)# 设置PID参数，

pid_setting=setting=PID_set_par(k_p=30000, k_i=80, k_d=0, ref=-1498, dds=dds)# 设置PID参数，
pid_setting=setting=PID_set_par(k_p=15000, k_i=40, k_d=0, ref=-1498, dds=dds)# 设置PID参数，
pid_setting=setting=PID_set_par(k_p=7500, k_i=20, k_d=0, ref=-1498, dds=dds)# 设置PID参数，
pid_setting=setting=PID_set_par(k_p=3750, k_i=10, k_d=0, ref=-1498, dds=dds)# 设置PID参数，
pid_setting=setting=PID_set_par(k_p=1875, k_i=5, k_d=0, ref=-1498, dds=dds)# 设置PID参数，
pid_setting=setting=PID_set_par(k_p=900, k_i=2, k_d=0, ref=-1498, dds=dds)# 设置PID参数，





hpid_setting=setting=PID_set_par(k_p=30000, k_i=90, k_d=0, ref=-1498, dds=dds)# 设置PID参数
pid_setting=setting=PID_set_par(k_p=30000, k_i=100, k_d=0, ref=-1498, dds=dds)# 设置PID参数，


pid_setting=setting=PID_set_par(k_p=30000, k_i=100, k_d=0, ref=-1498, dds=dds)
pid_setting=setting=PID_set_par(k_p=15000, k_i=50, k_d=0, ref=-1498, dds=dds)
pid_setting=setting=PID_set_par(k_p=7500, k_i=25, k_d=0, ref=-1498, dds=dds)
pid_setting=setting=PID_set_par(k_p=3750, k_i=12, k_d=0, ref=-1498, dds=dds)
pid_setting=setting=PID_set_par(k_p=1800, k_i=6, k_d=0, ref=-1498, dds=dds)
pid_setting=setting=PID_set_par(k_p=900, k_i=3, k_d=0, ref=-1498, dds=dds)


pid_setting=setting=PID_set_par(k_p=30000, k_i=110, k_d=0, ref=-1498, dds=dds)# 设置PID参数，
pid_setting=setting=PID_set_par(k_p=30000, k_i=120, k_d=0, ref=-1498, dds=dds)# 设置PID参数，
pid_setting=setting=PID_set_par(k_p=30000, k_i=150, k_d=0, ref=-1498, dds=dds)# 设置PID参数
pid_setting=setting=PID_set_par(k_p=30000, k_i=170, k_d=0, ref=-1498, dds=dds)# 设置PID参数，
pid_setting=setting=PID_set_par(k_p=30000, k_i=200, k_d=0, ref=-1498, dds=dds)# 设置PID参数，
pid_setting=setting=PID_set_par(k_p=30000, k_i=300, k_d=0, ref=-1498, dds=dds)# 设置PID参数，
pid_setting=setting=PID_set_par(k_p=30000, k_i=500, k_d=0, ref=-1498, dds=dds)# 设置PID参数，
pid_setting=setting=PID_set_par(k_p=30000, k_i=1000, k_d=0, ref=-1498, dds=dds)# 设置PID参数，
pid_setting=setting=PID_set_par(k_p=30000, k_i=2000, k_d=0, ref=-1498, dds=dds)# 设置PID参数，
pid_setting=setting=PID_set_par(k_p=30000, k_i=5000, k_d=0, ref=-1498, dds=dds)# 设置PID参数，
pid_setting=setting=PID_set_par(k_p=30000, k_i=10000, k_d=0, ref=-1498, dds=dds)# 设置PID参数，
pid_setting=setting=PID_set_par(k_p=30000, k_i=20000, k_d=0, ref=-1498, dds=dds)# 设置PID参数，
pid_setting=setting=PID_set_par(k_p=30000, k_i=30000, k_d=0, ref=-1498, dds=dds)# 设置PID参数，
# see k_p
Ex(DDS_Prof)(prof=(None, None), pf=(None, None), sft=(0,0)) # 设置PID缩放
pid_setting=setting=PID_set_par(k_p=32000, k_i=20, k_d=0, ref=-1498, dds=dds)# 设置PID参数
pid_setting=setting=PID_set_par(k_p=30000, k_i=20, k_d=0, ref=-1498, dds=dds)# 设置PID参数
pid_setting=setting=PID_set_par(k_p=20000, k_i=20, k_d=0, ref=-1498, dds=dds)# 设置PID参数
pid_setting=setting=PID_set_par(k_p=10000, k_i=20, k_d=0, ref=-1498, dds=dds)# 设置PID参数
pid_setting=setting=PID_set_par(k_p=7000, k_i=20, k_d=0, ref=-1498, dds=dds)# 设置PID参数
pid_setting=setting=PID_set_par(k_p=5000, k_i=20, k_d=0, ref=-1498, dds=dds)# 设置PID参数
pid_setting=setting=PID_set_par(k_p=4000, k_i=20, k_d=0, ref=-1498, dds=dds)# 设置PID参数
pid_setting=setting=PID_set_par(k_p=1000, k_i=20, k_d=0, ref=-1498, dds=dds)# 设置PID参数
pid_setting=setting=PID_set_par(k_p=500, k_i=20, k_d=0, ref=-1498, dds=dds)# 设置PID参数

# set shift
Ex(DDS_Prof)(prof=(None, None), pf=(None, None), sft=(0,0)) # 设置PID缩放
pid_setting=setting=PID_set_par(k_p=500, k_i=1, k_d=0, ref=-1498, dds=dds)# 设置PID参数，
pid_setting=setting=PID_set_par(k_p=1000, k_i=2, k_d=0, ref=-1498, dds=dds)# 设置PID参数
pid_setting=setting=PID_set_par(k_p=1500, k_i=3, k_d=0, ref=-1498, dds=dds)# 设置PID参数
pid_setting=setting=PID_set_par(k_p=2000, k_i=4, k_d=0, ref=-1498, dds=dds)# 设置PID参数
pid_setting=setting=PID_set_par(k_p=3000, k_i=6, k_d=0, ref=-1498, dds=dds)# 设置PID参数
pid_setting=setting=PID_set_par(k_p=5000, k_i=10, k_d=0, ref=-1498, dds=dds)# 设置PID参数，
pid_setting=setting=PID_set_par(k_p=10000, k_i=20, k_d=0, ref=-1498, dds=dds)# 设置PID参数
pid_setting=setting=PID_set_par(k_p=15000, k_i=30, k_d=0, ref=-1498, dds=dds)# 设置PID参数
pid_setting=setting=PID_set_par(k_p=20000, k_i=40, k_d=0, ref=-1498, dds=dds)# 设置PID参数
pid_setting=setting=PID_set_par(k_p=30000, k_i=60, k_d=0, ref=-1498, dds=dds)# 设置PID参数，

pid_setting=setting=PID_set_par(k_p=5000, k_i=1, k_d=0, ref=-1498, dds=dds)# 设置PID参数，
pid_setting=setting=PID_set_par(k_p=10000, k_i=2, k_d=0, ref=-1498, dds=dds)# 设置PID参数
pid_setting=setting=PID_set_par(k_p=15000, k_i=3, k_d=0, ref=-1498, dds=dds)# 设置PID参数
pid_setting=setting=PID_set_par(k_p=20000, k_i=4, k_d=0, ref=-1498, dds=dds)# 设置PID参数
pid_setting=setting=PID_set_par(k_p=25000, k_i=4, k_d=0, ref=-1498, dds=dds)# 设置PID参数
pid_setting=setting=PID_set_par(k_p=30000, k_i=6, k_d=0, ref=-1498, dds=dds)# 设置PID参数


Ex(DDS_Prof)(prof=(None, None), pf=(None, None), sft=(0,0)) # 设置PID缩放，这套参数似乎不错
Ex(DDS_Prof)(prof=(None, None), pf=(None, None), sft=(1,0)) # 设置PID缩放，这套参数似乎不错
Ex(DDS_Prof)(prof=(None, None), pf=(None, None), sft=(2,0)) # 设置PID缩放，这套参数似乎不错
Ex(DDS_Prof)(prof=(None, None), pf=(None, None), sft=(3,0)) # 设置PID缩放，这套参数似乎不错
Ex(DDS_Prof)(prof=(None, None), pf=(None, None), sft=(5,0)) # 设置PID缩放，这套参数似乎不错
Ex(DDS_Prof)(prof=(None, None), pf=(None, None), sft=(8,0)) # 设置PID缩放，这套参数似乎不错
Ex(DDS_Prof)(prof=(None, None), pf=(None, None), sft=(13,0)) # 设置PID缩放，这套参数似乎不错
Ex(DDS_Prof)(prof=(None, None), pf=(None, None), sft=(15,0)) # 设置PID缩放，这套参数似乎不错
Ex(DDS_Prof)(prof=(None, None), pf=(None, None), sft=(16,0)) # 设置PID缩放，这套参数似乎不错

# see k_d
Ex(DDS_Prof)(prof=(None, None), pf=(None, None), sft=(0,0)) # 设置PID缩放
pid_setting=setting=PID_set_par(k_p=30000, k_i=50, k_d=0, ref=-1498, dds=dds)# 设置PID参数，
pid_setting=setting=PID_set_par(k_p=30000, k_i=50, k_d=1, ref=-1498, dds=dds)# 设置PID参数
pid_setting=setting=PID_set_par(k_p=30000, k_i=50, k_d=5, ref=-1498, dds=dds)# 设置PID参数
pid_setting=setting=PID_set_par(k_p=30000, k_i=50, k_d=10, ref=-1498, dds=dds)# 设置PID参数
pid_setting=setting=PID_set_par(k_p=30000, k_i=50, k_d=100, ref=-1498, dds=dds)# 设置PID参数，
pid_setting=setting=PID_set_par(k_p=30000, k_i=50, k_d=1000, ref=-1498, dds=dds)# 设置PID参数
pid_setting=setting=PID_set_par(k_p=30000, k_i=50, k_d=5000, ref=-1498, dds=dds)# 设置PID参数
pid_setting=setting=PID_set_par(k_p=30000, k_i=50, k_d=10000, ref=-1498, dds=dds)# 设置PID参数
pid_setting=setting=PID_set_par(k_p=30000, k_i=50, k_d=20000, ref=-1498, dds=dds)# 设置PID参数
pid_setting=setting=PID_set_par(k_p=30000, k_i=50, k_d=30000, ref=-1498, dds=dds)# 设置PID参数，



pid_setting=setting=PID_set_par(k_p=0, k_i=0, k_d=0, ref=0, dds=dds)# 设置PID参数
abbhreadpara=PID_readpara(dds=dds)

"R_PIDMIN0","R_PIDMAX0", # PID 输出幅度限制
Ex(Set)('R_PIDMIN0',round(-80000)) 
Ex(Set)('R_PIDMAX0',round(80000)) 
Ex(Set)('R_PIDMIN0',round(0)) 
Ex(Set)('R_PIDMAX0',round(0)) 
# ======================== 拍频锁定 =====================================

Ex(MasterReset)() # single tone mode
Ex(DDS_ProfWrite)("DDS0", 0, 220, 0.5, 0) # 设置DDS输出


a



























