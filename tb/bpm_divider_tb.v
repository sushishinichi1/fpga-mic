`timescale 1ns/1ps
`default_nettype none

module bpm_divider_tb;

    reg clk;
    reg reset;
    reg start;
    reg [15:0] dividend;
    reg [15:0] divisor;
    wire [15:0] quotient;
    wire busy;
    wire done;
    integer start_cycle;
    integer cycle_count;

    bpm_divider dut (
        .clk(clk), .reset(reset), .start(start),
        .dividend(dividend), .divisor(divisor),
        .quotient(quotient), .busy(busy), .done(done)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always @(posedge clk)
        cycle_count = cycle_count + 1;

    task check_division;
        input [15:0] test_divisor;
        input [15:0] expected;
        begin
            @(negedge clk);
            divisor = test_divisor;
            start = 1'b1;
            start_cycle = cycle_count;
            @(negedge clk);
            start = 1'b0;
            wait (done);
            if (quotient !== expected) begin
                $display("FAIL: 60000 / %0d expected %0d, actual %0d",
                         test_divisor, expected, quotient);
                $fatal;
            end
            if ((cycle_count - start_cycle) != 17) begin
                $display("FAIL: divider expected 17 start-to-done clocks, actual %0d",
                         cycle_count - start_cycle);
                $fatal;
            end
            $display("60000 / %0d = %0d (16 iterations, %0d start-to-done clocks) PASS",
                     test_divisor, quotient, cycle_count - start_cycle);
            @(negedge clk);
        end
    endtask

    initial begin
        reset = 1'b1;
        start = 1'b0;
        dividend = 16'd60000;
        divisor = 16'd1;
        cycle_count = 0;
        repeat (3) @(negedge clk);
        reset = 1'b0;

        check_division(16'd500, 16'd120);
        check_division(16'd1000, 16'd60);
        check_division(16'd400, 16'd150);
        check_division(16'd750, 16'd80);

        $display("PASS: bpm_divider_tb");
        $finish;
    end

endmodule

`default_nettype wire
