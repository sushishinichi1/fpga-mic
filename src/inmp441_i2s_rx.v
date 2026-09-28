`default_nettype none

module inmp441_i2s_rx (
    input  wire        clk,
    input  wire        mic_sd,
    output reg         mic_sck,
    output reg         mic_ws,
    output wire        mic_lr,
    output reg signed [23:0] sample,
    output reg         sample_valid
);

    // 27 MHz / (2 * 6) = 2.25 MHz.
    // With 64 SCK clocks per stereo frame, the sample rate is about 35.16 kHz.
    localparam [3:0] SCK_DIV_MAX = 4'd5;

    reg [3:0]  sck_div;
    reg [5:0]  bit_pos;
    reg [23:0] shift_reg;

    wire [23:0] next_sample = {shift_reg[22:0], mic_sd};

    // INMP441 selects the left channel when L/R is low.
    assign mic_lr = 1'b0;

    initial begin
        mic_sck = 1'b0;
        mic_ws = 1'b0;
        sample = 24'sd0;
        sample_valid = 1'b0;
        sck_div = 4'd0;
        bit_pos = 6'd0;
        shift_reg = 24'd0;
    end

    always @(posedge clk) begin
        sample_valid <= 1'b0;

        if (sck_div == SCK_DIV_MAX) begin
            sck_div <= 4'd0;
            mic_sck <= ~mic_sck;

            // INMP441 uses Philips I2S. The receiver samples SD on SCK rising
            // edges. The MSB is valid one SCK after the WS transition.
            if (mic_sck == 1'b0) begin
                if ((mic_ws == 1'b0) && (bit_pos >= 6'd1) && (bit_pos <= 6'd24)) begin
                    shift_reg <= next_sample;

                    // Only the first 24 bits in the 32-bit left-channel slot
                    // are audio data. The remaining 8 bits are ignored.
                    if (bit_pos == 6'd24) begin
                        sample <= next_sample;
                        sample_valid <= 1'b1;
                    end
                end
            end

            // WS changes on SCK falling edges, after each 32-bit slot.
            if (mic_sck == 1'b1) begin
                if (bit_pos == 6'd31) begin
                    bit_pos <= 6'd0;
                    mic_ws <= ~mic_ws;
                end else begin
                    bit_pos <= bit_pos + 6'd1;
                end
            end
        end else begin
            sck_div <= sck_div + 4'd1;
        end
    end

endmodule

`default_nettype wire
