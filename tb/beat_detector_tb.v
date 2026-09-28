`timescale 1ns/1ps
`default_nettype none

module beat_detector_tb;

    reg clk;
    reg reset;
    reg frame_valid;
    reg [38:0] beat_energy;
    wire beat_pulse;
    wire [15:0] beat_count;
    integer index;
    integer count_before;

    beat_detector #(
        .BASELINE_SHIFT(5),
        .WARMUP_FRAMES(4),
        .REFRACTORY_FRAMES(3)
    ) dut (
        .clk(clk), .reset(reset), .frame_valid(frame_valid),
        .beat_energy(beat_energy), .beat_pulse(beat_pulse),
        .beat_count(beat_count)
    );

    always #5 clk = ~clk;

    task send_frame;
        input [38:0] energy;
        output pulse_seen;
        begin
            @(negedge clk);
            beat_energy = energy;
            frame_valid = 1'b1;
            @(posedge clk);
            #1 pulse_seen = beat_pulse;
            @(negedge clk);
            frame_valid = 1'b0;
        end
    endtask

    task apply_reset;
        begin
            @(negedge clk);
            reset = 1'b1;
            @(posedge clk);
            @(negedge clk);
            reset = 1'b0;
        end
    endtask

    reg pulse_seen;

    initial begin
        clk = 1'b0;
        reset = 1'b0;
        frame_valid = 1'b0;
        beat_energy = 39'd0;

        // A: Constant energy must not create a beat after warmup.
        apply_reset();
        for (index = 0; index < 7; index = index + 1) begin
            send_frame(39'd1000, pulse_seen);
            if (pulse_seen) begin
                $display("FAIL A: constant energy generated a beat at frame %0d", index);
                $fatal;
            end
        end
        if (beat_count != 16'd0) begin
            $display("FAIL A: beat_count=%0d expected 0", beat_count);
            $fatal;
        end

        // B: A large rising burst after warmup creates exactly one beat.
        send_frame(39'd10000, pulse_seen);
        if (!pulse_seen || (beat_count != 16'd1)) begin
            $display("FAIL B: pulse=%0d count=%0d expected pulse=1 count=1",
                     pulse_seen, beat_count);
            $fatal;
        end

        // C: A second onset during refractory is rejected.
        send_frame(39'd1000, pulse_seen);
        send_frame(39'd10000, pulse_seen);
        if (pulse_seen || (beat_count != 16'd1)) begin
            $display("FAIL C: refractory burst changed count to %0d", beat_count);
            $fatal;
        end

        // D: A new onset after refractory is detected.
        for (index = 0; index < 4; index = index + 1)
            send_frame(39'd1000, pulse_seen);
        send_frame(39'd10000, pulse_seen);
        if (!pulse_seen || (beat_count != 16'd2)) begin
            $display("FAIL D: pulse=%0d count=%0d expected pulse=1 count=2",
                     pulse_seen, beat_count);
            $fatal;
        end

        // E: Remaining above threshold only triggers on the first frame.
        for (index = 0; index < 4; index = index + 1)
            send_frame(39'd1000, pulse_seen);
        count_before = beat_count;
        send_frame(39'd12000, pulse_seen);
        if (!pulse_seen)
            $fatal(1, "FAIL E: first above-threshold frame had no pulse");
        send_frame(39'd12000, pulse_seen);
        if (pulse_seen)
            $fatal(1, "FAIL E: sustained burst generated a second pulse");
        send_frame(39'd12000, pulse_seen);
        if (pulse_seen || (beat_count != count_before + 1)) begin
            $display("FAIL E: sustained burst count=%0d expected %0d",
                     beat_count, count_before + 1);
            $fatal;
        end

        // F: A slowly rising background is followed by the EMA without beats.
        apply_reset();
        for (index = 0; index < 24; index = index + 1) begin
            send_frame(39'd1000 + (index * 39'd20), pulse_seen);
            if (pulse_seen)
                $fatal(1, "FAIL F: gradual background generated a beat");
        end
        if ((beat_count != 16'd0) || (dut.baseline <= 39'd1000)) begin
            $display("FAIL F: count=%0d baseline=%0d", beat_count, dut.baseline);
            $fatal;
        end

        $display("PASS: beat_detector_tb baseline=%0d count=%0d",
                 dut.baseline, beat_count);
        $finish;
    end

endmodule

`default_nettype wire
