# -*- coding: utf-8 -*-
"""
Created on Sat Feb 11 21:25:49 2023

@author: Jack
"""

import numpy as np
import time
from tqdm import trange
from DigiLock_API import *


import datetime
import re
res=re.findall('0xf.+', '0x7fff')
# 将字符串以十进制的形式转化为数
# PID_in = int(PID_in_l[0],10) 
# PID_ref = int(PID_ref_l[0],10) 
# PID_out = int(PID_out_l[0],10)



# paralell 
dds="DDS0"
dds_setting=DDS_ParF_Init(frq=227, amp=0.05, pha=0, dds=dds, FM=4, prof=0, sd=15, lmk=0x0B)
reg_dref=round(800*1000000/2**32*0*1000/2**4)
pid_setting=setting=PID_set_par(k_p=200, k_i=0, k_d=0, ref=54028, dds="DDS0")# parallel data
Filter_Seta(dds='DDS0',a=0.04) # 设置滤波器参数

voltage0=Ex(SerialSend)('AIO0')[0]/2**16*13.1-13.1/2
voltage0
#Ex(MasterReset)()

(25487-21889)/2**16*13.1

(22525-21739)/2**16*13.1
