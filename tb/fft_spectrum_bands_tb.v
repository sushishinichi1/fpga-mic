`timescale 1ns/1ps
`default_nettype none

module fft_spectrum_bands_tb;

    localparam real PI = 3.14159265358979323846;
    localparam real SAMPLE_RATE = 35156.25;
    localparam integer AMPLITUDE = 60000;

    reg clk;
    reg signed [23:0] sample;
    reg sample_valid;
    wire busy;
    wire spectrum_valid;
    wire [7:0] peak_bin;
    wire [36:0] peak_power;
    wire [255:0] spectrum;
    integer failures;

    audio_fft_analyzer dut (
        .clk(clk), .sample(sample), .sample_valid(sample_valid),
        .busy(busy), .peak_valid(spectrum_valid),
        .peak_bin(peak_bin), .peak_power(peak_power),
        .spectrum(spectrum)
    );

    always #18.5185 clk = ~clk;

    task run_tone;
        input real frequency;
        input integer expected_band;
        input [8*24-1:0] label;
        integer sample_number;
        integer pcm_value;
        integer wait_clocks;
        integer band_number;
        integer max_band;
        integer max_value;
        reg [7:0] band_value;
        begin
            while (busy)
                @(posedge clk);

            for (sample_number = 0; sample_number < 256; sample_number = sample_number + 1) begin
                pcm_value = $rtoi(AMPLITUDE * $sin(
                    2.0 * PI * frequency * sample_number / SAMPLE_RATE
                ));
                @(negedge clk);
                sample = pcm_value * 64;
                sample_valid = 1'b1;
                @(negedge clk);
                sample_valid = 1'b0;
                repeat (3) @(posedge clk);
            end

            wait_clocks = 0;
            while (!spectrum_valid && (wait_clocks < 7000)) begin
                @(posedge clk);
                wait_clocks = wait_clocks + 1;
            end

            if (!spectrum_valid) begin
                $display("%0s: FAIL timeout", label);
                failures = failures + 1;
            end else begin
                max_band = 0;
                max_value = 0;
                for (band_number = 0; band_number < 32; band_number = band_number + 1) begin
                    band_value = spectrum[(band_number * 8) +: 8];
                    if ($isunknown(band_value)) begin
                        $display("%0s: FAIL band %0d is unknown", label, band_number);
                        failures = failures + 1;
                    end
                    if ((band_number == 0) || (band_value > max_value)) begin
                        max_value = band_value;
                        max_band = band_number;
                    end
                end

                if (max_band != expected_band) begin
                    $display("%0s: peak_bin=%0d max_band=%0d value=%0d expected_band=%0d FAIL",
                             label, peak_bin, max_band, max_value, expected_band);
                    failures = failures + 1;
                end else begin
                    $display("%0s: peak_bin=%0d max_band=%0d value=%0d expected_band=%0d PASS",
                             label, peak_bin, max_band, max_value, expected_band);
                end
            end

            @(posedge clk);
        end
    endtask

    initial begin
        clk = 1'b0;
        sample = 24'sd0;
        sample_valid = 1'b0;
        failures = 0;
        repeat (4) @(posedge clk);

        run_tone(549.31640625, 0, "549.316 Hz");
        run_tone(3021.240234375, 5, "3021.240 Hz");
        run_tone(8000.0, 14, "8000 Hz");

        if (failures == 0) begin
            $display("fft_spectrum_bands_tb PASS");
            $finish;
        end else begin
            $display("fft_spectrum_bands_tb FAIL: %0d failure(s)", failures);
            $fatal(1);
        end
    end

endmodule

`default_nettype wire
