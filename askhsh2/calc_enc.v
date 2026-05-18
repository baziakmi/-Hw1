`ifndef CALC_ENC_V   
`define CALC_ENC_V

module alu_op_0 (
    input btnl, btnr, btnd,
    output result
);
    wire not1, not2, and1, and2, and3, or1;//wires for alu_op[0]
    assign not1 = ~btnl;
    assign not2 = ~btnd;
    assign and1 = not1 & btnd;
    assign and2 = btnl & btnr;
    assign and3 = and2 & not2;
    assign or1 = and1 | and3;
    assign result = or1;
endmodule

module alu_op_1 (
    input btnl, btnr, btnd,
    output result
);
    wire not1, not2, or1, and1;//wires for alu_op[1]
    assign not1 = ~btnr;
    assign not2 = ~btnd;
    assign or1 = not1 | not2;
    assign and1 = btnl & or1;
    assign result = and1;
endmodule

module alu_op_2 (
    input btnl, btnr, btnd,
    output result
);
    wire not1, not2, xor1, and1, and2, or1;//wires for alu_op[2]
    assign not1 = ~btnl;
    assign and1 = not1 & btnr;
    assign xor1 = btnr ^ btnd;
    assign not2 = ~xor1;
    assign and2 = btnl & not2;
    assign or1 = and1 | and2;
    assign result = or1;
endmodule

module alu_op_3 (
    input btnl, btnr, btnd,
    output result
);
    wire and1, and2, or1;//wires for alu_op[3]
    assign and1 = btnl & btnr;
    assign and2 = btnl & btnd;
    assign or1 = and1 | and2;
    assign result = or1;
endmodule

module calc_enc (
    input btnl,
    input btnr,
    input btnd,
    output [3:0] alu_op
);
    wire op0, op1, op2, op3;
    alu_op_0 u0 (
        .btnl(btnl),
        .btnr(btnr),
        .btnd(btnd),
        .result(op0)
    );
    alu_op_1 u1 (
        .btnl(btnl),
        .btnr(btnr),
        .btnd(btnd),
        .result(op1)
    );
    alu_op_2 u2 (
        .btnl(btnl),
        .btnr(btnr),
        .btnd(btnd),
        .result(op2)
    );
    alu_op_3 u3 (
        .btnl(btnl),
        .btnr(btnr),
        .btnd(btnd),
        .result(op3)
    );
    assign alu_op = {op3, op2, op1, op0};
endmodule

`endif
