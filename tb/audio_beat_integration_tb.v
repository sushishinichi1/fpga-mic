`timescale 1ns/1ps
`default_nettype none

module audio_beat_integration_tb;

    localparam real PI = 3.14159265358979323846;
    localparam real SAMPLE_RATE = 35156.25;
    localparam real TONE_FREQUENCY = 274.658203125;

    reg clk;
    reg signed [23:0] sample;
    reg sample_valid;
    wire fft_busy;
    wire frame_valid;
    wire [7:0] peak_bin;
    wire [36:0] peak_power;
    wire [255:0] spectrum;
    wire [38:0] beat_energy;
    wire beat_pulse;
    wire [15:0] beat_count;
    integer pulse_count;

    audio_fft_analyzer fft_dut (
        .clk(clk), .sample(sample), .sample_valid(sample_valid),
        .busy(fft_busy), .peak_valid(frame_valid),
        .peak_bin(peak_bin), .peak_power(peak_power),
        .spectrum(spectrum), .beat_energy(beat_energy)
    );

    beat_detector #(
        .BASELINE_SHIFT(5),
        .WARMUP_FRAMES(4),
        .REFRACTORY_FRAMES(2)
    ) beat_dut (
        .clk(clk), .reset(1'b0), .frame_valid(frame_valid),
        .beat_energy(beat_energy), .beat_pulse(beat_pulse),
        .beat_count(beat_count)
    );

    always #18.5185 clk = ~clk;

    always @(posedge clk) begin
        if (beat_pulse)
            pulse_count = pulse_count + 1;
    end

    task send_fft_frame;
        input integer amplitude;
        integer sample_number;
        integer pcm_value;
        integer wait_clocks;
        begin
            while (fft_busy)
                @(posedge clk);

            for (sample_number = 0; sample_number < 256; sample_number = sample_number + 1) begin
                pcm_value = $rtoi(amplitude * $sin(
                    2.0 * PI * TONE_FREQUENCY * sample_number / SAMPLE_RATE
                ));
                @(negedge clk);
                sample = pcm_value * 64;
                sample_valid = 1'b1;
                @(negedge clk);
                sample_valid = 1'b0;
                repeat (3) @(posedge clk);
            end

            wait_clocks = 0;
            while (!frame_valid && (wait_clocks < 7000)) begin
                @(posedge clk);
                wait_clocks = wait_clocks + 1;
            end
            if (!frame_valid)
                $fatal(1, "FAIL: FFT frame timed out");
            repeat (2) @(posedge clk);
        end
    endtask

    initial begin
        clk = 1'b0;
        sample = 24'sd0;
        sample_valid = 1'b0;
        pulse_count = 0;
        repeat (4) @(posedge clk);

        send_fft_frame(0);
        send_fft_frame(0);
        send_fft_frame(0);
        send_fft_frame(0);

        send_fft_frame(60000);
        if ((beat_count != 16'd1) || (peak_bin != 8'd2)) begin
            $display("FAIL: first burst count=%0d peak_bin=%0d energy=%0d",
                     beat_count, peak_bin, beat_energy);
            $fatal;
        end

        send_fft_frame(0);
        send_fft_frame(0);
        send_fft_frame(0);
        send_fft_frame(60000);

        if ((beat_count != 16'd2) || (pulse_count != 2) || (peak_bin != 8'd2)) begin
            $display("FAIL: integration count=%0d pulses=%0d peak_bin=%0d energy=%0d",
                     beat_count, pulse_count, peak_bin, beat_energy);
            $fatal;
        end

        $display("PASS: audio_beat_integration_tb count=%0d pulses=%0d energy=%0d",
                 beat_count, pulse_count, beat_energy);
        $finish;
    end

endmodule

`default_nettype wire
