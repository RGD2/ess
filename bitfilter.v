module bitfilter #(
    parameter N=50
)(
    input wire i, ni, clk,
    output reg q
);
//  to eliminate spurious steps due to EMI and/or metastability
// applies hysteresis but using (a relatively long) time, and is better at ignoring spurious ns scale transisions.
// such as may be generated by interference to the sensor wires
// duration of filter should be limited to no longer than ~microsecond, so as not to impact
// injection timing performance. (encoder inputs will be 1 microsecond late with this design).
// Please note: This is not the same as key-debouncing, which can be zero latency. 
// The latency cannot be avoided here without compromising the glitch-filtering effect!
// Also note that RFI glitches can occur even for differential inputs, because a glitch can cause one or both inputs to move
// outside the 'valid input range' of one or both inputs (typically close to Vcc to gnd), resulting in a failure to cancel common-mode noise,
// which can read as a short glitch which the clock may sample.
// Furthermore, signal reflections can result in a pulse-train of this behaviour also. 
// A microsecond is more than long enough to for such reflections to settle, so long as the cable runs are less than ~50 m long.
// Now with enable signal: intended use is to ignore invalid input signals, if
// that can be determined, eg, A^nA is true if A is not nA.
reg [4:0] pchain;
reg [4:0] nchain;
wire fi = pchain[0];
wire en = (pchain[0] != nchain[0]);
reg [N-1:0] fifo;
wire all = &fifo;
wire any = |fifo;

always @(posedge clk)
begin
    pchain <= {i,pchain[3:1]}; // chain is a pure metastability filter, just sequential D-type flip flops.
    nchain <= {ni,nchain[3:1]};
    fifo <= en ? {fi,fifo[N-1:1]} : fifo;
    q <= q ? any : all;
end
endmodule

