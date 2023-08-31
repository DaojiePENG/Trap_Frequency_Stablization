# -*- coding: utf-8 -*-
"""
Created on Sat Sep  3 23:47:34 2022

@author: ZJH
"""

import DigiLock_API as dglk

def Example_DDSWave():
    dglk.MasterReset()
    with dglk.ExperimentFlow():
        dglk.WaitExtTrig()
        dglk.NewPhaseOrigin()
        dglk.SwitchMode("mono", "mono")
        dglk.DDSWave(2.0, [200.0, 0.5, 0.0], [200.0, 0.5, 0.0])
        dglk.TTLOutput(0xabcf_1234)
        dglk.DDSWave(3.0, [200.0, 0.5, 0.0], [200.0, 0.5, 0.0])
    dglk.intf.run()


def Example_DDSWave(rep):
    dglk.MasterReset()
    with dglk.ExperimentFlow():
        dglk.DefineFunc()
        with dglk.Repeat(dglk.R00, ):
            dglk.WaitExtTrig()
            dglk.NewPhaseOrigin()
            dglk.SwitchMode("mono", "mono")
            # dglk.DDSWave(d0, w0_0, w0_1)
            # dglk.DDSWave(d1, w1_0, w1_1)
            # dglk.DDSWave(d2, w2_0, w2_1)
            dglk.SwitchMode("dual", "dual")
            # dglk.DDSWave(d3, w3_0, w3_1)
            # dglk.DDSWave(d4, w4_0, w4_1)
            # dglk.DDSWave(d5, w5_0, w5_1)
            dglk.SwitchMode("dual", "mono")
            # dglk.DDSWave(d6, w6_0, w6_1)
            dglk.DDSWave(1.0, [0, 0, 0], [0, 0, 0])
    dglk.intf.run()

def Example_Controller(rep):
    dglk.MasterReset()
    with dglk.ExperimentFlow():
        dglk.DefineFunc()
        with dglk.Repeat(dglk.R00, rep):
            # dglk.TTLStage(dt0, ttl0)
            # dglk.TTLStage(dt1, ttl1)
            # dglk.TTLStage(dt2, ttl2)
            dglk.NewPhaseOrigin()
            dglk.SwitchMode("mono", "mono")
            # dglk.DDSWave(d0, w0_0, w0_1)
            # dglk.DDSWave(d1, w1_0, w1_1)
            # dglk.DDSWave(d2, w2_0, w2_1)
            # dglk.TTLStage(dt3, ttl3)
            dglk.SwitchMode("dual", "dual")
            # dglk.DDSWave(d3, w3_0, w3_1)
            # dglk.TTL(ttl4)
            # dglk.DDSWave(d4, w4_0, w4_1)
            # dglk.DDSWave(d5, w5_0, w5_1)
            dglk.SwitchMode("dual", "mono")
            # dglk.DDSWave(d6, w6_0, w6_1)
            dglk.DDSWave(1.0, [0, 0, 0], [0, 0, 0])
            with dglk.UntimedTask():
                dglk.CntrStart([0, 1, 2])
            # dglk.TTLStage(dt5, ttl5)
            with dglk.UntimedTask():
                dglk.CntrStop([0, 1, 2])
                dglk.SerialSend(dglk.CNT0)
                dglk.SerialSend(dglk.CNT1)
                dglk.SerialSend(dglk.CNT2)

    res = dglk.intf.run()

with LoopForever():
    Pass()

with If(R00 > R01):
    Pass()
with Elif(R00 == R01):
    Pass()
with Else():
    Pass()

with Scan(R03, start, stop, step):
    Pass()

