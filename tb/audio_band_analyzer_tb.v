`timescale 1ns/1ps
`default_nettype none

module audio_band_analyzer_tb;

    localparam integer SAMPLE_PERIOD_CLKS = 768;
    localparam integer PCM_AMPLITUDE = 1000000;
    localparam real SAMPLE_RATE_HZ = 35156.25;
    localparam real TWO_PI = 6.28318530717958647692;

    reg clk;
    reg sample_valid;
    reg signed [23:0] sample_50hz;
    reg signed [23:0] sample_100hz;
    reg signed [23:0] sample_250hz;
    reg signed [23:0] sample_500hz;
    reg signed [23:0] sample_1400hz;
    reg signed [23:0] sample_3000hz;
    reg signed [23:0] sample_8000hz;

    integer sample_clock_counter;
    real phase_50hz;
    real phase_100hz;
    real phase_250hz;
    real phase_500hz;
    real phase_1400hz;
    real phase_3000hz;
    real phase_8000hz;

    wire [7:0] low_50hz;
    wire [7:0] mid_50hz;
    wire [7:0] high_50hz;
    wire toggle_50hz;

    wire [7:0] low_100hz;
    wire [7:0] mid_100hz;
    wire [7:0] high_100hz;
    wire toggle_100hz;

    wire [7:0] low_250hz;
    wire [7:0] mid_250hz;
    wire [7:0] high_250hz;
    wire toggle_250hz;

    wire [7:0] low_500hz;
    wire [7:0] mid_500hz;
    wire [7:0] high_500hz;
    wire toggle_500hz;

    wire [7:0] low_1400hz;
    wire [7:0] mid_1400hz;
    wire [7:0] high_1400hz;
    wire toggle_1400hz;

    wire [7:0] low_3000hz;
    wire [7:0] mid_3000hz;
    wire [7:0] high_3000hz;
    wire toggle_3000hz;

    wire [7:0] low_8000hz;
    wire [7:0] mid_8000hz;
    wire [7:0] high_8000hz;
    wire toggle_8000hz;

    audio_band_analyzer analyzer_50hz (
        .clk(clk),
        .sample(sample_50hz),
        .sample_valid(sample_valid),
        .report_raw(),
        .report_peak(),
        .report_rms(),
        .report_low(low_50hz),
        .report_mid(mid_50hz),
        .report_high(high_50hz),
        .report_toggle(toggle_50hz),
        .audio_active()
    );

    audio_band_analyzer analyzer_100hz (
        .clk(clk),
        .sample(sample_100hz),
        .sample_valid(sample_valid),
        .report_raw(),
        .report_peak(),
        .report_rms(),
        .report_low(low_100hz),
        .report_mid(mid_100hz),
        .report_high(high_100hz),
        .report_toggle(toggle_100hz),
        .audio_active()
    );

    audio_band_analyzer analyzer_500hz (
        .clk(clk),
        .sample(sample_500hz),
        .sample_valid(sample_valid),
        .report_raw(),
        .report_peak(),
        .report_rms(),
        .report_low(low_500hz),
        .report_mid(mid_500hz),
        .report_high(high_500hz),
        .report_toggle(toggle_500hz),
        .audio_active()
    );

    audio_band_analyzer analyzer_250hz (
        .clk(clk),
        .sample(sample_250hz),
        .sample_valid(sample_valid),
        .report_raw(),
        .report_peak(),
        .report_rms(),
        .report_low(low_250hz),
        .report_mid(mid_250hz),
        .report_high(high_250hz),
        .report_toggle(toggle_250hz),
        .audio_active()
    );

    audio_band_analyzer analyzer_1400hz (
        .clk(clk),
        .sample(sample_1400hz),
        .sample_valid(sample_valid),
        .report_raw(),
        .report_peak(),
        .report_rms(),
        .report_low(low_1400hz),
        .report_mid(mid_1400hz),
        .report_high(high_1400hz),
        .report_toggle(toggle_1400hz),
        .audio_active()
    );

    audio_band_analyzer analyzer_3000hz (
        .clk(clk),
        .sample(sample_3000hz),
        .sample_valid(sample_valid),
        .report_raw(),
        .report_peak(),
        .report_rms(),
        .report_low(low_3000hz),
        .report_mid(mid_3000hz),
        .report_high(high_3000hz),
        .report_toggle(toggle_3000hz),
        .audio_active()
    );

    audio_band_analyzer analyzer_8000hz (
        .clk(clk),
        .sample(sample_8000hz),
        .sample_valid(sample_valid),
        .report_raw(),
        .report_peak(),
        .report_rms(),
        .report_low(low_8000hz),
        .report_mid(mid_8000hz),
        .report_high(high_8000hz),
        .report_toggle(toggle_8000hz),
        .audio_active()
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always @(negedge clk) begin
        if (sample_clock_counter == SAMPLE_PERIOD_CLKS - 1) begin
            sample_clock_counter = 0;
            sample_50hz = $rtoi(PCM_AMPLITUDE * $sin(phase_50hz));
            sample_100hz = $rtoi(PCM_AMPLITUDE * $sin(phase_100hz));
            sample_250hz = $rtoi(PCM_AMPLITUDE * $sin(phase_250hz));
            sample_500hz = $rtoi(PCM_AMPLITUDE * $sin(phase_500hz));
            sample_1400hz = $rtoi(PCM_AMPLITUDE * $sin(phase_1400hz));
            sample_3000hz = $rtoi(PCM_AMPLITUDE * $sin(phase_3000hz));
            sample_8000hz = $rtoi(PCM_AMPLITUDE * $sin(phase_8000hz));
            sample_valid = 1'b1;

            phase_50hz = phase_50hz + (TWO_PI * 50.0 / SAMPLE_RATE_HZ);
            phase_100hz = phase_100hz + (TWO_PI * 100.0 / SAMPLE_RATE_HZ);
            phase_250hz = phase_250hz + (TWO_PI * 250.0 / SAMPLE_RATE_HZ);
            phase_500hz = phase_500hz + (TWO_PI * 500.0 / SAMPLE_RATE_HZ);
            phase_1400hz = phase_1400hz + (TWO_PI * 1400.0 / SAMPLE_RATE_HZ);
            phase_3000hz = phase_3000hz + (TWO_PI * 3000.0 / SAMPLE_RATE_HZ);
            phase_8000hz = phase_8000hz + (TWO_PI * 8000.0 / SAMPLE_RATE_HZ);

            if (phase_50hz >= TWO_PI)
                phase_50hz = phase_50hz - TWO_PI;
            if (phase_100hz >= TWO_PI)
                phase_100hz = phase_100hz - TWO_PI;
            if (phase_250hz >= TWO_PI)
                phase_250hz = phase_250hz - TWO_PI;
            if (phase_500hz >= TWO_PI)
                phase_500hz = phase_500hz - TWO_PI;
            if (phase_1400hz >= TWO_PI)
                phase_1400hz = phase_1400hz - TWO_PI;
            if (phase_3000hz >= TWO_PI)
                phase_3000hz = phase_3000hz - TWO_PI;
            if (phase_8000hz >= TWO_PI)
                phase_8000hz = phase_8000hz - TWO_PI;
        end else begin
            sample_clock_counter = sample_clock_counter + 1;
            sample_valid = 1'b0;
        end
    end

    task check_low_frequency;
        begin
            if ((low_100hz > mid_100hz) && (low_100hz > high_100hz)) begin
                $display(
                    "100Hz: LOW=%0d MID=%0d HIGH=%0d PASS",
                    low_100hz,
                    mid_100hz,
                    high_100hz
                );
            end else begin
                $display(
                    "100Hz: LOW=%0d MID=%0d HIGH=%0d FAIL: LOW is not dominant",
                    low_100hz,
                    mid_100hz,
                    high_100hz
                );
                $fatal;
            end
        end
    endtask

    task check_mid_frequency;
        begin
            if ((mid_500hz > low_500hz) && (mid_500hz > high_500hz)) begin
                $display(
                    "500Hz: LOW=%0d MID=%0d HIGH=%0d PASS",
                    low_500hz,
                    mid_500hz,
                    high_500hz
                );
            end else begin
                $display(
                    "500Hz: LOW=%0d MID=%0d HIGH=%0d FAIL: MID is not dominant",
                    low_500hz,
                    mid_500hz,
                    high_500hz
                );
                $fatal;
            end
        end
    endtask

    task check_high_frequency;
        begin
            if ((high_3000hz > low_3000hz) && (high_3000hz > mid_3000hz)) begin
                $display(
                    "3000Hz: LOW=%0d MID=%0d HIGH=%0d PASS",
                    low_3000hz,
                    mid_3000hz,
                    high_3000hz
                );
            end else begin
                $display(
                    "3000Hz: LOW=%0d MID=%0d HIGH=%0d FAIL: HIGH is not dominant",
                    low_3000hz,
                    mid_3000hz,
                    high_3000hz
                );
                $fatal;
            end
        end
    endtask

    initial begin
        sample_valid = 1'b0;
        sample_50hz = 24'sd0;
        sample_100hz = 24'sd0;
        sample_250hz = 24'sd0;
        sample_500hz = 24'sd0;
        sample_1400hz = 24'sd0;
        sample_3000hz = 24'sd0;
        sample_8000hz = 24'sd0;
        sample_clock_counter = 0;
        phase_50hz = 0.0;
        phase_100hz = 0.0;
        phase_250hz = 0.0;
        phase_500hz = 0.0;
        phase_1400hz = 0.0;
        phase_3000hz = 0.0;
        phase_8000hz = 0.0;

        // Use the third 100 ms report so all filters have settled.
        repeat (3) @(toggle_100hz);
        @(negedge clk);

        if ((toggle_100hz !== toggle_50hz) ||
            (toggle_100hz !== toggle_250hz) ||
            (toggle_100hz !== toggle_500hz) ||
            (toggle_100hz !== toggle_1400hz) ||
            (toggle_100hz !== toggle_3000hz) ||
            (toggle_100hz !== toggle_8000hz)) begin
            $display("FAIL: analyzer report toggles are not synchronized");
            $fatal;
        end

        $display(
            "50Hz: LOW=%0d MID=%0d HIGH=%0d",
            low_50hz,
            mid_50hz,
            high_50hz
        );
        check_low_frequency;
        $display(
            "250Hz: LOW=%0d MID=%0d HIGH=%0d boundary",
            low_250hz,
            mid_250hz,
            high_250hz
        );
        check_mid_frequency;
        $display(
            "1400Hz: LOW=%0d MID=%0d HIGH=%0d boundary",
            low_1400hz,
            mid_1400hz,
            high_1400hz
        );
        check_high_frequency;
        $display(
            "8000Hz: LOW=%0d MID=%0d HIGH=%0d",
            low_8000hz,
            mid_8000hz,
            high_8000hz
        );

        $display("PASS: audio_band_analyzer_tb dominant bands matched");
        $finish;
    end

    initial begin
        repeat (8500000) @(posedge clk);
        $display("FAIL: audio_band_analyzer_tb timed out");
        $fatal;
    end

endmodule

`default_nettype wire
