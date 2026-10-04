`timescale 1ns/1ps

module fifo_tb;

    parameter WIDTH = 8;
    parameter DEPTH = 4;

    logic clk;
    logic rst_n;

    logic write_enable;
    logic [WIDTH-1:0] write_data;

    logic read_enable;
    logic [WIDTH-1:0] read_data;

    logic full;
    logic empty;

    integer tests_run;
    integer failures;
    integer i;

    fifo #(
        .WIDTH(WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .write_enable(write_enable),
        .write_data(write_data),
        .read_enable(read_enable),
        .read_data(read_data),
        .full(full),
        .empty(empty)
    );

    // 100 MHz clock
    always #5 clk = ~clk;

    task check_flags(
        input logic expected_empty,
        input logic expected_full,
        input string test_name
    );
        begin
            tests_run = tests_run + 1;

            if (
                empty === expected_empty &&
                full === expected_full
            ) begin
                $display("TEST_PASS | fifo | %s", test_name);
            end
            else begin
                failures = failures + 1;

                $display(
                    "TEST_FAIL | fifo | %s | expected_empty=%0b actual_empty=%0b expected_full=%0b actual_full=%0b",
                    test_name,
                    expected_empty,
                    empty,
                    expected_full,
                    full
                );
            end
        end
    endtask

    task check_data(
        input logic [WIDTH-1:0] expected_data,
        input string test_name
    );
        begin
            tests_run = tests_run + 1;

            if (read_data === expected_data) begin
                $display("TEST_PASS | fifo | %s", test_name);
            end
            else begin
                failures = failures + 1;

                $display(
                    "TEST_FAIL | fifo | %s | expected_data=%0d actual_data=%0d",
                    test_name,
                    expected_data,
                    read_data
                );
            end
        end
    endtask

    task reset_fifo;
        begin
            rst_n        = 0;
            write_enable = 0;
            read_enable  = 0;

            @(posedge clk);
            #1;

            @(negedge clk);
            rst_n = 1;
        end
    endtask

    task write_value(
        input logic [WIDTH-1:0] value
    );
        begin
            @(negedge clk);
            write_data   = value;
            write_enable = 1;

            @(posedge clk);
            #1;

            @(negedge clk);
            write_enable = 0;
        end
    endtask

    task read_and_check(
        input logic [WIDTH-1:0] expected_data,
        input string test_name
    );
        begin
            @(negedge clk);
            read_enable = 1;

            @(posedge clk);
            #1;
            check_data(expected_data, test_name);

            @(negedge clk);
            read_enable = 0;
        end
    endtask

    task read_empty_and_check(
        input logic [WIDTH-1:0] expected_held_data,
        input string test_name
    );
        begin
            @(negedge clk);
            read_enable = 1;

            @(posedge clk);
            #1;
            check_data(expected_held_data, test_name);

            @(negedge clk);
            read_enable = 0;
        end
    endtask

    initial begin
        clk          = 0;
        rst_n        = 1;
        write_enable = 0;
        write_data   = '0;
        read_enable  = 0;
        tests_run    = 0;
        failures     = 0;

        // Test reset state
        reset_fifo();
        check_flags(1, 0, "reset_empty");

        // Write and read one value
        write_value(10);
        check_flags(0, 0, "single_write_nonempty");

        read_and_check(10, "single_value_read");
        check_flags(1, 0, "empty_after_single_read");

        // Attempt to read while empty.
        // read_data should hold its previous value of 10.
        read_empty_and_check(10, "underflow_blocked");

        // Reset before the full and ordering tests
        reset_fifo();

        // Fill every FIFO location
        for (i = 0; i < DEPTH; i = i + 1) begin
            write_value(i + 20);
        end

        check_flags(0, 1, "full_after_depth_writes");

        // Attempt to write while full
        write_value(99);
        check_flags(0, 1, "overflow_blocked");

        // Confirm that values leave in the original order
        for (i = 0; i < DEPTH; i = i + 1) begin
            read_and_check(
                i + 20,
                $sformatf("fifo_order_%0d", i)
            );
        end

        check_flags(1, 0, "empty_after_complete_read");

        // Test simultaneous read and write
        write_value(55);

        @(negedge clk);
        write_enable = 1;
        write_data   = 66;
        read_enable  = 1;

        @(posedge clk);
        #1;

        check_data(55, "simultaneous_read_oldest_value");
        check_flags(0, 0, "simultaneous_count_unchanged");

        @(negedge clk);
        write_enable = 0;
        read_enable  = 0;

        read_and_check(66, "simultaneous_write_preserved");
        check_flags(1, 0, "final_empty_state");

        $display(
            "TEST_SUMMARY | fifo | total=%0d passed=%0d failed=%0d",
            tests_run,
            tests_run - failures,
            failures
        );

        if (failures > 0)
            $fatal(1, "FIFO REGRESSION FAILED");
        else
            $finish;
    end

endmodule