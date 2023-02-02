#!/bin/env python
import serial
from struct import pack
from time import sleep
speed = 400 # RPM
st = 120/400 / 1440
c = int( st / (1/40e6))
import numpy as np
sine = np.clip(32767*np.sin( np.linspace(0, 2*np.pi, 1440)-0.5*np.pi )+32767, 0, 65535)
i = 0
with serial.Serial('/dev/ttyAMA0', 2500000) as ser:
    while (True):
            v = sine[i]
            ser.write(pack('>HH', c, int(v)))
            i += 1
            if i==1440:
                i=0
            sleep(st)

