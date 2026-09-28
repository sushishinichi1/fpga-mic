`timescale 1ns / 1ps
`default_nettype none

module dot_product_accel_tb;
    reg clk;
    reg reset;
    reg start;
    reg clear;
    reg [15:0] vector_length;
    wire fifo_read_enable;
    wire [31:0] fifo_read_data;
    wire fifo_empty;
    wire fifo_full;
    wire [4:0] fifo_count;
    wire fifo_overflow;
    wire fifo_underflow;
    wire busy;
    wire done;
    wire error;
    wire signed [31:0] result;
    wire [31:0] cycle_count;

    reg fifo_reset;
    reg fifo_write_enable;
    reg [31:0] fifo_write_data;

    sync_fifo #(
        .DATA_WIDTH(32),
        .DEPTH(16)
    ) input_fifo (
        .clk(clk),
        .reset(fifo_reset),
        .write_enable(fifo_write_enable),
        .write_data(fifo_write_data),
        .read_enable(fifo_read_enable),
        .read_data(fifo_read_data),
        .full(fifo_full),
        .empty(fifo_empty),
        .count(fifo_count),
        .overflow(fifo_overflow),
        .underflow(fifo_underflow)
    );

    dot_product_accel dut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .clear(clear),
        .vector_length(vector_length),
        .fifo_read_enable(fifo_read_enable),
        .fifo_read_data(fifo_read_data),
        .fifo_empty(fifo_empty),
        .fifo_count(fifo_count),
        .busy(busy),
        .done(done),
        .error(error),
        .result(result),
        .cycle_count(cycle_count)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("build/sim/dot_product_accel_tb.vcd");
        $dumpvars(0, dot_product_accel_tb);
    end

    initial begin
        #1000000;
        $display("FAIL: dot_product_accel_tb simulation timeout");
        $fatal;
    end

    initial begin
        reset = 1'b0;
        start = 1'b0;
        clear = 1'b0;
        vector_length = 16'd0;
        fifo_reset = 1'b0;
        fifo_write_enable = 1'b0;
        fifo_write_data = 32'd0;

        reset_all;
        run_case_basic;
        run_case_negative;
        run_case_int8_limits;
        run_case_length_one;
        run_case_length_sixteen;
        run_case_fifo_shortage;
        run_case_clear;
        run_case_start_while_busy;

        $display("PASS: dot_product_accel_tb");
        $finish;
    end

    function [31:0] pack_word;
        input integer input_value;
        input integer weight_value;
        begin
            pack_word = {16'd0, weight_value[7:0], input_value[7:0]};
        end
    endfunction

    task reset_all;
        begin
            @(negedge clk);
            reset = 1'b1;
            fifo_reset = 1'b1;
            start = 1'b0;
            clear = 1'b0;
            fifo_write_enable = 1'b0;
            fifo_write_data = 32'd0;
            vector_length = 16'd0;
            @(negedge clk);
            reset = 1'b0;
            fifo_reset = 1'b0;
            @(negedge clk);
        end
    endtask

    task clear_accel_and_fifo;
        begin
            @(negedge clk);
            clear = 1'b1;
            fifo_reset = 1'b1;
            start = 1'b0;
            fifo_write_enable = 1'b0;
            @(negedge clk);
            clear = 1'b0;
            fifo_reset = 1'b0;
            @(negedge clk);
        end
    endtask

    task write_fifo_word;
        input [31:0] value;
        begin
            @(negedge clk);
            fifo_write_data = value;
            fifo_write_enable = 1'b1;
            @(negedge clk);
            fifo_write_enable = 1'b0;
            fifo_write_data = 32'd0;
        end
    endtask

    task pulse_start;
        begin
            @(negedge clk);
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;
        end
    endtask

    task wait_for_done_or_error;
        integer wait_cycles;
        begin
            wait_cycles = 0;
            while (!done && !error && wait_cycles < 200) begin
                @(negedge clk);
                wait_cycles = wait_cycles + 1;
            end
            if (wait_cycles >= 200) begin
                $display("FAIL: accelerator timed out");
                $fatal;
            end
            if (busy) begin
                while (busy && wait_cycles < 200) begin
                    @(negedge clk);
                    wait_cycles = wait_cycles + 1;
                end
            end
            if (wait_cycles >= 200) begin
                $display("FAIL: accelerator stayed busy");
                $fatal;
            end
        end
    endtask

    task expect_done_held;
        integer hold_count;
        begin
            for (hold_count = 0; hold_count < 5; hold_count = hold_count + 1) begin
                @(negedge clk);
                if (done !== 1'b1 || busy !== 1'b0) begin
                    $display("FAIL: done did not hold cleanly at hold clock %0d", hold_count + 1);
                    $fatal;
                end
            end
        end
    endtask

    task run_vector_case;
        input [8*32-1:0] case_name;
        input integer length;
        input signed [31:0] expected;
        input [31:0] expected_cycles;
        integer index;
        begin
            clear_accel_and_fifo;
            vector_length = length[15:0];

            if (case_name == "basic") begin
                write_fifo_word(pack_word(1, 5));
                write_fifo_word(pack_word(2, 6));
                write_fifo_word(pack_word(3, 7));
                write_fifo_word(pack_word(4, 8));
            end else if (case_name == "negative") begin
                write_fifo_word(pack_word(-1, 5));
                write_fifo_word(pack_word(2, -6));
                write_fifo_word(pack_word(-3, 7));
                write_fifo_word(pack_word(4, -8));
            end else if (case_name == "limits") begin
                write_fifo_word(pack_word(127, 127));
                write_fifo_word(pack_word(-128, -128));
            end else if (case_name == "length_one") begin
                write_fifo_word(pack_word(-128, 127));
            end else if (case_name == "length_sixteen") begin
                for (index = 0; index < 16; index = index + 1) begin
                    write_fifo_word(pack_word(index - 8, 1));
                end
            end

            if (fifo_count !== length[4:0]) begin
                $display("FAIL: %0s fifo_count expected %0d got %0d", case_name, length, fifo_count);
                $fatal;
            end

            pulse_start;
            wait_for_done_or_error;

            if (error !== 1'b0) begin
                $display("FAIL: %0s raised error", case_name);
                $fatal;
            end
            if (done !== 1'b1) begin
                $display("FAIL: %0s did not assert done", case_name);
                $fatal;
            end
            if (result !== expected) begin
                $display("FAIL: %0s result expected %0d got %0d", case_name, expected, result);
                $fatal;
            end
            if (cycle_count !== expected_cycles) begin
                $display("FAIL: %0s cycles expected %0d got %0d", case_name, expected_cycles, cycle_count);
                $fatal;
            end
            if (fifo_empty !== 1'b1 || fifo_count !== 5'd0) begin
                $display("FAIL: %0s did not consume all FIFO words", case_name);
                $fatal;
            end

            expect_done_held;
        end
    endtask

    task run_case_basic;
        begin
            run_vector_case("basic", 4, 32'sd70, 32'd8);
        end
    endtask

    task run_case_negative;
        begin
            run_vector_case("negative", 4, -32'sd70, 32'd8);
        end
    endtask

    task run_case_int8_limits;
        begin
            run_vector_case("limits", 2, 32'sd32513, 32'd4);
        end
    endtask

    task run_case_length_one;
        begin
            run_vector_case("length_one", 1, -32'sd16256, 32'd2);
        end
    endtask

    task run_case_length_sixteen;
        begin
            run_vector_case("length_sixteen", 16, -32'sd8, 32'd32);
        end
    endtask

    task run_case_fifo_shortage;
        begin
            clear_accel_and_fifo;
            vector_length = 16'd4;
            write_fifo_word(pack_word(1, 1));
            write_fifo_word(pack_word(2, 1));
            pulse_start;
            wait_for_done_or_error;

            if (error !== 1'b1 || busy !== 1'b0 || done !== 1'b0) begin
                $display("FAIL: FIFO shortage did not raise error and stop cleanly");
                $fatal;
            end
        end
    endtask

    task run_case_clear;
        begin
            run_vector_case("basic", 4, 32'sd70, 32'd8);
            @(negedge clk);
            clear = 1'b1;
            @(negedge clk);
            clear = 1'b0;
            @(negedge clk);

            if (busy !== 1'b0 || done !== 1'b0 || error !== 1'b0 ||
                result !== 32'sd0 || cycle_count !== 32'd0) begin
                $display("FAIL: clear did not reset accelerator state");
                $fatal;
            end

            write_fifo_word(pack_word(1, 5));
            write_fifo_word(pack_word(2, 6));
            write_fifo_word(pack_word(3, 7));
            write_fifo_word(pack_word(4, 8));
            vector_length = 16'd4;
            pulse_start;
            if (done !== 1'b0) begin
                $display("FAIL: next START did not clear done");
                $fatal;
            end
            wait_for_done_or_error;
            if (error !== 1'b0 || done !== 1'b1 || result !== 32'sd70) begin
                $display("FAIL: run after clear did not complete cleanly");
                $fatal;
            end
        end
    endtask

    task run_case_start_while_busy;
        integer wait_cycles;
        begin
            clear_accel_and_fifo;
            vector_length = 16'd4;
            write_fifo_word(pack_word(1, 5));
            write_fifo_word(pack_word(2, 6));
            write_fifo_word(pack_word(3, 7));
            write_fifo_word(pack_word(4, 8));

            pulse_start;
            wait_cycles = 0;
            while (!busy && wait_cycles < 20) begin
                @(negedge clk);
                wait_cycles = wait_cycles + 1;
            end
            if (!busy) begin
                $display("FAIL: accelerator did not enter busy before restart test");
                $fatal;
            end

            pulse_start;
            wait_for_done_or_error;

            if (error !== 1'b1 || busy !== 1'b0 || done !== 1'b1 ||
                result !== 32'sd70 || fifo_empty !== 1'b1) begin
                $display("FAIL: START while busy did not latch error and finish current operation");
                $fatal;
            end
        end
    endtask
endmodule

`default_nettype wire
