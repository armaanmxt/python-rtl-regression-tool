`timescale 1ns/1ps

module alu_tb;

    parameter WIDTH = 8;

    logic [WIDTH-1:0] a;
    logic [WIDTH-1:0] b;
    logic [1:0] operation;
                                                  //these are all physical wire names that are the exact same as the DUT
    logic [WIDTH-1:0] result;                     //we could lit name these anything, it doesnt matter
    logic overflow;

    integer tests_run;                        //counts how many tests ran and how many failures, just keeps count
    integer failures;

    localparam logic [WIDTH-1:0] MAX_VALUE = {WIDTH{1'b1}};      //creates a value containing max possible width

    alu #(
        .WIDTH(WIDTH)
    ) dut (
        .a(a),
        .b(b),
        .operation(operation),                  //these are all now instantiating the DUT
        .result(result),                        //this means "take the ALU pin named "result" and plug our testbench wire "result" to it""
        .overflow(overflow)
    );

    task run_test(                        //task is just reusable code
        input logic [WIDTH-1:0] test_a,          
        input logic [WIDTH-1:0] test_b,
        input logic [1:0] test_operation,             //each time "run test" task is ran, we give it        
        input logic [WIDTH-1:0] expected_result,
        input logic expected_overflow,
        input string test_name
    );
        begin
            a         = test_a;
            b         = test_b;
            operation = test_operation;

            // Allow combinational outputs to update
            #1;

            tests_run = tests_run + 1;

            if (
                result === expected_result &&
                overflow === expected_overflow
            ) begin
                $display("TEST_PASS | alu | %s", test_name);
            end
            else begin
                failures = failures + 1;

                $display(
                    "TEST_FAIL | alu | %s | expected_result=%0d actual_result=%0d expected_overflow=%0b actual_overflow=%0b",
                    test_name,
                    expected_result,
                    result,
                    expected_overflow,
                    overflow
                );
            end
        end
    endtask

    initial begin
        a         = '0;
        b         = '0;
        operation = '0;
        tests_run = 0;
        failures  = 0;

        // Addition tests
        run_test(5, 3, 2'b00, 8, 0, "basic_addition");
        run_test(0, 0, 2'b00, 0, 0, "zero_addition");

        run_test(
            MAX_VALUE,
            1,
            2'b00,
            0,
            1,
            "addition_overflow"
        );

        run_test(
            MAX_VALUE,
            MAX_VALUE,
            2'b00,
            MAX_VALUE - 1'b1,
            1,
            "maximum_value_addition"
        );

        // Subtraction tests
        run_test(9, 4, 2'b01, 5, 0, "basic_subtraction");
        run_test(7, 7, 2'b01, 0, 0, "equal_subtraction");

        // Logic tests
        run_test(12, 10, 2'b10, 8, 0, "bitwise_and");
        run_test(12, 10, 2'b11, 14, 0, "bitwise_or");

        $display(
            "TEST_SUMMARY | alu | total=%0d passed=%0d failed=%0d",
            tests_run,
            tests_run - failures,
            failures
        );

        if (failures > 0)
            $fatal(1, "ALU REGRESSION FAILED");
        else
            $finish;
    end

endmodule