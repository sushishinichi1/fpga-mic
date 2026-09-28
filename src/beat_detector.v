`default_nettype none

module beat_detector #(
    parameter integer BASELINE_SHIFT = 5,
    parameter [15:0] WARMUP_FRAMES = 16'd32,
    parameter [15:0] REFRACTORY_FRAMES = 16'd26
) (
    input  wire        clk,
    input  wire        reset,
    input  wire        frame_valid,
    input  wire [38:0] beat_energy,
    output reg         beat_pulse,
    output reg  [15:0] beat_count
);

    reg [38:0] baseline;
    reg [15:0] warmup_count;
    reg [15:0] refractory_count;
    reg        previous_above_threshold;

    wire [39:0] threshold = {1'b0, baseline} + ({1'b0, baseline} >> 1);
    wire above_threshold = {1'b0, beat_energy} > threshold;
    wire [38:0] rising_delta = beat_energy - baseline;
    wire [38:0] falling_delta = baseline - beat_energy;

    initial begin
        baseline = 39'd0;
        warmup_count = 16'd0;
        refractory_count = 16'd0;
        previous_above_threshold = 1'b0;
        beat_pulse = 1'b0;
        beat_count = 16'd0;
    end

    always @(posedge clk) begin
        beat_pulse <= 1'b0;

        if (reset) begin
            baseline <= 39'd0;
            warmup_count <= 16'd0;
            refractory_count <= 16'd0;
            previous_above_threshold <= 1'b0;
            beat_count <= 16'd0;
        end else if (frame_valid) begin
            if (warmup_count == 16'd0) begin
                baseline <= beat_energy;
            end else if (beat_energy >= baseline) begin
                baseline <= baseline + (rising_delta >> BASELINE_SHIFT);
            end else begin
                baseline <= baseline - (falling_delta >> BASELINE_SHIFT);
            end

            if (warmup_count < WARMUP_FRAMES) begin
                warmup_count <= warmup_count + 16'd1;
                refractory_count <= 16'd0;
                previous_above_threshold <= 1'b0;
            end else begin
                if (refractory_count != 16'd0)
                    refractory_count <= refractory_count - 16'd1;

                if (above_threshold && !previous_above_threshold &&
                    (refractory_count == 16'd0)) begin
                    beat_pulse <= 1'b1;
                    beat_count <= beat_count + 16'd1;
                    refractory_count <= REFRACTORY_FRAMES;
                end

                previous_above_threshold <= above_threshold;
            end
        end
    end

endmodule

`default_nettype wire
