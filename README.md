# Engine signals simulator

- LICENSE: CC Zero <https://creativecommons.org/publicdomain/zero/1.0/>
- Hardware:
	- IceZero from shop.trenz-electronic.de
	- RasPi (tested with RasPi 1B+)
	- AnalogDevices MAX5216PMB1# DAC

- Generate a stand-in for a 0.5 to 2.5 VDC 'cylinder pressure' signal, 
and output a corresponding incremental optical encoder single pair (TDC, TIC)

- Use serial feedback to allow host code to avoid buffer over/underflow
- Rate is 'dynamic': Data arrives as a 4-byte binary word from the uart:
	- Two big endian U16's
		- First is a 40MHz count for the state duration
		- Second is the output data for the DAQ
		- Each state toggles the 'TIC' signal
		- every 720th tick toggles 'TDC' high one state
-~~ Includes serial feedback on current state, fifo fullness status ~~
    - Raspberry Pi 1 Model B+ doesn't keep up with more than a few 10's RPM's, 
    But this is 'good enough' for the purpose of exercising the ECU,
- receive fifo space is limited, and no hardware flow control is available,
so host code must send data only as consumed, and avoid buffer overflow.
    - Underflow just results in 'slow' movement with 'pauses', but otherwise works
    - RasPi1B+ cannot keep up with a very high speed anyway, so we'll leave it here,
        - Works well enough for the intended application:

- Application is 'hardware in the loop' testing for an engine ECU, 
which is using a single cylinder pressure signal and crankshaft encoder to monitor engine position.

- This design *would* allow 'replay' of previously collected signals data, 
    if the host can keep up with the required processing speed.
	- However, data as synthesized is 'good enough' for our ECU to sync to.

- Included is a python version  (works but very slow) and a C version (which is **barely** able to keep up with 400 RPM real time on a RasPi 1 B+). 
    - the C version has a nasty habit of leaving an odd number of bytes on the com port buffer, since it doesn't respect signals and properly close the FD. It is *very* Quick&Dirty, and doesn't even do any error checking. 


