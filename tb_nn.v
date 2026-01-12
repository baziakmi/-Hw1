`timescale 1ns/1ps

// Συμπερίληψη των απαραίτητων αρχείων
`include "nn.v"
`include "nn_model.v"

module tb_nn();
    // Παράμετροι
    parameter SIZE = 32;
    parameter CLK_PERIOD = 10; 

    // Σήματα για το Unit Under Test (UUT)
    reg [SIZE-1:0] input_1;
    reg [SIZE-1:0] input_2;
    reg clk;
    reg resetn;
    reg enable;
    
    wire [SIZE-1:0] final_output;
    wire total_ovf;
    wire total_zero;
    wire [2:0] ovf_fsm_stage;
    wire [2:0] zero_fsm_stage;

    // Μεταβλητές ελέγχου
    reg [SIZE-1:0] ref_output;
    integer pass_count = 0;
    integer total_tests = 0;
    integer i;
    
    // Όρια για signed 32-bit
    reg signed [31:0] max_pos = 32'sh7FFFFFFF;
    reg signed [31:0] max_neg = 32'sh80000000;

    // Instance του Neural Network
    nn #(SIZE) uut (
        .input_1(input_1),
        .input_2(input_2),
        .clk(clk),
        .resetn(resetn),
        .enable(enable),
        .final_output(final_output),
        .total_ovf(total_ovf),
        .total_zero(total_zero),
        .ovf_fsm_stage(ovf_fsm_stage),
        .zero_fsm_stage(zero_fsm_stage)
    );

    // Δημιουργία Ρολογιού
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // Κύριο simulation block
    initial begin
        input_1 = 0; input_2 = 0;
        enable = 0; resetn = 0;
        
        #(CLK_PERIOD * 2);
        resetn = 1;
        #(CLK_PERIOD * 2);

        $display("Starting Neural Network Testbench...");

        for (i = 0; i < 100; i = i + 1) begin
            // TEST 1: Μικρές τυχαίες τιμές
            run_test($urandom_range(4095, 0) - 2048, $urandom_range(4095, 0) - 2048);

            // TEST 2: Πιθανή θετική υπερχείλιση
            //run_test($urandom_range(max_pos, max_pos/2), $urandom_range(max_pos, max_pos/2));

            // TEST 3: Πιθανή αρνητική υπερχείλιση
            //run_test($signed($urandom_range(max_neg/2, max_neg)), $signed($urandom_range(max_neg/2, max_neg)));
        end

        $display("\nSimulation Finished!");
        $display("Results: %0d PASS / %0d total", pass_count, total_tests);
        $finish;
    end

    // Task για την εκτέλεση του τεστ
    task run_test(input signed [31:0] in1, input signed [31:0] in2);
        begin
            // 1. Hard Reset πριν από κάθε δείγμα
            resetn = 0;
            enable = 0;
            #(CLK_PERIOD * 2);
            resetn = 1;
            #(CLK_PERIOD);

            // 2. Ανάθεση τιμών
            total_tests = total_tests + 1;
            input_1 = in1;
            input_2 = in2;
            enable = 1;
            
            ref_output = nn_model(in1, in2);
            
            // 3. Περίμενε την έναρξη (να φύγει από DEACTIVATED)
            wait(uut.state != 3'b000);
            enable = 0; // Το enable πρέπει να είναι παλμός

            // 4. Περίμενε τον τερματισμό στην IDLE
            wait(uut.state == 3'b110);
            #(CLK_PERIOD); 

            // 5. Έλεγχος αν υπήρξε υπερχείλιση
            if (total_ovf) begin
                if (ref_output === 32'hffffffff) 
                    pass_count = pass_count + 1;
                else
                    $display("MISMATCH OVF: Hardware reported OVF, Model didn't. In1=%d", in1);
            end else begin
                if (final_output === ref_output) begin
                    pass_count = pass_count + 1;
                end else begin
                    $display("FAIL: In1=%d, In2=%d | Got=%h, Exp=%h", $signed(in1), $signed(in2), final_output, ref_output);
                end
            end
        end
    endtask

endmodule