`include "alu.v"
`include "regfile.v"

module mac_unit #(parameter SIZE = 32)(
    input [SIZE-1:0] op1,
    input [SIZE-1:0] op2,
    input [SIZE-1:0] op3,
    output [SIZE-1:0] total_result,
    output zero_mul,
    output zero_add,
    output ovf_mul,
    output ovf_add
);
    parameter [3:0] ALUOP_MUL  = 4'b0110;
    parameter [3:0] ALUOP_ADD  = 4'b0100;

    wire [SIZE-1:0] mul_result;
    alu alu_mul (
        .op1(op1),
        .op2(op2),
        .alu_op(ALUOP_MUL),
        .zero(zero_mul),
        .result(mul_result),
        .ovf(ovf_mul)
    );

    alu alu_add (
        .op1(mul_result),
        .op2(op3),
        .alu_op(ALUOP_ADD),
        .zero(zero_add),
        .result(total_result),
        .ovf(ovf_add)
    );
endmodule