
module uppdiv #( // unsigned parametric precision division
    parameter XWIDTH=16,  // width of x number in bits
    parameter YWIDTH=16,   // as above, Y can be totally different to X
    parameter QWIDTH=XWIDTH+YWIDTH // may truncate answer to this, lsb to lsb (the usual way vectors get truncated).
    ) (
    input wire clk,
    input wire start,          // start signal
    input wire [XWIDTH-1:0] x,  // dividend
    input wire [YWIDTH-1:0] y,  // divisor
    output     reg [QWIDTH-1:0] q,  // quotient
   
    output     reg done,           // done signal
    output     reg dbz            // divide by zero flag
    );


    // please note carefully: The output of this is not the typical div / mod: It does a full divide, 
    // resulting in a fixed-point binimal number. EG: x / y = q*2^(-YWIDTH)
    // I.E. Q(XWIDTH).(YWIDTH), meaning {(XWIDTH bits 'integer'),(YWIDTH bits 'fractional')}.
    // Thus you will get 32'h0001_0000 as a result if you divide two identical non-zero 16-bit inputs.
    // In general, q[YWIDTH] should always end up the 'units' part of the result, so q[0] == 2**(-YWIDTH).

    // Latency is XWIDTH+YWIDTH+1 clocks (not QWIDTH clks!), and done will stay high until start transitions high again.
    // Both inputs are registered, and start is positive-transition sensitive, and will force a 'restart' if you don't 
    // let it have enough clks of latency to form a result.

    // It is up to you to interpret the results (especially with unequal length input vectors), 
    // and particularly if you are using arbitrary fixed point. (where units index could be anywhere -- even outside your vector).
  
    // verilog does not align indices, instead, it always treats vectors like the least end ([:_] in the definition) is equal to 1, 
    // and the rest is an integer. Therefore right-ends are always aligned, and left-ends may be extended.
    // This means that the meaning of fixed points has to be tracked 'manually', and this sometimes may require
    // a bit shift to 'correct' the operation, especially if you want to add, subtract or compare with another number, 
    // which may be of different scale.

    // EG.: Using a 8 bit x and a 5 bit y results in a 13 bit q, where q[5] is equal to 1.  
    // This can be verified by dividing like values, which will result in only the 'units' bit set. (q[5] in this case)
    // Then, divide xmax by 1 - this should be equal to xmax again - with the fractional bits of q filled with 0's. (q[4:0] in this case)
    // Note that 1 divided by ymax should give you q = 1, ie, only the lsb set.
    // We also define x/0 = all bits set (because this is more useful in practical terms) 
    // it is also the only way you can have all bits set. There is a dbz flag also - so no need to do &q to detect division by zero.

    // Another example: an 8-bit, '18 bit integer' unsigned is divided by a 5-bit, '15 bit integer' unsigned to produce a 12-bit, 8-int.
    // this would need q[0] truncated off. In LV, these look like FXP's with formats <+,8,18> / <+,5,15> = <+,12,8>
    // The reason we keep our 'extra' LSB, is that it means that nonzero / nonzero must = nonzero. If truncated, it is possible that will not hold.
    // Therefore you can only get a zero value by having zero / nonzero.

    // Additionally. if you know that X < Y, then you can just use the bits of each that you 'care' about. This allows you to 'skip' bits.
    // just be careful to keep track of your scaling -- something like x2^(fscale) in your comments or naming:
    // eg use a post-fix like <var>_n4 for *2^-4, and <var>_p2 for *2^2 -- if you wanted to compare (or add/sub) the two, 
    // you need to make their bits completely overlap, by adding zero bits to the bottom end of the 'larger' magnitude number, 
    // so that they both end up with the same _x magnitude.
    // e.g. assign varA_n4 = {varA_p2,{6{1'b0}}}; then do varA_n4 + varB_n4 etc.
    // if you want to 'truncate' a number to drop precision, you should also round them in an appropriate way for your application.
    // i.e., it often makes sense to round so that the minium value possible is 1 instead of 0 - this will behave more linearly if it 
    // gets used as a divisor. It will still saturate, but not to as high a value on the last step.

    localparam YMSB = YWIDTH-1; 
    localparam IQWIDTH = XWIDTH + YWIDTH - 1;  // 'internal' Q-width. One less then 'full' QWIDTH - but QWIDTH might be overridden.

    localparam DIVSTEPS = IQWIDTH; // as many steps as IQWIDTH has WIDTH. Last step for lsb is 'free'
    localparam IQMSB = IQWIDTH-1; 
    localparam SCWIDTH = $clog2(IQWIDTH+1);
    localparam SCMSB = SCWIDTH-1;
    


    reg [YMSB:0] y1;            // copy of divisor - note - now exact size of y
    reg [IQMSB:0] q1, q1_next;   // intermediate quotient
    reg [YWIDTH:0] ac, ac_next;   // accumulator - yes, one bit wider than y.
    reg [SCMSB:0] sc;   // state counter
    wire [YWIDTH+1:0] rd = ac - y1; // remainder difference 
    always @(*) begin
        if (ac >= y1) begin
            {ac_next, q1_next} = {rd[YWIDTH-1:0], q1, 1'b1};
        end else begin
            {ac_next, q1_next} = {ac, q1} << 1;
        end
    end
    reg start_;

    always @(posedge clk) begin
        {y1, dbz, done, sc, q1, ac, q} <= {y1, dbz, done, sc, q1, ac, q};
        start_ <= start;
        if (start>start_) begin
            if (y == 0) begin  // catch divide by zero
                dbz <= 1;
                done <= 1;
                sc <= 0;
                q <= {IQWIDTH{1'b1}}; // all bits set for this case. 
            end else begin
                sc <= DIVSTEPS;
                dbz <= 0;
                done <= 0;
                y1 <= y;
                {ac, q1} <= {{YWIDTH+1{1'b0}}, x, {YWIDTH-1{1'b0}}}; // IQWIDTH + YWIDTH + 1 = 2*YWIDTH + XWIDTH
            end
        end else if (!done) begin
            if (sc) begin
                sc <= {sc - 1}[SCMSB:0];
                ac <= ac_next;
                q1 <= q1_next;
            end else begin  // done
                done <= 1;
                q <= {q1_next,(ac_next >= y1)}; // this gets the lsb.
            end
        end
    end
endmodule