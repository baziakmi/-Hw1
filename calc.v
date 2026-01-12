`include "alu.v"
`include "calc_enc.v"

`define OLD_SIZE 16
`define NEW_SIZE 32

module calc (
    input clk,
    input btnc,
    input btnac,
    input btnl,
    input btnr,
    input btnd,
    input signed [OLD_SIZE-1:0] sw,
    output reg signed [OLD_SIZE-1:0] led
);
    reg signed [OLD_SIZE-1:0] accumulator;

    wire signed [NEW_SIZE-1:0] op1_extended;
    wire signed [NEW_SIZE-1:0] op2_extended;
    wire [3:0] alu_operation;
    wire signed [NEW_SIZE-1:0] alu_result;
    wire alu_zero, alu_ovf;
    
    calc_enc encoder (
        .btnl(btnl),
        .btnr(btnr),
        .btnd(btnd),
        .alu_op(alu_operation)
    );
    alu arithmetic_unit (
        .op1(op1_extended),
        .op2(op2_extended),
        .alu_op(alu_operation),
        .zero(alu_zero),
        .result(alu_result),
        .ovf(alu_ovf)
    );

    assign op1_extended = { {NEW_SIZE-OLD_SIZE{accumulator[OLD_SIZE-1]}}, accumulator };
    assign op2_extended = { {NEW_SIZE-OLD_SIZE{sw[OLD_SIZE-1]}}, sw };
    
    always @(posedge clk) begin
        if (btnac) begin
            accumulator = 16'b0;
        end
        else if (btnc) begin
            accumulator = alu_result[OLD_SIZE-1:0];
        end
    end
    
    always @(*) begin
        led = accumulator;
    end
endmodule