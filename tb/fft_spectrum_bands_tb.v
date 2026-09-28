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
    integer bin_number;
    integer band_number;
    integer band_start;
    integer band_end;
    integer ownership_count;

    audio_fft_analyzer dut (
        .clk(clk), .sample(sample), .sample_valid(sample_valid),
        .busy(busy), .peak_valid(spectrum_valid),
        .peak_bin(peak_bin), .peak_power(peak_power),
        .spectrum(spectrum)
    );

    always #18.5185 clk = ~clk;

    task check_band_mapping;
        integer mapping_band;
        integer previous_end;
        begin
            previous_end = 0;
            for (mapping_band = 0; mapping_band < 32; mapping_band = mapping_band + 1) begin
                band_start = previous_end + 1;
                band_end = dut.fft_core_inst.spectrum_band_end(mapping_band);
                if (band_end < band_start) begin
                    $display("Mapping FAIL: band %0d has invalid range %0d-%0d",
                             mapping_band, band_start, band_end);
                    failures = failures + 1;
                end
                previous_end = band_end;
            end

            if (previous_end != 127) begin
                $display("Mapping FAIL: final bin is %0d, expected 127", previous_end);
                failures = failures + 1;
            end

            for (bin_number = 1; bin_number <= 127; bin_number = bin_number + 1) begin
                ownership_count = 0;
                previous_end = 0;
                for (mapping_band = 0; mapping_band < 32; mapping_band = mapping_band + 1) begin
                    band_start = previous_end + 1;
                    band_end = dut.fft_core_inst.spectrum_band_end(mapping_band);
                    if ((bin_number >= band_start) && (bin_number <= band_end))
                        ownership_count = ownership_count + 1;
                    previous_end = band_end;
                end
                if (ownership_count != 1) begin
                    $display("Mapping FAIL: bin %0d belongs to %0d bands",
                             bin_number, ownership_count);
                    failures = failures + 1;
                end
            end

            if (failures == 0)
                $display("Mapping bins 1-127: exactly one band per bin PASS");
        end
    endtask

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

        check_band_mapping;
        run_tone(549.31640625, 3, "549.316 Hz");
        run_tone(1000.0, 6, "1000 Hz");
        run_tone(2500.0, 12, "2500 Hz");
        run_tone(3021.240234375, 14, "3021.240 Hz");
        run_tone(8000.0, 24, "8000 Hz");

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
