`default_nettype none

module top (
    input  wire clk,

    input  wire mic_sd,
    output wire mic_sck,
    output wire mic_ws,
    output wire mic_lr,

    output wire uart_tx,
    output wire led0
);

    localparam integer CLK_HZ    = 27000000;
    localparam integer BAUD_RATE = 115200;

    wire signed [23:0] mic_sample;
    wire               mic_sample_valid;
    wire signed [23:0] report_raw;
    wire [7:0]         report_peak;
    wire [7:0]         report_rms;
    wire [7:0]         report_low;
    wire [7:0]         report_mid;
    wire [7:0]         report_high;
    wire               report_toggle;
    wire               fft_busy;
    wire               fft_peak_valid;
    wire [7:0]         fft_peak_bin;
    wire [36:0]        fft_peak_power;
    wire [255:0]       fft_spectrum;
    wire [38:0]        fft_beat_energy;
    wire               beat_pulse;
    wire [15:0]        beat_count;
    wire [15:0]        latest_bpm;
    wire               bpm_valid;
    wire [15:0]        beat_interval_ms;
    reg [7:0]          latest_fft_bin;
    reg [36:0]         latest_fft_power;
    reg [255:0]        latest_spectrum;
    reg                beat_latched;
    reg                report_beat;

    // LED0 is active low. Keep it off during normal analyzer operation.
    assign led0 = 1'b1;

    inmp441_i2s_rx i2s_rx_inst (
        .clk(clk),
        .mic_sd(mic_sd),
        .mic_sck(mic_sck),
        .mic_ws(mic_ws),
        .mic_lr(mic_lr),
        .sample(mic_sample),
        .sample_valid(mic_sample_valid)
    );

    audio_band_analyzer analyzer_inst (
        .clk(clk),
        .sample(mic_sample),
        .sample_valid(mic_sample_valid),
        .report_raw(report_raw),
        .report_peak(report_peak),
        .report_rms(report_rms),
        .report_low(report_low),
        .report_mid(report_mid),
        .report_high(report_high),
        .report_toggle(report_toggle),
        .audio_active()
    );

    (* keep_hierarchy = "yes", syn_keep = 1 *)
    audio_fft_analyzer fft_analyzer_inst (
        .clk(clk),
        .sample(mic_sample),
        .sample_valid(mic_sample_valid),
        .busy(fft_busy),
        .peak_valid(fft_peak_valid),
        .peak_bin(fft_peak_bin),
        .peak_power(fft_peak_power),
        .spectrum(fft_spectrum),
        .beat_energy(fft_beat_energy)
    );

    beat_detector beat_detector_inst (
        .clk(clk),
        .reset(1'b0),
        .frame_valid(fft_peak_valid),
        .beat_energy(fft_beat_energy),
        .beat_pulse(beat_pulse),
        .beat_count(beat_count)
    );

    bpm_detector #(
        .CLK_HZ(CLK_HZ)
    ) bpm_detector_inst (
        .clk(clk),
        .reset(1'b0),
        .beat_pulse(beat_pulse),
        .bpm(latest_bpm),
        .bpm_valid(bpm_valid),
        .interval_ms(beat_interval_ms)
    );

    wire      uart_start;
    wire      uart_busy;
    wire [7:0] uart_data;
    reg       audio_sender_start;
    wire      audio_sender_busy;
    wire      audio_uart_start;
    wire [7:0] audio_uart_data;
    reg       spectrum_sender_start;
    wire      spectrum_sender_busy;
    wire      spectrum_uart_start;
    wire [7:0] spectrum_uart_data;
    reg       seen_report_toggle;
    reg       uart_owner;
    reg [2:0] uart_arbiter_state;

    localparam [2:0] ARB_IDLE               = 3'd0;
    localparam [2:0] ARB_AUDIO_WAIT_HIGH    = 3'd1;
    localparam [2:0] ARB_AUDIO_WAIT_LOW     = 3'd2;
    localparam [2:0] ARB_SPECTRUM_WAIT_HIGH = 3'd3;
    localparam [2:0] ARB_SPECTRUM_WAIT_LOW  = 3'd4;

    assign uart_start = uart_owner ? spectrum_uart_start : audio_uart_start;
    assign uart_data = uart_owner ? spectrum_uart_data : audio_uart_data;

    uart_tx #(
        .CLK_HZ(CLK_HZ),
        .BAUD_RATE(BAUD_RATE)
    ) uart_tx_inst (
        .clk(clk),
        .start(uart_start),
        .data(uart_data),
        .busy(uart_busy),
        .tx(uart_tx)
    );

    audio_uart_sender audio_uart_sender_inst (
        .clk(clk),
        .start(audio_sender_start),
        .raw(report_raw),
        .peak(report_peak),
        .rms(report_rms),
        .low(report_low),
        .mid(report_mid),
        .high(report_high),
        .fft_bin(latest_fft_bin),
        .fft_power(latest_fft_power),
        .beat(report_beat),
        .beat_count(beat_count),
        .bpm(latest_bpm),
        .bpm_valid(bpm_valid),
        .busy(audio_sender_busy),
        .uart_start(audio_uart_start),
        .uart_data(audio_uart_data),
        .uart_busy(uart_busy)
    );

    spectrum_uart_sender spectrum_uart_sender_inst (
        .clk(clk),
        .start(spectrum_sender_start),
        .spectrum(latest_spectrum),
        .busy(spectrum_sender_busy),
        .uart_start(spectrum_uart_start),
        .uart_data(spectrum_uart_data),
        .uart_busy(uart_busy)
    );

    initial begin
        audio_sender_start = 1'b0;
        spectrum_sender_start = 1'b0;
        seen_report_toggle = 1'b0;
        latest_fft_bin = 8'd0;
        latest_fft_power = 37'd0;
        latest_spectrum = 256'd0;
        beat_latched = 1'b0;
        report_beat = 1'b0;
        uart_owner = 1'b0;
        uart_arbiter_state = ARB_IDLE;
    end

    always @(posedge clk) begin
        audio_sender_start <= 1'b0;
        spectrum_sender_start <= 1'b0;

        if (beat_pulse)
            beat_latched <= 1'b1;

        if (fft_peak_valid) begin
            latest_fft_bin <= fft_peak_bin;
            latest_fft_power <= fft_peak_power;
            latest_spectrum <= fft_spectrum;
        end

        case (uart_arbiter_state)
            ARB_IDLE: begin
                if (seen_report_toggle != report_toggle) begin
                    seen_report_toggle <= report_toggle;
                    report_beat <= beat_latched;
                    if (!beat_pulse)
                        beat_latched <= 1'b0;
                    uart_owner <= 1'b0;
                    audio_sender_start <= 1'b1;
                    uart_arbiter_state <= ARB_AUDIO_WAIT_HIGH;
                end
            end

            ARB_AUDIO_WAIT_HIGH: begin
                if (audio_sender_busy)
                    uart_arbiter_state <= ARB_AUDIO_WAIT_LOW;
            end

            ARB_AUDIO_WAIT_LOW: begin
                if (!audio_sender_busy) begin
                    uart_owner <= 1'b1;
                    spectrum_sender_start <= 1'b1;
                    uart_arbiter_state <= ARB_SPECTRUM_WAIT_HIGH;
                end
            end

            ARB_SPECTRUM_WAIT_HIGH: begin
                if (spectrum_sender_busy)
                    uart_arbiter_state <= ARB_SPECTRUM_WAIT_LOW;
            end

            ARB_SPECTRUM_WAIT_LOW: begin
                if (!spectrum_sender_busy) begin
                    uart_owner <= 1'b0;
                    uart_arbiter_state <= ARB_IDLE;
                end
            end

            default: uart_arbiter_state <= ARB_IDLE;
        endcase
    end

endmodule

`default_nettype wire
