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
    wire               audio_active;

    reg [21:0] led_hold;

    assign led0 = (led_hold != 22'd0) ? 1'b0 : 1'b1;

    always @(posedge clk) begin
        if (audio_active)
            led_hold <= 22'd675000;
        else if (led_hold != 22'd0)
            led_hold <= led_hold - 22'd1;
    end

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
        .audio_active(audio_active)
    );

    wire      uart_start;
    wire      uart_busy;
    wire [7:0] uart_data;
    reg       sender_start;
    wire      sender_busy;
    reg       seen_report_toggle;

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
        .start(sender_start),
        .raw(report_raw),
        .peak(report_peak),
        .rms(report_rms),
        .low(report_low),
        .mid(report_mid),
        .high(report_high),
        .busy(sender_busy),
        .uart_start(uart_start),
        .uart_data(uart_data),
        .uart_busy(uart_busy)
    );

    initial begin
        led_hold = 22'd0;
        sender_start = 1'b0;
        seen_report_toggle = 1'b0;
    end

    always @(posedge clk) begin
        sender_start <= 1'b0;

        if ((seen_report_toggle != report_toggle) && !sender_busy) begin
            seen_report_toggle <= report_toggle;
            sender_start <= 1'b1;
        end
    end

endmodule

`default_nettype wire
