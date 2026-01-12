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

    // Ορισμός Καταστάσεων (Σύμφωνα με την εκφώνηση - 7 στάδια)
    localparam DEACTIVATED = 3'b000;
    localparam LOADING     = 3'b001;
    localparam PRE_PROC    = 3'b010;
    localparam INPUT_LAYER = 3'b011;
    localparam OUTPUT_LAYER= 3'b100;
    localparam POST_PROC   = 3'b101;
    localparam IDLE        = 3'b110;

    reg [2:0] state;
    reg loading_done;
    reg [7:0] load_counter;

    // Ενδιάμεσοι καταχωρητές
    reg [SIZE-1:0] inter_1, inter_2, inter_3, inter_4, inter_5;

    // Σήματα για το Register File
    reg [3:0] rf_r1, rf_r2, rf_r3, rf_r4, rf_w1;
    reg [SIZE-1:0] rf_wd1;
    reg rf_we;
    wire [SIZE-1:0] rf_d1, rf_d2, rf_d3, rf_d4;

    // Σήματα για τις ALU και MAC
    reg [SIZE-1:0] alu_in1, alu_in2;
    reg [3:0] alu_ctrl;
    wire [SIZE-1:0] alu_out;
    wire alu_ovf, alu_z;

    reg [SIZE-1:0] m1_op1, m1_op2, m1_op3;
    wire [SIZE-1:0] m1_res;
    wire m1_om, m1_oa, m1_zm, m1_za;

    reg [SIZE-1:0] m2_op1, m2_op2, m2_op3;
    wire [SIZE-1:0] m2_res;
    wire m2_om, m2_oa, m2_zm, m2_za;

    // --- INSTANTIATIONS (Μία φορά, εκτός always) ---
    
    regfile RF (
        .clk(clk), .resetn(resetn),
        .readReg1(rf_r1), .readReg2(rf_r2), .readReg3(rf_r3), .readReg4(rf_r4),
        .writeReg1(rf_w1), .writeData1(rf_wd1), .write(rf_we),
        .readData1(rf_d1), .readData2(rf_d2), .readData3(rf_d3), .readData4(rf_d4)
    );

    alu ALU_UNIT (
        .op1(alu_in1), .op2(alu_in2), .alu_op(alu_ctrl),
        .result(alu_out), .ovf(alu_ovf), .zero(alu_z)
    );

    mac_unit MAC1 (
        .op1(m1_op1), .op2(m1_op2), .op3(m1_op3),
        .total_result(m1_res), .zero_mul(m1_zm), .zero_add(m1_za), .ovf_mul(m1_om), .ovf_add(m1_oa)
    );

    mac_unit MAC2 (
        .op1(m2_op1), .op2(m2_op2), .op3(m2_op3),
        .total_result(m2_res), .zero_mul(m2_zm), .zero_add(m2_za), .ovf_mul(m2_om), .ovf_add(m2_oa)
    );

    wire [SIZE-1:0] rom_d1;
    WEIGHT_BIAS_MEMORY ROM (.clk(clk), .addr1(load_counter), .dout1(rom_d1));

    // --- ΚΥΡΙΑ ΜΗΧΑΝΗ ΚΑΤΑΣΤΑΣΕΩΝ ---
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state <= DEACTIVATED;
            loading_done <= 0;
            load_counter <= 0;
            total_ovf <= 0;
            ovf_fsm_stage <= 3'b111;
            zero_fsm_stage <= 3'b111;
        end else begin
            case (state)
                DEACTIVATED: if (enable) state <= loading_done ? PRE_PROC : LOADING;

                LOADING: begin
                    if (load_counter <= 8'd68) begin // 17 παράμετροι * 4 bytes = 68
                        rf_we <= 1;
                        rf_w1 <= load_counter >> 2; // Μετατροπή byte address σε word address
                        rf_wd1 <= rom_d1;
                        load_counter <= load_counter + 4;
                    end else begin
                        rf_we <= 0;
                        loading_done <= 1;
                        state <= PRE_PROC;
                    end
                end

                PRE_PROC: begin
                    // Διάβασμα shift biases
                    rf_r1 <= 4'h2; rf_r2 <= 4'h3;
                    // Πράξη ALU
                    alu_in1 <= input_1; alu_in2 <= rf_d1; alu_ctrl <= 4'b0010; // SRA
                    inter_1 <= alu_out;
                    // Εδώ πρέπει να κάνεις το ίδιο για το input_2 (ίσως χρειαστείς 2ο κύκλο)
                    
                    if (alu_ovf) begin 
                        state <= IDLE; total_ovf <= 1; ovf_fsm_stage <= PRE_PROC; 
                    end else state <= INPUT_LAYER;
                end

                INPUT_LAYER: begin
                    // Φόρτωση βαρών/πολώσεων (Διευθύνσεις 0x4-0x7)
                    rf_r1 <= 4'h4; rf_r2 <= 4'h5; rf_r3 <= 4'h6; rf_r4 <= 4'h7;
                    m1_op1 <= inter_1; m1_op2 <= rf_d1; m1_op3 <= rf_d2;
                    m2_op1 <= inter_2; m2_op2 <= rf_d3; m2_op3 <= rf_d4;
                    
                    inter_3 <= m1_res; inter_4 <= m2_res;

                    if (m1_om || m1_oa || m2_om || m2_oa) begin
                        state <= IDLE; total_ovf <= 1; ovf_fsm_stage <= INPUT_LAYER;
                    end else state <= OUTPUT_LAYER;
                end

                OUTPUT_LAYER: begin
                    // Διευθύνσεις 0x8, 0x9, 0xA
                    rf_r1 <= 4'h8; rf_r2 <= 4'h9; rf_r3 <= 4'h10;
                    // inter_5 = inter_3*w3 + inter_4*w4 + b3
                    m1_op1 <= inter_3; m1_op2 <= rf_d1; m1_op3 <= 0;
                    m2_op1 <= inter_4; m2_op2 <= rf_d2; m2_op3 <= rf_d3;
                    
                    alu_in1 <= m1_res; alu_in2 <= m2_res; alu_ctrl <= 4'b0100; // ADD
                    inter_5 <= alu_out;

                    if (alu_ovf) begin
                         state <= IDLE; total_ovf <= 1; ovf_fsm_stage <= OUTPUT_LAYER;
                    end else state <= POST_PROC;
                end

                POST_PROC: begin
                    rf_r1 <= 4'h11; // shift_bias_3
                    alu_in1 <= inter_5; alu_in2 <= rf_d1; alu_ctrl <= 4'b0001; // SLL
                    final_output <= alu_out;
                    state <= IDLE;
                end

                IDLE: begin
                    if (total_ovf) final_output <= 32'h7FFFFFFF;
                    if (enable) state <= PRE_PROC;
                end
            endcase
        end
    end
endmodule

/*Τι απομένει να κάνεις εσύ:

Zero Detection: Πρόσθεσε μέσα σε κάθε στάδιο ένα if (alu_z || m1_zm ...) 
    για να ενημερώνεις το total_zero και το zero_fsm_stage.
    Timing στο Pre-proc: Επειδή έχεις μόνο μία ALU, για να κάνεις ολίσθηση και στο input_1 και στο input_2,
     θα χρειαστείς είτε 2 κύκλους στο στάδιο PRE_PROC είτε να ορίσεις και δεύτερη ALU (ALU_UNIT2).
    ROM Addresses: Βεβαιώσου ότι η ROM σου διαβάζει σωστά (η WEIGHT_BIAS_MEMORY που ανέβασες διαβάζει 4 bytes ταυτόχρονα,
     οπότε ο μετρητής πρέπει να πηδάει ανά 4).*/