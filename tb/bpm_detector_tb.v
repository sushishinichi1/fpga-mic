`timescale 1ns/1ps
`default_nettype none

module bpm_detector_tb;

    localparam integer TEST_CLK_HZ = 100000;
    localparam integer CLKS_PER_MS = TEST_CLK_HZ / 1000;

    reg clk;
    reg reset;
    reg beat_pulse;
    wire [15:0] bpm;
    wire bpm_valid;
    wire [15:0] interval_ms;

    bpm_detector #(
        .CLK_HZ(TEST_CLK_HZ)
    ) dut (
        .clk(clk), .reset(reset), .beat_pulse(beat_pulse),
        .bpm(bpm), .bpm_valid(bpm_valid), .interval_ms(interval_ms)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task reset_dut;
        begin
            @(negedge clk);
            reset = 1'b1;
            beat_pulse = 1'b0;
            repeat (3) @(negedge clk);
            reset = 1'b0;
        end
    endtask

    task send_beat;
        begin
            @(negedge clk);
            beat_pulse = 1'b1;
            @(negedge clk);
            beat_pulse = 1'b0;
        end
    endtask

    task wait_interval_and_beat;
        input integer milliseconds;
        begin
            repeat ((milliseconds * CLKS_PER_MS) - 1) @(posedge clk);
            send_beat;
        end
    endtask

    task check_single_interval;
        input integer milliseconds;
        input integer expected_bpm;
        begin
            reset_dut;
            send_beat;
            if (bpm_valid !== 1'b0) begin
                $display("FAIL: first beat asserted bpm_valid");
                $fatal;
            end
            wait_interval_and_beat(milliseconds);
            wait (bpm_valid);
            if ((bpm < expected_bpm - 2) || (bpm > expected_bpm + 2)) begin
                $display("FAIL: %0dms expected BPM %0d +/-2, actual %0d",
                         milliseconds, expected_bpm, bpm);
                $fatal;
            end
            if ((interval_ms < milliseconds - 1) ||
                (interval_ms > milliseconds + 1)) begin
                $display("FAIL: requested %0dms, measured %0dms",
                         milliseconds, interval_ms);
                $fatal;
            end
            $display("%0dms: interval=%0d BPM=%0d PASS",
                     milliseconds, interval_ms, bpm);
        end
    endtask

    task establish_120_bpm;
        begin
            reset_dut;
            send_beat;
            wait_interval_and_beat(500);
            wait (bpm_valid);
            if (bpm != 16'd120) begin
                $display("FAIL: setup BPM expected 120, actual %0d", bpm);
                $fatal;
            end
        end
    endtask

    integer smooth_index;
    integer smooth_intervals [0:3];

    initial begin
        reset = 1'b1;
        beat_pulse = 1'b0;
        smooth_intervals[0] = 495;
        smooth_intervals[1] = 505;
        smooth_intervals[2] = 498;
        smooth_intervals[3] = 502;

        reset_dut;
        send_beat;
        repeat (20 * CLKS_PER_MS) @(posedge clk);
        if (bpm_valid !== 1'b0) begin
            $display("FAIL: case A first beat must not produce BPM");
            $fatal;
        end
        $display("A first beat: BPM_VALID=0 PASS");

        check_single_interval(500, 120);
        check_single_interval(1000, 60);
        check_single_interval(400, 150);
        check_single_interval(750, 80);

        establish_120_bpm;
        wait_interval_and_beat(250);
        repeat (32) @(posedge clk);
        if ((bpm != 16'd120) || (interval_ms < 16'd249) ||
            (interval_ms > 16'd251)) begin
            $display("FAIL: short invalid interval changed BPM: interval=%0d BPM=%0d",
                     interval_ms, bpm);
            $fatal;
        end
        $display("250ms invalid: BPM held at %0d PASS", bpm);

        establish_120_bpm;
        wait_interval_and_beat(1600);
        repeat (32) @(posedge clk);
        if ((bpm != 16'd120) || (interval_ms < 16'd1599) ||
            (interval_ms > 16'd1601)) begin
            $display("FAIL: long invalid interval changed BPM: interval=%0d BPM=%0d",
                     interval_ms, bpm);
            $fatal;
        end
        $display("1600ms invalid: BPM held at %0d PASS", bpm);

        establish_120_bpm;
        for (smooth_index = 0; smooth_index < 4; smooth_index = smooth_index + 1) begin
            wait_interval_and_beat(smooth_intervals[smooth_index]);
            repeat (32) @(posedge clk);
        end
        if ((bpm < 16'd118) || (bpm > 16'd122)) begin
            $display("FAIL: smoothed BPM expected 120 +/-2, actual %0d", bpm);
            $fatal;
        end
        $display("495/505/498/502ms smoothing: BPM=%0d PASS", bpm);

        $display("PASS: bpm_detector_tb");
        $finish;
    end

    initial begin
        #20000000;
        $display("FAIL: bpm_detector_tb timed out");
        $fatal;
    end

endmodule

`default_nettype wire
