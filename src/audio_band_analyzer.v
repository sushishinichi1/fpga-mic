`default_nettype none

module audio_band_analyzer (
    input  wire              clk,
    input  wire signed [23:0] sample,
    input  wire              sample_valid,
    output reg signed [23:0] report_raw,
    output reg [7:0]         report_peak,
    output reg [7:0]         report_rms,
    output reg [7:0]         report_low,
    output reg [7:0]         report_mid,
    output reg [7:0]         report_high,
    output reg               report_toggle,
    output wire              audio_active
);

    localparam [21:0] REPORT_INTERVAL = 22'd2700000;

    // At about 35.16 kHz sample rate, these one-pole filters are gentle but
    // cheap: low is roughly below 250 Hz, and mid/high split around 1.4 kHz.
    localparam integer LOW_SHIFT  = 5;
    localparam integer MID_SHIFT  = 2;

    reg [21:0] report_counter;
    reg [23:0] peak_accum;
    reg [31:0] rms_accum;
    reg [31:0] low_accum;
    reg [31:0] mid_accum;
    reg [31:0] high_accum;

    reg signed [31:0] low_lp;
    reg signed [31:0] mid_lp;
    reg signed [31:0] sample32_r;
    reg signed [31:0] low_band_r;
    reg signed [31:0] mid_band_r;
    reg signed [31:0] high_band_r;
    reg [23:0] sample_abs_r;
    reg        process_valid;

    wire signed [31:0] sample32 = {{8{sample[23]}}, sample};
    wire [23:0] sample_abs = abs24(sample);
    wire [23:0] low_abs = abs32_to_24(low_band_r);
    wire [23:0] mid_abs = abs32_to_24(mid_band_r);
    wire [23:0] high_abs = abs32_to_24(high_band_r);

    assign audio_active = (sample_abs_r > 24'd32768);

    function [23:0] abs24;
        input signed [23:0] value;
        begin
            if (value[23])
                abs24 = (~value) + 24'd1;
            else
                abs24 = value;
        end
    endfunction

    function [23:0] abs32_to_24;
        input signed [31:0] value;
        reg [31:0] magnitude;
        begin
            if (value[31])
                magnitude = (~value) + 32'd1;
            else
                magnitude = value;

            if (magnitude[31:24] != 8'd0)
                abs32_to_24 = 24'hffffff;
            else
                abs32_to_24 = magnitude[23:0];
        end
    endfunction

    function [7:0] scale_peak;
        input [23:0] peak;
        begin
            if (peak >= 24'd1044480)
                scale_peak = 8'd255;
            else
                scale_peak = peak[19:12];
        end
    endfunction

    function [7:0] scale_average;
        input [31:0] sum_value;
        begin
            if (sum_value[31:15] >= 17'd255)
                scale_average = 8'd255;
            else
                scale_average = sum_value[22:15];
        end
    endfunction

    function [7:0] scale_band;
        input [31:0] sum_value;
        begin
            if (sum_value[31:13] >= 19'd255)
                scale_band = 8'd255;
            else
                scale_band = sum_value[20:13];
        end
    endfunction

    initial begin
        report_raw = 24'sd0;
        report_peak = 8'd0;
        report_rms = 8'd0;
        report_low = 8'd0;
        report_mid = 8'd0;
        report_high = 8'd0;
        report_toggle = 1'b0;
        report_counter = 22'd0;
        peak_accum = 24'd0;
        rms_accum = 32'd0;
        low_accum = 32'd0;
        mid_accum = 32'd0;
        high_accum = 32'd0;
        low_lp = 32'sd0;
        mid_lp = 32'sd0;
        sample32_r = 32'sd0;
        low_band_r = 32'sd0;
        mid_band_r = 32'sd0;
        high_band_r = 32'sd0;
        sample_abs_r = 24'd0;
        process_valid = 1'b0;
    end

    always @(posedge clk) begin
        process_valid <= sample_valid;

        if (report_counter == REPORT_INTERVAL - 22'd1) begin
            report_counter <= 22'd0;
            report_peak <= scale_peak(peak_accum);
            report_rms <= scale_average(rms_accum);
            report_low <= scale_band(low_accum);
            report_mid <= scale_band(mid_accum);
            report_high <= scale_band(high_accum);
            report_toggle <= ~report_toggle;
            peak_accum <= 24'd0;
            rms_accum <= 32'd0;
            low_accum <= 32'd0;
            mid_accum <= 32'd0;
            high_accum <= 32'd0;
        end else begin
            report_counter <= report_counter + 22'd1;
        end

        if (sample_valid) begin
            report_raw <= sample;
            sample32_r <= sample32;
            sample_abs_r <= sample_abs;
        end

        if (process_valid) begin
            low_lp <= low_lp + ((sample32_r - low_lp) >>> LOW_SHIFT);
            mid_lp <= mid_lp + ((sample32_r - mid_lp) >>> MID_SHIFT);

            low_band_r <= low_lp;
            mid_band_r <= mid_lp - low_lp;
            high_band_r <= sample32_r - mid_lp;

            if (sample_abs_r > peak_accum)
                peak_accum <= sample_abs_r;

            rms_accum <= rms_accum + {20'd0, sample_abs_r[23:12]};
            low_accum <= low_accum + {20'd0, low_abs[23:12]};
            mid_accum <= mid_accum + {20'd0, mid_abs[23:12]};
            high_accum <= high_accum + {20'd0, high_abs[23:12]};
        end
    end

endmodule

`default_nettype wire
