#!/bin/env python
import serial
from struct import pack
from time import sleep, perf_counter_ns
speed = 100 # RPM
st = 120/400 / 1440
c = int( st / (1/40e6))
import numpy as np
sine = np.clip(32767*(0.7*np.sin( np.linspace(0, 2*np.pi, 1440)-0.5*np.pi)+0.21 )+32767, 0, 65535)
i = 0
dt = 0
lt = perf_counter_ns()
now=lt
v = 0
wait =0

try:    
    with serial.Serial('/dev/ttyAMA0', 2500000) as ser:
        while (True):
                now = perf_counter_ns()
                dt = now-lt
                lt = now

                v = sine[i]
                ser.write(pack('>HH', c, int(v)))
                i += 1
                if i==1440:
                    i=0
                wait = st - dt
                if wait>0:
                    sleep(wait)

except (KeyboardInterrupt):
    pass

