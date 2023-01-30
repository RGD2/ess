module spiword (
    input wire clk,
    input wire we,
    input wire [15:0] tx,
    output wire running,
    output wire MOSI,
    output reg SCL);

// Runs a dedicated bidirectional SPI bus transaction for two bytes at half system clock only.
// *hdr = 'half data rate'
// *qdr = 'quarter data rate'
// *fdr = 'full data rate'
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

reg [15:0] sdelay;
reg [15:0] dataout;
wire MOSI = dataout[15];

reg SCL;

assign running = sdelay[15];

always @(posedge clk)
begin
    if (running) begin
        sdelay <= SCL ? sdelay : {sdelay[6:0], 1'b0};
        dataout <= SCL ? dataout : {dataout[6:0],1'b0};
        datain <= SCL ? {datain[6:0], MISO_} : datain;
        SCL <= ~SCL;
    end else begin
        SCL <= 1'b1;
        datain <= datain;
        if (we) begin
            sdelay <= 16'hffff;
            dataout <= tx;
        end else begin
            sdelay <= sdelay;
            dataout <= dataout;
        end
    end
end

endmodule
