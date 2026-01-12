`include "calc.v"

`timescale 1ns/1ps

module tb_calc #(parameter OLD_SIZE = 16, parameter NEW_SIZE = 32)();
    reg clk;
    reg btnc, btnac, btnl, btnr, btnd;
    reg [OLD_SIZE-1:0] sw;
    wire [OLD_SIZE-1:0] led;

    calc uut #(
        .OLD_SIZE(OLD_SIZE),
        .NEW_SIZE(NEW_SIZE)
    ) (
        .clk(clk),
        .btnc(btnc),
        .btnac(btnac),
        .btnl(btnl),
        .btnr(btnr),
        .btnd(btnd),
        .sw(sw),
        .led(led)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        btnc = 0; btnac = 0; 
        btnl = 0; btnr = 0; btnd = 0;
        sw = 16'h0;

        $display("Starting Calculator Testbench...");
        $monitor("Time=%0t | Sw=%h | BTN(L,R,D)=%b%b%b | Acc=%h", $time, sw, btnl, btnr, btnd, led);

        // 1. Reset
        #10 btnac = 1;
        #10 btnac = 0;
        if (led !== 16'h0) $display("Reset Failed!");

        // 2. ADD: btnl,r,d = 0,1,0 | sw = 0x285a
        // Αναμενόμενο: 0x0 + 0x285a = 0x285a
        #10 sw = 16'h285a; btnl = 0; btnr = 1; btnd = 0;
        #10 btnc = 1; #10 btnc = 0; // Trigger accumulation

        // 3. XOR: btnl,r,d = 1,1,1 | sw = 0x04c8
        // Αναμενόμενο: 0x285a ^ 0x04c8 = 0x2c92
        #10 sw = 16'h04c8; btnl = 1; btnr = 1; btnd = 1;
        #10 btnc = 1; #10 btnc = 0;

        // 4. Logical Shift Right: btnl,r,d = 0,0,0 | sw = 0x0005
        // Αναμενόμενο: 0x2c92 >> 5 = 0x0164
        #10 sw = 16'h0005; btnl = 0; btnr = 0; btnd = 0;
        #10 btnc = 1; #10 btnc = 0;

        // 5. NOR: btnl,r,d = 1,0,1 | sw = 0xa085
        // Αναμενόμενο: ~(0x0164 | 0xa085) = 0x5e1a
        #10 sw = 16'ha085; btnl = 1; btnr = 0; btnd = 1;
        #10 btnc = 1; #10 btnc = 0;

        // 6. MULT: btnl,r,d = 1,0,0 | sw = 0x07fe
        // Αναμενόμενο: (0x5e1a * 0x07fe) & 0xFFFF = 0x13cc
        #10 sw = 16'h07fe; btnl = 1; btnr = 0; btnd = 0;
        #10 btnc = 1; #10 btnc = 0;

        // 7. Logical Shift Left: btnl,r,d = 0,0,1 | sw = 0x0004
        // Αναμενόμενο: 0x13cc << 4 = 0x3cc0
        #10 sw = 16'h0004; btnl = 0; btnr = 0; btnd = 1;
        #10 btnc = 1; #10 btnc = 0;

        // 8. NAND: btnl,r,d = 1,1,0 | sw = 0xfa65
        // Αναμενόμενο: ~(0x3cc0 & 0xfa65) = 0xc7bf
        #10 sw = 16'hfa65; btnl = 1; btnr = 1; btnd = 0;
        #10 btnc = 1; #10 btnc = 0;

        // 9. SUB: btnl,r,d = 0,1,1 | sw = 0xb2e4
        // Αναμενόμενο: 0xc7bf - 0xb2e4 = 0x14db
        #10 sw = 16'hb2e4; btnl = 0; btnr = 1; btnd = 1;
        #10 btnc = 1; #10 btnc = 0;

        #20 $display("Testbench Completed.");
        $finish;
    end
endmodule