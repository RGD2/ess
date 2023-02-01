
module top (
	input clk_100MHz,
      	output reg led1, led2, led3,
	output reg SCL, MOSI, CSn,
	output reg tdc, tic,
	input rx,
	output tx,
	input slmosi,
	output slmiso,
	input slsck,
	input slce0n,
	input slce1n,
    output test
);


	// Clock Generator

	wire clk, pll_locked;

`ifdef TESTBENCH
	assign clk = clk_100MHz, pll_locked = 1;
`else
	wire clk_40MHz;

	SB_PLL40_PAD #(
		.FEEDBACK_PATH("SIMPLE"),
		.DELAY_ADJUSTMENT_MODE_FEEDBACK("FIXED"),
		.DELAY_ADJUSTMENT_MODE_RELATIVE("FIXED"),
		.PLLOUT_SELECT("GENCLK"),
		.FDA_FEEDBACK(4'b1111),
		.FDA_RELATIVE(4'b1111),
		.DIVR(4'b0100),		// DIVR =  4
		.DIVF(7'b0011111),	// DIVF = 31
		.DIVQ(3'b100),		// DIVQ =  4
		.FILTER_RANGE(3'b010)	// FILTER_RANGE = 2
	) pll (
		.PACKAGEPIN   (clk_100MHz),
		.PLLOUTGLOBAL (clk_40MHz ),
		.LOCK         (pll_locked),
		.BYPASS       (1'b0      ),
		.RESETB       (1'b1      )
	);

	assign clk = clk_40MHz;
`endif

	// Reset Generator

	reg [7:0] resetstate = 0;
	reg resetn = 0;

	always @(posedge clk) begin
		resetstate <= pll_locked ? resetstate + !(&resetstate) : 0;
		resetn <= &resetstate;
	end

	// serial receiver
    wire [7:0] rxbyte;
    wire newrx;
	serialrx rxer (.clk(clk), .rxserialin(rx), .newrxstrobe(newrx), .rxbyte(rxbyte));
    
	// rxfifo
	//
    reg read_i;  // control from state machine
	wire [7:0] data_o;
	wire fifoFull_o, fifoEmpty_o;
	fifo rxqueue(
		.clk(clk),
		.nreset(resetn),
		.read_i(read_i),
		.write_i(newrx),
		.data_i(rxbyte),
		.data_o(data_o),
		.fifoFull_o(fifoFull_o),
		.fifoEmpty_o(fifoEmpty_o)
	);
	
    reg [31:0] time;
    reg utick;
    always @(posedge clk) begin
        time <= time + 1;
        utick <= (time[11:0]==0); // 102 us ticks
    end


    // serial loopback (for testing)
    serialtx testloop (.clk(clk), .resetn(resetn), .xmit(newrx), .txchar(rxbyte), .rsout(tx));

    // assign test = tx;

	wire running; // feedback from SPI driver
	reg finished; // feedback from engine position timer

    // main FSM

	// 0 waitin
	// 1 read
	// " "
	// 4 read4
	// 5 waitout
	// 6 writeout, loop
    // reg read_i; // already defined
	reg [2:0] sm_state;
	reg start;
	reg [31:0] cmd;
	reg [15:0] value;
	reg [15:0] count;
	
	always @(posedge clk) begin

        CSn <= 1'b1;
        read_i <= 1'b0;
        start <= 1'b0;

		if (!resetn) begin
			{value,count} <= 32'd0;
			sm_state <= 3'd0;
			cmd <= 32'd0;
		end else begin
			value <= value;
			count <= count;
			cmd <= cmd;

			casex(sm_state)
				3'd0: 
				begin
                    // wait for available data
                    // then load a 4byte command
					sm_state <= fifoEmpty_o ? 3'd0 : 3'd1;
                    read_i <= 1'b1;
				end
                3'd4:
                begin
                    // read 4th byte, don't request another unless fifo is
                    // empty
					sm_state <= fifoEmpty_o ? sm_state : sm_state+3'b1;
					cmd <= fifoEmpty_o ? cmd : {cmd[23:0],data_o};
                    read_i <= fifoEmpty_o; // needed if we need to wait here
                end 
				3'd5:
				begin
					sm_state <= 3'd6;
					{count,value} <= cmd;
                    start <= 1'b1;
                    CSn <= 1'd0; // early assert
				end
				3'd6:
				begin
                    CSn <= 1'd0; // hold CSn asserted until transfer is done
					sm_state <= (start|running) ? sm_state : 3'd7;
                    // first cycle here, start flag will fire, then running
                    // will take over
				end
                3'd7:
                begin
                    CSn <= 1'b1; // deassert
                    // wait for counter to be finished
                    sm_state <= finished ? 3'd0 : sm_state;
                end
				default:
				begin
                    // states 1-3: load 3 bytes, requesting another each time
					sm_state <= fifoEmpty_o ? sm_state : sm_state+3'b1;
					cmd <= fifoEmpty_o ? cmd : {cmd[23:0],data_o};
					read_i <= 1'b1;
				end
			endcase
		end
	end


	// engine position timer
    // reg finished
	reg[15:0] timer;
    wire active = (timer != 0);
    wire[15:0] timer_next = timer-1'd1;

    always @(posedge clk) begin
        if (~resetn) begin
            timer <= 0;
            finished <= 1'b1;
        end else begin
            finished <= ~active;
            if (start) begin
                timer <= count;
            end else begin
                timer <= (active)? timer_next : 16'd0;
            end
        end
    end

    // Encoder simulation
    // reg tic;
    // reg tdc;
    reg [10:0] pos;

	always @(posedge clk) begin
        if (~resetn) begin
            pos <= 0;
            {tic,tdc} <= 0;
        end else begin
            if (start) begin
                if ( pos == 11'd1439 ) begin
                    pos <= 0;
                end else begin
                    pos <= pos + 1'd1;
                end
                tic <= ~tic;
                tdc <= ((pos==0)|(pos==720));
            end else begin
                pos <= pos;
                tic <= tic;
                tdc <= tdc;
            end
        end
	end

	// sender
	wire [23:0] sendval = {2'b01, value, {6{1'b0}}};
	spiword driver (.clk(clk), .we(start), .tx(sendval), .running(running), .MOSI(MOSI), .SCL(SCL));

    // oscilloscope diagnostics

    assign slmiso= 1'b0;
    assign test = finished;

    // LED diagnostics
    pulsegen visibleblink1 (.sysclk(clk), .step(utick), .trigger(newrx), .preset(16'd410), .pulse(led1));
    pulsegen visibleblink2 (.sysclk(clk), .step(utick), .trigger(finished), .preset(16'd410), .pulse(led2));
    pulsegen visibleblink3 (.sysclk(clk), .step(utick), .trigger(start), .preset(16'd410), .pulse(led3));
endmodule
