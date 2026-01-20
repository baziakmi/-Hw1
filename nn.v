`ifndef NN_V
`define NN_V

`include "mac_unit.v"
`include "alu.v"
`include "regfile.v"
`include "rom.v"

module nn #(parameter SIZE = 32) (
    input [SIZE-1:0] input_1,
    input [SIZE-1:0] input_2,
    input clk,
    input resetn,
    input enable,
    output reg [SIZE-1:0] final_output,
    output reg total_ovf,
    output reg total_zero,
    output reg [2:0] ovf_fsm_stage,
    output reg [2:0] zero_fsm_stage
);
    // Καταστάσεις FSM
    parameter DEACTIVATED = 3'b000;
    parameter LOADING     = 3'b001;
    parameter PRE_PROC    = 3'b010;
    parameter INPUT_LAYER = 3'b011;
    parameter OUTPUT_LAYER= 3'b100;
    parameter POST_PROC   = 3'b101;
    parameter IDLE        = 3'b110;

    // an den yparxei kanena zero h overflow se kamia katastash
    parameter NO_ZERO_OR_OVF = 3'b111;

    // ALU Operations
    parameter ALU_OP_SRA = 4'b0010;
    parameter ALU_OP_SLL = 4'b0001;
    parameter ALU_OP_ADD = 4'b0100;

    reg [2:0] state;
    reg [2:0] next_state;
    reg loading_done;
    reg [7:0] load_counter;

    // Ενδιάμεσοι καταχωρητές
    reg [SIZE-1:0] inter_1, inter_2, inter_3, inter_4, inter_5;

    // Σήματα για το Register File
    reg [3:0] rf_r1, rf_r2, rf_r3, rf_r4, rf_w;//read kai write addresses
    reg [SIZE-1:0] rf_wd; // write data
    reg rf_we;//write enable
    wire [SIZE-1:0] rf_d1, rf_d2, rf_d3, rf_d4;//destination registers

    // Σήματα Datapath
    reg [SIZE-1:0] alu_in11, alu_in12, alu_in21, alu_in22;//alu inputs
    reg [3:0] alu_ctrl;//alu control signal
    wire [SIZE-1:0] alu_out1, alu_out2;//alu results
    wire alu_ovf1, alu_z1, alu_ovf2, alu_z2;//zeroes and overflows

    reg [SIZE-1:0] m1_op1, m1_op2, m1_op3, m2_op1, m2_op2, m2_op3;//mac inputs
    wire [SIZE-1:0] m1_res, m2_res;//mac result
    wire m1_om, m1_oa, m1_zm, m1_za, m2_om, m2_oa, m2_zm, m2_za;//mac overflows and zeroes

    wire [SIZE-1:0] rom_d;//rom data

    // Instantiations
    regfile #(.DATAWIDTH(SIZE)) RF (
        .clk(clk), 
        .resetn(resetn),
        .readReg1(rf_r1), .readReg2(rf_r2), .readReg3(rf_r3), .readReg4(rf_r4),
        .writeReg1(rf_w), 
        .writeData1(rf_wd), 
        .write(rf_we),
        .readData1(rf_d1), .readData2(rf_d2), .readData3(rf_d3), .readData4(rf_d4)
    );

    alu #(.SIZE(SIZE)) ALU_UNIT_1 (
        .op1(alu_in11), .op2(alu_in12), .alu_op(alu_ctrl),
        .result(alu_out1), .ovf(alu_ovf1), .zero(alu_z1)
    );

    alu #(.SIZE(SIZE)) ALU_UNIT_2 (
        .op1(alu_in21), .op2(alu_in22), .alu_op(alu_ctrl),
        .result(alu_out2), .ovf(alu_ovf2), .zero(alu_z2)
    );

    mac_unit #(.SIZE(SIZE)) MAC1 (
        .op1(m1_op1), .op2(m1_op2), .op3(m1_op3),
        .total_result(m1_res), .zero_mul(m1_zm), .zero_add(m1_za), .ovf_mul(m1_om), .ovf_add(m1_oa)
    );

    mac_unit #(.SIZE(SIZE)) MAC2 (
        .op1(m2_op1), .op2(m2_op2), .op3(m2_op3),
        .total_result(m2_res), .zero_mul(m2_zm), .zero_add(m2_za), .ovf_mul(m2_om), .ovf_add(m2_oa)
    );

    WEIGHT_BIAS_MEMORY ROM (.clk(clk), .addr1(load_counter), .dout1(rom_d));

    // ========================================================================
    // BLOCK 1: State Memory (Sequential)
    // ========================================================================
    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            state <= DEACTIVATED;
        else
            state <= next_state;
    end

    // ========================================================================
    // BLOCK 2: Next State Logic (Combinational)
    // ========================================================================
    always @(*) begin
        next_state = state; // Default next state

        case (state)
            DEACTIVATED: begin
                if (enable) next_state = loading_done ? PRE_PROC : LOADING;
            end

            LOADING: begin
                if (load_counter <= 8'd60) next_state = LOADING;
                else                       next_state = PRE_PROC;
            end

            PRE_PROC:    next_state = INPUT_LAYER;

            INPUT_LAYER: next_state = OUTPUT_LAYER;

            OUTPUT_LAYER: next_state = POST_PROC;

            POST_PROC:   next_state = IDLE;

            IDLE: begin
                if (enable) next_state = PRE_PROC; 
                else next_state = DEACTIVATED;     
            end
            
            default: next_state = DEACTIVATED;
        endcase
    end

    // ========================================================================
    // BLOCK 3: Output Logic (Combinational)
    // ========================================================================
    always @(*) begin
        // Defaults
        alu_in11 = 0;
        alu_in12 = 0; alu_in21 = 0; alu_in22 = 0;
        alu_ctrl = 0;
        m1_op1 = 0; m1_op2 = 0;
        m1_op3 = 0;
        m2_op1 = 0; m2_op2 = 0; m2_op3 = 0;
        rf_wd = 0;
        
        case (state)
            LOADING: begin
                rf_wd = rom_d;//regfile write data from rom
            end

            PRE_PROC: begin
                alu_in11 = input_1; alu_in12 = rf_d1; 
                alu_in21 = input_2; alu_in22 = rf_d2; 
                alu_ctrl = ALU_OP_SRA;//input >>> rf_d gia 1 kai 2
            end

            INPUT_LAYER: begin
                m1_op1 = inter_1; m1_op2 = rf_d1; m1_op3 = rf_d2;
                m2_op1 = inter_2; m2_op2 = rf_d3; m2_op3 = rf_d4;
                //mc_out = inter_1 * rf_d1 + rf_d2 kai to allo
            end

            OUTPUT_LAYER: begin
                m1_op1 = inter_3; m1_op2 = rf_d1; m1_op3 = 0;
                m2_op1 = inter_4; m2_op2 = rf_d2; m2_op3 = rf_d3;
                //mc_out = inter_3 * rf_d1 + 0 kai to allo
                alu_in11 = m1_res; alu_in12 = m2_res; 
                alu_ctrl = ALU_OP_ADD;
                //alu_out1 = m1_res + m2_res
            end

            POST_PROC: begin
                alu_in11 = inter_5; alu_in12 = rf_d1; 
                alu_ctrl = ALU_OP_SLL;
                //alu_out1 = inter_5 <<< rf_d1
            end
        endcase
    end

    // ========================================================================
    // DATAPATH REGISTERS (Sequential)
    // ========================================================================
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            loading_done <= 0;
            load_counter <= 0;
            rf_we <= 0;
            total_ovf <= 0;
            total_zero <= 0;
            ovf_fsm_stage <= NO_ZERO_OR_OVF;
            zero_fsm_stage <= NO_ZERO_OR_OVF;
            final_output <= 0;
            
            inter_1 <= 0; inter_2 <= 0; inter_3 <= 0; inter_4 <= 0; inter_5 <= 0;
            rf_r1 <= 0; rf_r2 <= 0; rf_r3 <= 0; rf_r4 <= 0;
            rf_w <= 0;
        end else begin
            if(state == DEACTIVATED) begin
                if(enable) begin 
                    total_ovf <= 0; total_zero <= 0;
                    ovf_fsm_stage <= NO_ZERO_OR_OVF;
                    zero_fsm_stage <= NO_ZERO_OR_OVF; 
                    load_counter <= 0;
                end
            end 
            else if (state == LOADING) begin
                if (load_counter <= 8'd60) begin //an load_counter <= 60, sunexizei to fortwma
                    rf_we <= 1;//write enable
                    rf_w <= load_counter >> 2;//write address = load_counter / 4
                    load_counter <= load_counter + 4;//aukshsh tou load_counter kata 4
                end else begin
                    rf_we <= 0;//write disable
                    loading_done <= 1;//fortwma oloklhrwthike
                    rf_r1 <= 4'd2; rf_r2 <= 4'd3;//shift_bias_1, shift_bias_2
                end
            end 
            else if (state == PRE_PROC) begin
                if(alu_z1 || alu_z2) begin 
                    total_zero <= 1;
                    zero_fsm_stage <= PRE_PROC; 
                end
                inter_1 <= alu_out1;
                inter_2 <= alu_out2;
                rf_r1 <= 4'd4; rf_r2 <= 4'd5; rf_r3 <= 4'd6; rf_r4 <= 4'd7;
                //weight_1, bias_1, weight_2, bias_2
            end 
            else if (state == INPUT_LAYER) begin
                if (m1_om || m1_oa || m2_om || m2_oa) begin
                    total_ovf <= 1;
                    ovf_fsm_stage <= INPUT_LAYER;
                end else begin
                    if(m1_zm || m1_za || m2_zm || m2_za) begin 
                        total_zero <= 1;
                        zero_fsm_stage <= INPUT_LAYER; 
                    end
                    inter_3 <= m1_res;
                    inter_4 <= m2_res;
                    rf_r1 <= 4'd8; rf_r2 <= 4'd9; rf_r3 <= 4'd10;
                    //weight_3, weight_4, bias_3
                end
            end 
            else if (state == OUTPUT_LAYER) begin
                if (alu_ovf1 || m1_om || m1_oa || m2_om || m2_oa) begin
                    total_ovf <= 1;
                    ovf_fsm_stage <= OUTPUT_LAYER;
                end else begin
                    if(alu_z1 || m1_zm || m1_za || m2_zm || m2_za) begin 
                        total_zero <= 1;
                        zero_fsm_stage <= OUTPUT_LAYER; 
                    end
                    inter_5 <= alu_out1;
                    rf_r1 <= 4'd11;//shift_bias_3
                end
            end 
            else if (state == POST_PROC) begin
                if (alu_ovf1 || total_ovf) begin
                    total_ovf <= 1;
                    ovf_fsm_stage <= POST_PROC;
                    final_output <= 32'hffffffff;//if ovf set result the max neg value
                end else begin
                    if (alu_z1) begin 
                        total_zero <= 1;
                        zero_fsm_stage <= POST_PROC; 
                    end
                    final_output <= alu_out1;
                end
            end 
        end
    end
endmodule
`endif