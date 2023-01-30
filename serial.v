// Contains simple byte-based rx/tx support for the command interface.
// modularized because it became stable and requires no further changes, and has small interfaces.

// This runs on the RS422 full-duplex port on the cRIO (request 500000 baud) but runs
// actually around 460800 bps.
// The simplest possible 'core' between the two is to just connect one to the other
// and observe that all data is looped back intact.
// The serialrx part includes a buffer so a byte-per system clk can be sent without loss.
// This allows a more complex multi-cycle core to react to commands and emit multi-byte
// data in response to single command bytes.

// That core is not here - it is in the top.v file so it has unrestricted access to all
// signals, and can define control registers as well. It remains in flux as signals
// are added and removed as necessary.

// 50_000_000 / 19_200 ~= 2604;  /4 = 651
// 19200 baud is 'slow mode'

// 50 / 2.5 == 20; /4 = 5
// 2.5M baud is 'fastest mode' - but failed - the cRIO-9045 could not swing the voltage fast enough.
// 50_000_000 / 500_000 = 100; /4 = 25
// 500000 baud is fastest practical with NI's wiring.

//wire[9:0] baudmax = 10'd650; // for 19200 - 0..650 = 651 cycles

`define BAUDMAX 5'd26

// should have been 24 for 500000, but the cRIO-9045 doesn't go at the right speed, instead seems to be doing around 463k when asked for 500k.
// wire[9:0] baudmax = 10'd19;

module serialrx(input clk, rxserialin, output reg newrxstrobe, output reg[7:0] rxbyte);


// ### 19200 baud rate strobe generator

// #### rx generator


// line always idles high if connected
// 8N1 format only: start bit is always 0, stop always 1.

//reg[9:0] brgenctr; // for 19200
reg[4:0] brgenctr; // for 500000
reg[1:0] rxqclk;
reg[1:0] rxclkflg;
wire en_rxqclk; // input to this block -> set high when rx negative edge first arrives to properly synchronise sampling to middle of bits
always @(posedge clk)
begin
    brgenctr <= en_rxqclk ? ((brgenctr == `BAUDMAX) ? 0 : {brgenctr + 1}) : 0; //runs 0..24: 25 states, or 0..650: 651 states
    rxqclk <= en_rxqclk ? ((brgenctr == 0)? {rxqclk + 2'd1} : rxqclk) : 0; // receive quadrature clk -- idles as 0, on en_rxqclk edge spends only 1 system clk in rxqclk=0
    rxclkflg <= {rxclkflg[0], (rxqclk==2'd3)}; // delay sample time to middle of bit for clearer reception (initially spends nearly no time in state 0 -> start of state 3 is middle.
end
wire rxs = rxclkflg[0] > rxclkflg[1]; // strobe to sample bits

// ### rx byte state machine

reg[1:0] rxed;
reg[3:0] rxctr;
// 0 -> waiting for a run (rx: edge detect, tx: wait for push)
// 1..10 -> running (although start bit should be 0, stop bit should be 1)
// 11 -> push output (rx)

reg[9:0] serialin;

always @(posedge clk)
begin
    rxed <= {rxed[0], rxserialin}; // for edge detection
    // these next are defaults to be overridden depending on rxctr
    // so will implement as registers and not infer latches (must be assigned somehow under all possibilities)
    serialin <= serialin;
    newrxstrobe <= 1'b0;
    rxbyte <= rxbyte;
  casez (rxctr)
  4'd0: rxctr <= (rxed[0] < rxed[1]) ? 4'd1 : 0 ; // synchronises on negative edge of start bit
  4'd11: begin
        rxctr <= 4'd12;
        rxbyte <= serialin[8:1]; // copy data out first -- will be reliably stable next clock.
        end
  4'd12: begin
        rxctr <= 0;
        newrxstrobe <= (~serialin[0])&&(serialin[9]); // newly received strobe -- rxbyte set last clock so will be stable.
        // note start bit should always be 0, and stop bit always 1 -- else byte wasn't received properly.
        end
  default: begin
        rxctr <= rxs ? {rxctr + 1} : rxctr; // advances only on rxs == 1
        serialin <= rxs ? {rxserialin,serialin[9:1]} : serialin; // shift lsb in first
        end
  endcase
end
assign en_rxqclk = (rxctr > 0); // tells baud generator to run - so that it synchronises with incoming data.

endmodule



module serialtx(input clk, rst_n, input xmit, input[7:0] txchar, output reg rsout);

// #### tx generator
//reg[9:0] btgenctr; // 19200
reg[4:0] btgenctr; // 500000

reg[1:0] txqclk;
reg[1:0] txclkflg;
wire en_txqclk; // ensures minimum latency when transmitting a new byte
always @(posedge clk)
begin
    btgenctr <= en_txqclk ? ((btgenctr == `BAUDMAX) ? 0 : {btgenctr + 1}) : 0;
    txqclk <= en_txqclk ? ((btgenctr == 0)? {txqclk+1} : txqclk) : 0;
    txclkflg <= {txclkflg[0], (txqclk==2'd1)}; // no delay necessary here
end
wire txs = txclkflg[0] > txclkflg[1]; // strobe to send bits


// ### tx byte state machine
// predefined inputs: xmit txchar
// xmit   : 0 1 1 1 0 
// txchar : x A B C C

reg txbdone; // signal that txbyte has been sent, for handshaking.

wire empty;
wire unloading = ~(en_txqclk||empty);

reg [1:0] ups;
reg fiforead, send;
always @(posedge clk)
begin
    ups <= {ups[0], unloading};
    fiforead <= fiforead ? 1'd0 : (ups[0] > ups[1]); // one byte read strobe per edge here
    send <= fiforead; // delay a cycle for fifo latency
end
// Transmit Request Strobe -> send high one clk to start tx process

// send fifo so we can burst-write multiple bytes
wire full;
wire[7:0] txbyte;
fifo_sc_top txfifo(
  .Data(txchar),
  .Clk(clk),
  .WrEn(xmit&&~full),
  .RdEn(fiforead),
  .Reset(~rst_n),
  .Almost_Empty(),
  .Almost_Full(),
  .Q(txbyte),
  .Empty(empty),
  .Full(full)
);


reg[3:0] txctr; // to count 10 bits
// txctr is slightly different
// 1 : wait for txs edge
// 2 : start bit (always 0)
// 3..10 : byte lsb first
// 11 : stop bit (always 1)
// 12 : done (goes to state 0 after one clk

reg[9:0] serialout;
//reg rsout; // actual output signal -- idles high

always @(posedge clk)
begin
    serialout <= serialout;
    rsout <= 1'b1;
    txbdone <= 1'b0;
  casez (txctr)
  4'd0: begin
        txctr <= send ? 4'd1 : 0; // wait here, or here for 1 clk if send is already true
        serialout <= send ? {1'b1, txbyte, 1'b0} : 10'b1_1111_1111_1;
        end
  4'd1: begin // here 1 clk to start the tx baud generator rolling
        txctr <= txs ? {txctr+1} : txctr;
        end
  4'd12: begin // here 1 clk to generate txbdone strobe
        txctr <= 4'd0; 
        txbdone <= 1'b1;
        end
  default: begin // here during most of transmission
        txctr <= txs ? {txctr+1} : txctr;
        {serialout,rsout} <= txs ? {1'b1, serialout}:{serialout,rsout}; // LSB first, when txs
        end
  endcase
end
assign en_txqclk = (txctr > 0);
//full duplex, not needed:  assign rstri =  ~(txctr > 0); // not in tristate if transmitting

endmodule
