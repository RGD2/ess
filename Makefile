
all: ess.bin

prog: ess.bin icezprog
	./icezprog ess.bin

reset: icezprog
	./icezprog .

icezprog: icezprog.c
	gcc -o icezprog -Wall -Os icezprog.c -lwiringPi -lrt -lstdc++

ess.json: top.v fifo.v serial.v pulsegen.v spiword.v
	yowasp-yosys -p 'synth_ice40 -top top -json ess.json' top.v fifo.v serial.v pulsegen.v spiword.v

ess.asc: ess.json ess.pcf
	#arachne-pnr -d 8k -P tq144:4k -p ess.pcf -o ess.asc ess.blif
	yowasp-nextpnr-ice40 --hx8k --package tq144:4k --freq 40 --json ess.json --pcf ess.pcf --asc ess.asc

ess.bin: ess.asc
	#icetime -d hx8k -c 25 ess.asc
	yowasp-icepack ess.asc ess.bin

clean:
	rm -f testbench testbench.vcd
	rm -f ess.json ess.asc ess.bin

.PHONY: all prog reset clean

