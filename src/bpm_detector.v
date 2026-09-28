`default_nettype none

module bpm_detector #(
    parameter integer CLK_HZ = 27000000,
    parameter [15:0] MIN_INTERVAL_MS = 16'd273,
    parameter [15:0] MAX_INTERVAL_MS = 16'd1500
) (
    input  wire        clk,
    input  wire        reset,
    input  wire        beat_pulse,
    output reg  [15:0] bpm,
    output reg         bpm_valid,
    output reg  [15:0] interval_ms
);

    localparam integer CLKS_PER_MS = CLK_HZ / 1000;

    reg [15:0] ms_divider_count;
    reg [15:0] elapsed_ms;
    reg        timing_active;
    reg [15:0] pending_interval;
    reg        division_pending;
    reg        divider_start;

    wire ms_tick = (ms_divider_count == CLKS_PER_MS - 1);
    wire [16:0] elapsed_at_beat = {1'b0, elapsed_ms} +
                                  (ms_tick ? 17'd1 : 17'd0);
    wire [15:0] divider_quotient;
    wire divider_busy;
    wire divider_done;

    bpm_divider divider_inst (
        .clk(clk),
        .reset(reset),
        .start(divider_start),
        .dividend(16'd60000),
        .divisor(pending_interval),
        .quotient(divider_quotient),
        .busy(divider_busy),
        .done(divider_done)
    );

    initial begin
        bpm = 16'd0;
        bpm_valid = 1'b0;
        interval_ms = 16'd0;
        ms_divider_count = 16'd0;
        elapsed_ms = 16'd0;
        timing_active = 1'b0;
        pending_interval = 16'd0;
        division_pending = 1'b0;
        divider_start = 1'b0;
    end

    always @(posedge clk) begin
        divider_start <= 1'b0;

        if (reset) begin
            bpm <= 16'd0;
            bpm_valid <= 1'b0;
            interval_ms <= 16'd0;
            ms_divider_count <= 16'd0;
            elapsed_ms <= 16'd0;
            timing_active <= 1'b0;
            pending_interval <= 16'd0;
            division_pending <= 1'b0;
        end else begin
            if (ms_tick) begin
                ms_divider_count <= 16'd0;
                if (timing_active && (elapsed_ms != 16'hffff))
                    elapsed_ms <= elapsed_ms + 16'd1;
            end else begin
                ms_divider_count <= ms_divider_count + 16'd1;
            end

            if (beat_pulse) begin
                if (!timing_active) begin
                    timing_active <= 1'b1;
                end else begin
                    interval_ms <= elapsed_at_beat[15:0];
                    if ((elapsed_at_beat >= {1'b0, MIN_INTERVAL_MS}) &&
                        (elapsed_at_beat <= {1'b0, MAX_INTERVAL_MS})) begin
                        pending_interval <= elapsed_at_beat[15:0];
                        division_pending <= 1'b1;
                    end
                end
                elapsed_ms <= 16'd0;
            end

            if (division_pending && !divider_busy) begin
                divider_start <= 1'b1;
                division_pending <= 1'b0;
            end

            if (divider_done) begin
                if (!bpm_valid) begin
                    bpm <= divider_quotient;
                end else if (divider_quotient >= bpm) begin
                    bpm <= bpm + ((divider_quotient - bpm) >> 2);
                end else begin
                    bpm <= bpm - ((bpm - divider_quotient) >> 2);
                end
                bpm_valid <= 1'b1;
            end
        end
    end

endmodule

`default_nettype wire
