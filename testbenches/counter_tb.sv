`timescale 1ns/1ps

module counter_tb;                //has no ports

    parameter WIDTH = 4;

    logic clk;
    logic rst_n;
    logic enable;
    logic [WIDTH-1:0] count;

    integer tests_run;              //simulation variables used to track results
    integer failures;

    counter #(                     //now changing the testbench parameter changes the instantiated counter width too.
        .WIDTH(WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),            //This creates the counter being tested.
        .enable(enable),
        .count(count)
    );

    // Generate a clock that changes every 5 ns.
    always #5 clk = ~clk;                           //every 5 ns, the clock gets inverted

    task check_count(                            //reusable task checker
        input logic [WIDTH-1:0] expected,        //the task receives the correct counter value and the name printed in the report
        input string test_name 
    );
        begin
            tests_run = tests_run + 1;           //records than another test happened

            if (count === expected) begin                    //count is actual DUT output, expected is the 
                $display("TEST_PASS | counter | %s", test_name);
            end
            else begin
                failures = failures + 1;
                $display(
                    "TEST_FAIL | counter | %s | expected=%0d actual=%0d",
                    test_name,
                    expected,
                    count
                );
            end
        end
    endtask

    initial begin
        clk       = 0;
        rst_n     = 1;
        enable    = 0;
        tests_run = 0;
        failures  = 0;

        // Test 1: Reset
        rst_n = 0;
        @(posedge clk);
        #1;
        check_count(0, "reset");

        // Release reset
        @(negedge clk);
        rst_n = 1;

        // Test 2: Hold while disabled
        @(posedge clk);
        #1;
        check_count(0, "disabled_hold");

        // Test 3: Increment once
        @(negedge clk); 
        enable = 1;

        @(posedge clk);
        #1;
        check_count(1, "single_increment");

        // Test 4: Increment several times
        repeat (3) @(posedge clk);
        #1;
        check_count(4, "multiple_increments");

        // Test 5: Hold the current value
        @(negedge clk);
        enable = 0;

        repeat (2) @(posedge clk);
        #1;
        check_count(4, "hold_existing_value");

        // Reset before testing wraparound
        @(negedge clk);
        rst_n = 0;

        @(posedge clk);
        #1;

        @(negedge clk);
        rst_n  = 1;
        enable = 1;

        // Test 6: Count through every value and wrap to zero
        repeat (2 ** WIDTH) @(posedge clk);
        #1;
        check_count(0, "maximum_value_wraparound");

        $display(
            "TEST_SUMMARY | counter | total=%0d passed=%0d failed=%0d",
            tests_run,
            tests_run - failures,
            failures
        );

        if (failures > 0)
            $fatal(1, "COUNTER REGRESSION FAILED");
        else
            $finish;
    end

endmodule