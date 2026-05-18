`ifndef REGFILE_V
`define REGFILE_V

module regfile #(parameter DATAWIDTH = 32) (
    input clk,
    input resetn,
    input [3:0] readReg1,
    input [3:0] readReg2,
    input [3:0] readReg3,
    input [3:0] readReg4,
    input [3:0] writeReg1,
    input [3:0] writeReg2,
    input [DATAWIDTH-1:0] writeData1,
    input [DATAWIDTH-1:0] writeData2,
    input write,
    output reg signed [DATAWIDTH-1:0] readData1,
    output reg signed [DATAWIDTH-1:0] readData2,
    output reg signed [DATAWIDTH-1:0] readData3,
    output reg signed [DATAWIDTH-1:0] readData4
);

    // 16 καταχωρητές των 32-bit
    reg signed [DATAWIDTH-1:0] registers [15:0];
    integer i;

    // Sequential Block: Εγγραφή & Reset
    always @(posedge clk or negedge resetn) begin
        if(!resetn) begin
            for (i = 0; i < 16; i = i + 1) begin
                registers[i] <= 0;
            end
        end
        else if(write) begin
            registers[writeReg1] <= writeData1;
            registers[writeReg2] <= writeData2;
        end
    end

    // Combinational Block: Ανάγνωση με πλήρες Forwarding
    always @(*) begin
        // Θύρα 1
        if (write && (readReg1 == writeReg1))      readData1 = writeData1;
        else if (write && (readReg1 == writeReg2)) readData1 = writeData2;
        else                                       readData1 = registers[readReg1];

        // Θύρα 2
        if (write && (readReg2 == writeReg1))      readData2 = writeData1;
        else if (write && (readReg2 == writeReg2)) readData2 = writeData2;
        else                                       readData2 = registers[readReg2];

        // Θύρα 3
        if (write && (readReg3 == writeReg1))      readData3 = writeData1;
        else if (write && (readReg3 == writeReg2)) readData3 = writeData2;
        else                                       readData3 = registers[readReg3];

        // Θύρα 4
        if (write && (readReg4 == writeReg1))      readData4 = writeData1;
        else if (write && (readReg4 == writeReg2)) readData4 = writeData2;
        else                                       readData4 = registers[readReg4];
    end

endmodule

`endif
