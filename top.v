
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
	input slce1n
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

	// rxfifo
	//
	wire [7:0] data_o;
	wire [7:0] data_i;
	wire read_i, write_i;
	wire fifoFull_o, fifoEmpty_o;
	fifo rxqueue(
		.clk(clk),
		.nreset(resetn),
		.read_i(read_i),
		.write_i(write_i),
		.data_i(data_i),
		.data_o(data_o),
		.fifoFull_o(fifoFull_o),
		.fifoEmpty_o(fifoEmpty_o)
	);
	
	// serial receiver
	serialrx rxer (.clk(clk), .rxserialin(rx), .newrxstrobe(write_i), .rxbyte(data_i));

	reg [31:0] cmd;
	
	// 0 waitin
	// 1 read
	// " "
	// 4 read4
	// 5 waitout
	// 6 writeout, loop
	reg [2:0] state;
	wire done;
	reg start;
	reg [15:0] value;
	reg [15:0] count;
	
	always @(posedge clk) begin
		if (!resetn) begin
			{value,count} <= 32'd0;
			{start,state} <= 4'd0;
			cmd <= 32'd0;
		end else begin
			state <= state;
			start <= 1'b0;
			value <= value;
			count <= count;
			cmd <= cmd;

			casez(state)
				3'd0: 
				begin
					state <= fifoEmpty_o ? 3'd0 : 3'd1;
					read_i <= !fifoEmpty_o;
				end
				3'b0xx:
				begin
					state <= state+3'b1;
					cmd <= {cmd[23:0],data_o};
					read_i <= 1'b1;
				end
				3'd4:
				begin
					state <= 3'd5;
					cmd <= {cmd[23:0],data_o};
					read_i <= 1'b0;
				end
				3'd5:
				begin
					state <= done? 3'd6 : state;
					{count,value} <= cmd;
				end
				3'd6:
				begin
					state <= 3'd0;
					start <= 1'b1;
				end

			endcase
		end
	end

	// timer
	reg[15:0] counter;
	wire[15:0] counter_next = counter-1'd1;
	assign done = (counter==0);

	always @(posedge clk) begin
		if (start)
			counter <= count;
		else
			counter <= done ? 16'd0 : counter_next[15:0];
	end

	// sender
	wire [15:0] sendval = {2'b00, value[15:2]};
	wire running;
	spiword driver (.clk(clk), .we(start), .tx(sendval), .running(running), .MOSI(MOSI), .SCL(SCL));

	always @(posedge clk) begin
		if (resetn)
			CSn <= 1'b1;
		else
			CSn <= !(start | running);
	end

	reg was_running;
	always @(posedge clk) was_running <= running;


endmodule
