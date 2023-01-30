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
- Includes serial feedback on current state, fifo fullness status
- receive fifo space is limited, and no hardware flow control is available,
so host code must send data only as consumed, and avoid buffer over and underflow

- Application is 'hardware in the loop' testing for an engine ECU, 
which is using a single cylinder pressure signal and crankshaft encoder to monitor engine position.

- This design specifically allows 'replay' of previously collected signals data, 
in order to conduct a 'fairer' test, which can include real-world imperfections.
	- However, data can also just be synthesized 
