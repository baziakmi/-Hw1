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

    //Αν δεν υπαρχει μηδενισμός ή υπερχείλιση
    parameter NO_ZERO_OR_OVF = 3'b111;

    // ALU Operations
    parameter ALU_OP_SRA = 4'b0010;
    parameter ALU_OP_SLL = 4'b0001;
    parameter ALU_OP_ADD = 4'b0100;

    reg [2:0] state;// current FSM state
    reg [2:0] next_state;// next FSM state
    reg loading_done;// flag to indicate loading completion
    reg [7:0] load_counter;// counter for loading parameters from ROM

    // Ενδιάμεσοι καταχωρητές
    reg [SIZE-1:0] inter_1, inter_2, inter_3, inter_4, inter_5;// intermediate results

    // Σήματα για το Register File
    reg [3:0] rf_r1, rf_r2, rf_r3, rf_r4, rf_w1;// register read and write addresses
    reg [SIZE-1:0] rf_wd1;// register write data
    reg rf_we;// register write enable
    wire [SIZE-1:0] rf_d1, rf_d2, rf_d3, rf_d4;// register read data

    // Σήματα για τις ALU και MAC
    reg [SIZE-1:0] alu_in11, alu_in12, alu_in21, alu_in22;//alu inputs
    reg [3:0] alu_ctrl;//alu control operation
    wire [SIZE-1:0] alu_out1, alu_out2;// alu outputs
    wire alu_ovf1, alu_z1, alu_ovf2, alu_z2;//alu overflow and zero flags

    reg [SIZE-1:0] m1_op1, m1_op2, m1_op3;//mac1 inputs
    wire [SIZE-1:0] m1_res;// mac1 output
    wire m1_om, m1_oa, m1_zm, m1_za;// mac1 overflow and zero flags

    reg [SIZE-1:0] m2_op1, m2_op2, m2_op3;//mac2 inputs
    wire [SIZE-1:0] m2_res;// mac2 output
    wire m2_om, m2_oa, m2_zm, m2_za;// mac2 overflow and zero flags

    regfile #(.DATAWIDTH(SIZE)) RF (
        .clk(clk), .resetn(resetn),
        .readReg1(rf_r1), .readReg2(rf_r2), .readReg3(rf_r3), .readReg4(rf_r4),
        .writeReg1(rf_w1), .writeReg2(4'b0), .writeData1(rf_wd1), .writeData2(32'b0), .write(rf_we),
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

    wire [SIZE-1:0] rom_d1;
    WEIGHT_BIAS_MEMORY ROM (.clk(clk), .addr1(load_counter), .dout1(rom_d1));

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state <= DEACTIVATED;
            loading_done <= 0;
            load_counter <= 0;
            rf_we <= 0;
        end else begin
            state <= next_state;

            if(state == DEACTIVATED) begin
                if(enable) begin 
                    rf_r1 <= 4'd2; rf_r2 <= 4'd3;// Pre-fetch διευθύνσεις για PRE_PROC
                    total_ovf <= 0;
                    total_zero <= 0;
                    ovf_fsm_stage <= NO_ZERO_OR_OVF;
                    zero_fsm_stage <= NO_ZERO_OR_OVF; 
                    load_counter <= 0;
                end
            end else if (state == LOADING) begin
                if (load_counter <= 8'd60) begin // 16 παράμετροι * 4 bytes = 60 (0 έως 60)
                    rf_we <= 1;
                    rf_w1 <= load_counter >> 2; // διαιρεση με το 4
                    rf_wd1 <= rom_d1;
                    load_counter <= load_counter + 4;
                end else begin
                    rf_we <= 0;
                    loading_done <= 1;
                    // Pre-fetch διευθύνσεις για PRE_PROC
                    rf_r1 <= 4'd2; rf_r2 <= 4'd3;
                end
            end else if (state == PRE_PROC) begin
                // Διάβασμα shift biases (Έχουν ήδη ζητηθεί από το προηγούμενο στάδιο)
                // Πράξη ALU1
                alu_in11 <= input_1; 
                alu_in12 <= rf_d1; 
                alu_ctrl <= ALU_OP_SRA;
                inter_1 <= alu_out1;
                // Πράξη ALU2
                alu_in21 <= input_2; 
                alu_in22 <= rf_d2; 
                alu_ctrl <= ALU_OP_SRA;
                inter_2 <= alu_out2;
                // Pre-fetch για INPUT_LAYER: weight_1, bias_1, weight_2, bias_2
                rf_r1 <= 4'd4; rf_r2 <= 4'd5; rf_r3 <= 4'd6; rf_r4 <= 4'd7;
            end else if (state == INPUT_LAYER) begin
                // Οι διευθύνσεις 4,5,6,7 έχουν ήδη ζητηθεί
                m1_op1 <= inter_1; m1_op2 <= rf_d1; m1_op3 <= rf_d2;
                m2_op1 <= inter_2; m2_op2 <= rf_d3; m2_op3 <= rf_d4;
                
                inter_3 <= m1_res; inter_4 <= m2_res;

                // Pre-fetch για OUTPUT_LAYER: weight_3, weight_4, bias_3
                rf_r1 <= 4'd8; rf_r2 <= 4'd9; rf_r3 <= 4'd10;
            end else if (state == OUTPUT_LAYER) begin
                // weight_3, weight_4, bias_3 (Διευθύνσεις 8, 9, 10)
                m1_op1 <= inter_3; m1_op2 <= rf_d1; m1_op3 <= 0;// inter_3*w3 + 0
                m2_op1 <= inter_4; m2_op2 <= rf_d2; m2_op3 <= rf_d3;// inter_4*w4 + b3

                alu_in11 <= m1_res; alu_in12 <= m2_res; alu_ctrl <= ALU_OP_ADD;// inter_3*w3 + inter_4*w4 + b3
                inter_5 <= alu_out1;

                // Pre-fetch για POST_PROC: shift_bias_3
                rf_r1 <= 4'd11; 
            end else if (state == POST_PROC) begin
                // shift_bias_3 (Διεύθυνση 11)
                alu_in11 <= inter_5; alu_in12 <= rf_d1; alu_ctrl <= ALU_OP_SLL;
            end else if (state == IDLE) begin
                if (enable) begin 
                    // Ετοιμασία για επανεκκίνηση
                    rf_r1 <= 4'd2; rf_r2 <= 4'd3;
                end
            end
        end
    end
    
    always @(*) begin
        next_state = state;
        total_ovf = 0;
        total_zero = 0;
        ovf_fsm_stage = NO_ZERO_OR_OVF;
        zero_fsm_stage = NO_ZERO_OR_OVF;
        final_output = 0;

        case (state)
            DEACTIVATED: begin
                if (enable) begin 
                    next_state = loading_done ? PRE_PROC : LOADING;
                end
            end

            LOADING: begin
                if (load_counter <= 8'd60) begin
                    next_state = LOADING;
                end else begin
                    next_state = PRE_PROC;
                end
            end

            PRE_PROC: begin
                if (alu_ovf1 || alu_ovf2) begin
                    next_state = IDLE; total_ovf = 1; ovf_fsm_stage = PRE_PROC;
                end else begin
                    if(alu_z1 || alu_z2) begin total_zero = 1; zero_fsm_stage = PRE_PROC; end
                    next_state = INPUT_LAYER;
                end
            end

            INPUT_LAYER: begin
                if (m1_om || m1_oa || m2_om || m2_oa) begin
                    next_state = IDLE; total_ovf = 1; ovf_fsm_stage = INPUT_LAYER;
                end else begin
                    if(m1_zm || m1_za || m2_zm || m2_za) begin total_zero = 1; zero_fsm_stage = INPUT_LAYER; end
                    next_state = OUTPUT_LAYER;
                end
            end

            OUTPUT_LAYER: begin
                if (alu_ovf1 || m1_om || m1_oa || m2_om || m2_oa) begin
                    next_state = IDLE; total_ovf = 1; ovf_fsm_stage = OUTPUT_LAYER;
                end else begin
                    if(alu_z1 || m1_zm || m1_za || m2_zm || m2_za) begin total_zero = 1; zero_fsm_stage = OUTPUT_LAYER; end
                    next_state = POST_PROC;
                end
            end

            POST_PROC: begin
                if (alu_ovf1) begin
                        next_state = IDLE; total_ovf = 1; ovf_fsm_stage = POST_PROC;
                end else begin
                    if (alu_z1) begin
                        total_zero = 1; zero_fsm_stage = POST_PROC;
                    end
                    final_output = alu_out1;
                    next_state = IDLE;
                end
            end

            IDLE: begin
                if (total_ovf) begin
                    final_output = 32'hffffffff; // Επιβολή τιμής overflow για συμβατότητα με το μοντέλο
                end
                next_state = DEACTIVATED;
                if (enable) begin
                    next_state = PRE_PROC;
                end
            end
        endcase
    end
endmodule

`endif