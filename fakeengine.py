#!/bin/env python
import serial
from struct import pack
from time import sleep, perf_counter_ns
speed = 400 # RPM
st = 120/speed/1440
c = int( st / (1/40e6))
import numpy as np
sine = np.clip(32767*(0.7*np.sin( np.linspace(0, 2*np.pi, 1440)-0.5*np.pi)+0.21 )+32767, 0, 65535)
sint = [int(s) for s in sine]
i = 0
dt = 0
lt = perf_counter_ns()
now=lt
v = 0
wait =0

try:    
    with serial.Serial('/dev/ttyAMA0', 2500000) as ser:
        while (True):
                v = sint[i]
                ser.write(pack('>HH', c, v))
                ser.flush() # wait until done
                i += 1
                if i==1440:
                    i=0
                    
                now = perf_counter_ns()
                dt = now-lt
                lt = now
                wait = st - dt
                if wait>0:
                    sleep(wait)

except (KeyboardInterrupt):
    pass

