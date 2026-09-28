`timescale 1ns/1ps
`default_nettype none

module audio_fft_analyzer_tb;

    localparam real PI = 3.14159265358979323846;
    localparam real SAMPLE_RATE = 35156.25;
    localparam integer AMPLITUDE = 60000;

    reg clk;
    reg signed [23:0] sample;
    reg sample_valid;
    wire busy;
    wire peak_valid;
    wire [7:0] peak_bin;
    wire [36:0] peak_power;
    wire rectangular_busy;
    wire rectangular_peak_valid;
    wire [7:0] rectangular_peak_bin;
    wire [36:0] rectangular_peak_power;

    integer failures;
    integer fft_clock_count;
    reg count_fft_clocks;
    reg signed [17:0] measured_real;
    reg signed [17:0] measured_imag;
    reg [36:0] window_adjacent_power;
    reg [36:0] window_far_power;
    reg [36:0] rectangular_adjacent_power;
    reg [36:0] rectangular_far_power;
    reg [73:0] window_leakage_cross;
    reg [73:0] rectangular_leakage_cross;

    audio_fft_analyzer dut (
        .clk(clk), .sample(sample), .sample_valid(sample_valid),
        .busy(busy), .peak_valid(peak_valid),
        .peak_bin(peak_bin), .peak_power(peak_power)
    );

    // This instance exists only to quantify Hann leakage reduction.
    audio_fft_analyzer #(
        .ENABLE_HANN(0)
    ) rectangular_dut (
        .clk(clk), .sample(sample), .sample_valid(sample_valid),
        .busy(rectangular_busy), .peak_valid(rectangular_peak_valid),
        .peak_bin(rectangular_peak_bin), .peak_power(rectangular_peak_power)
    );

    always #18.5185 clk = ~clk;

    always @(posedge clk) begin
        if (count_fft_clocks)
            fft_clock_count <= fft_clock_count + 1;
    end

    function [36:0] magnitude_power;
        input signed [17:0] real_value;
        input signed [17:0] imag_value;
        reg signed [35:0] real_square;
        reg signed [35:0] imag_square;
        begin
            real_square = real_value * real_value;
            imag_square = imag_value * imag_value;
            magnitude_power = {1'b0, real_square} + {1'b0, imag_square};
        end
    endfunction

    task run_tone;
        input real frequency;
        input integer expected_bin;
        input integer tolerance;
        input integer compare_leakage;
        input [8*32-1:0] label;
        integer index;
        integer pcm_value;
        integer wait_clocks;
        integer adjacent_bin;
        integer far_bin;
        begin
            while (busy || rectangular_busy)
                @(posedge clk);

            for (index = 0; index < 256; index = index + 1) begin
                pcm_value = $rtoi(AMPLITUDE * $sin(2.0 * PI * frequency * index / SAMPLE_RATE));
                @(negedge clk);
                sample = pcm_value * 64;
                sample_valid = 1'b1;
                @(negedge clk);
                sample_valid = 1'b0;
                repeat (3) @(posedge clk);
            end

            wait_clocks = 0;
            while (!busy && (wait_clocks < 20)) begin
                @(posedge clk);
                wait_clocks = wait_clocks + 1;
            end

            fft_clock_count = 0;
            count_fft_clocks = 1'b1;
            wait_clocks = 0;
            while (!peak_valid && (wait_clocks < 7000)) begin
                @(posedge clk);
                wait_clocks = wait_clocks + 1;
            end
            count_fft_clocks = 1'b0;

            if (!peak_valid) begin
                $display("%0s: FAIL timeout expected_bin=%0d", label, expected_bin);
                failures = failures + 1;
            end else if ((peak_bin + tolerance < expected_bin) ||
                         (peak_bin > expected_bin + tolerance)) begin
                $display("%0s: peak_bin=%0d peak_power=%0d expected_bin=%0d FAIL",
                         label, peak_bin, peak_power, expected_bin);
                failures = failures + 1;
            end else begin
                $display("%0s: peak_bin=%0d peak_power=%0d expected_bin=%0d clocks=%0d PASS",
                         label, peak_bin, peak_power, expected_bin, fft_clock_count);
            end

            if (compare_leakage != 0) begin
                adjacent_bin = expected_bin + 1;
                far_bin = expected_bin + 5;

                measured_real = dut.fft_core_inst.real_ram_inst.memory[adjacent_bin];
                measured_imag = dut.fft_core_inst.imag_ram_inst.memory[adjacent_bin];
                window_adjacent_power = magnitude_power(measured_real, measured_imag);
                measured_real = dut.fft_core_inst.real_ram_inst.memory[far_bin];
                measured_imag = dut.fft_core_inst.imag_ram_inst.memory[far_bin];
                window_far_power = magnitude_power(measured_real, measured_imag);

                measured_real = rectangular_dut.fft_core_inst.real_ram_inst.memory[adjacent_bin];
                measured_imag = rectangular_dut.fft_core_inst.imag_ram_inst.memory[adjacent_bin];
                rectangular_adjacent_power = magnitude_power(measured_real, measured_imag);
                measured_real = rectangular_dut.fft_core_inst.real_ram_inst.memory[far_bin];
                measured_imag = rectangular_dut.fft_core_inst.imag_ram_inst.memory[far_bin];
                rectangular_far_power = magnitude_power(measured_real, measured_imag);

                window_leakage_cross = window_far_power * rectangular_peak_power;
                rectangular_leakage_cross = rectangular_far_power * peak_power;

                $display("  leakage: Hann peak=%0d adjacent=%0d far(bin %0d)=%0d",
                         peak_power, window_adjacent_power, far_bin, window_far_power);
                $display("           Rect peak=%0d adjacent=%0d far(bin %0d)=%0d",
                         rectangular_peak_power, rectangular_adjacent_power,
                         far_bin, rectangular_far_power);

                if (window_leakage_cross >= rectangular_leakage_cross) begin
                    $display("  FAIL: normalized Hann far-bin leakage was not reduced");
                    failures = failures + 1;
                end else begin
                    $display("  PASS: normalized Hann far-bin leakage reduced");
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
        fft_clock_count = 0;
        count_fft_clocks = 1'b0;

        repeat (4) @(posedge clk);

        run_tone(549.31640625, 4, 0, 0, "bin 4 center");
        run_tone(3021.240234375, 22, 0, 0, "bin 22 center");
        run_tone(500.0, 4, 1, 0, "500 Hz");
        run_tone(3000.0, 22, 1, 0, "3000 Hz");
        run_tone(440.0, 3, 1, 1, "440 Hz");
        run_tone(1000.0, 7, 1, 1, "1000 Hz");
        run_tone(2500.0, 18, 1, 1, "2500 Hz");

        if (failures == 0) begin
            $display("audio_fft_analyzer_tb PASS");
            $finish;
        end else begin
            $display("audio_fft_analyzer_tb FAIL: %0d failure(s)", failures);
            $fatal(1);
        end
    end

endmodule

`default_nettype wire
