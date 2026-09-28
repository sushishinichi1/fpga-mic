`default_nettype none

// Unsigned 16-bit restoring divider. One quotient bit is produced per clock.
module bpm_divider (
    input  wire        clk,
    input  wire        reset,
    input  wire        start,
    input  wire [15:0] dividend,
    input  wire [15:0] divisor,
    output reg  [15:0] quotient,
    output reg         busy,
    output reg         done
);

    reg [15:0] quotient_work;
    reg [16:0] remainder;
    reg [15:0] divisor_latched;
    reg [4:0]  bit_count;

    wire [16:0] shifted_remainder = {remainder[15:0], quotient_work[15]};
    wire        subtract_enable = shifted_remainder >= {1'b0, divisor_latched};
    wire [16:0] next_remainder = subtract_enable ?
        shifted_remainder - {1'b0, divisor_latched} : shifted_remainder;
    wire [15:0] next_quotient = {quotient_work[14:0], subtract_enable};

    initial begin
        quotient = 16'd0;
        quotient_work = 16'd0;
        remainder = 17'd0;
        divisor_latched = 16'd1;
        bit_count = 5'd0;
        busy = 1'b0;
        done = 1'b0;
    end

    always @(posedge clk) begin
        done <= 1'b0;

        if (reset) begin
            quotient <= 16'd0;
            quotient_work <= 16'd0;
            remainder <= 17'd0;
            divisor_latched <= 16'd1;
            bit_count <= 5'd0;
            busy <= 1'b0;
        end else if (start && !busy) begin
            if (divisor == 16'd0) begin
                quotient <= 16'hffff;
                done <= 1'b1;
            end else begin
                quotient_work <= dividend;
                remainder <= 17'd0;
                divisor_latched <= divisor;
                bit_count <= 5'd0;
                busy <= 1'b1;
            end
        end else if (busy) begin
            quotient_work <= next_quotient;
            remainder <= next_remainder;

            if (bit_count == 5'd15) begin
                quotient <= next_quotient;
                busy <= 1'b0;
                done <= 1'b1;
            end else begin
                bit_count <= bit_count + 5'd1;
            end
        end
    end

endmodule

`default_nettype wire
