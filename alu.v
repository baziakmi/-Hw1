`define SIZE 32

module alu(
    input [SIZE-1:0] op1,
    input [SIZE-1:0] op2,
    input [3:0] alu_op,
    output reg zero,
    output reg signed [SIZE-1:0] result,
    output reg ovf
);
    parameter [3:0] ALUOP_AND  = 4'b1000;
    parameter [3:0] ALUOP_OR   = 4'b1001;
    parameter [3:0] ALUOP_NOR  = 4'b1010;
    parameter [3:0] ALUOP_NAND = 4'b1011;
    parameter [3:0] ALUOP_XOR  = 4'b1100;
    parameter [3:0] ALUOP_ADD  = 4'b0100;
    parameter [3:0] ALUOP_SUB  = 4'b0101;
    parameter [3:0] ALUOP_MUL  = 4'b0110;
    parameter [3:0] ALUOP_SRL  = 4'b0000;
    parameter [3:0] ALUOP_SLL  = 4'b0001;
    parameter [3:0] ALUOP_SRA  = 4'b0010;
    parameter [3:0] ALUOP_SLLV = 4'b0011;

    reg [2*SIZE-1:0] full_product;

    always @ (*) begin 
        ovf = 1'b0;
        full_product = 0;

        case(alu_op)
            ALUOP_AND: result = op1 & op2;
            ALUOP_OR:  result = op1 | op2;
            ALUOP_NOR: result = ~(op1 | op2);
            ALUOP_NAND:result = ~(op1 & op2);
            ALUOP_XOR: result = op1 ^ op2;
            ALUOP_ADD: begin
                     result = op1 + op2;
                     ovf = op1[SIZE-1] == op2[SIZE-1] && result[SIZE-1] != op1[SIZE-1];
                     end
            ALUOP_SUB: begin
                     result = op1 - op2;
                     ovf = op1[SIZE-1] != op2[SIZE-1] && result[SIZE-1] != op1[SIZE-1];
                     end
            ALUOP_MUL: begin
                     full_product = op1 * op2;  
                     result = full_product[SIZE-1:0];
                     ovf = (full_product[2*SIZE-1:SIZE-1] != {SIZE{result[SIZE-1]}});
                     end
            ALUOP_SRL: result = op1 >> op2;
            ALUOP_SLL: result = op1 << op2;
            ALUOP_SRA: result = op1 >>> op2;
            ALUOP_SLLV:result = op1 <<< op2;
            default: result = 32'b0;
        endcase

        if(!result)
            zero = 1'b1;
        else
            zero = 1'b0;
    end
endmodule