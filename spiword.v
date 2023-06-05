module spiword (
    input wire clk,
    input wire we,
    input wire [23:0] tx,
    output wire running,
    output wire MOSI,
    output reg SCL);

// Runs a SPI bus transaction for three bytes at half system clock only.
// N.B. Doesn't handle CS signal: Whatever runs this thing should do that.
// running should not be used for CS! You need to send CS low *Before*
// starting a transfer.

// - 'clk' assumed to be the system clk
// - 'we' going high samples data to send from tx
// - 'running' is high when busy until done: other traffic on tx ignored.
// - MOSI changes on SCL going low, steady on SCL going high
// - SCL runs at half clk rate, and idles high.

// n.b. 'we' gets ignored while busy, so will miss data if you send in a burst! 
// ( 
//      hint: just don't do that, or if you insist:
//      - BYO your own FIFO and,
//      - have 'we' come from the fifo not empty signal and, 
//      - confirm (with an oscilloscope) that run-on packets will
//      come out right, with a pause in SCL for each
//      sequential transfer from the FIFO: I didn't check.
// )

reg [4:0] sdelay;
assign running = |sdelay;
wire [4:0] decrement = sdelay-5'd1;

reg [23:0] dataout;
assign MOSI = dataout[23];

reg SCL;

always @(posedge clk)
begin
    if (running) begin
        sdelay <= SCL ? sdelay : decrement;
        dataout <= SCL ? dataout : {dataout[22:0],1'b0};
        SCL <= ~SCL;
    end else begin
        SCL <= 1'b1;
        if (we) begin
            sdelay <= 5'd24;
            dataout <= tx;
        end else begin
            sdelay <= sdelay;
            dataout <= dataout;
        end
    end
end

endmodule
