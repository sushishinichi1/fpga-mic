`default_nettype none

module audio_fft_analyzer #(
    parameter integer ENABLE_HANN = 1
 ) (
    input  wire               clk,
    input  wire signed [23:0] sample,
    input  wire               sample_valid,
    output wire               busy,
    output wire               peak_valid,
    output wire [7:0]         peak_bin,
    output wire [36:0]        peak_power,
    output wire [255:0]       spectrum,
    output wire [38:0]        beat_energy
);

    reg [7:0] sample_index;
    reg       load_we;
    reg [7:0] load_addr;
    reg signed [17:0] load_data;
    reg       fft_start;
    wire      fft_busy;
    wire      fft_done;
    wire signed [17:0] windowed_sample;
    wire               windowed_sample_valid;

    function [7:0] reverse_bits;
        input [7:0] value;
        integer index;
        begin
            for (index = 0; index < 8; index = index + 1)
                reverse_bits[index] = value[7-index];
        end
    endfunction

    assign busy = fft_busy;
    assign peak_valid = fft_done;

    generate
        if (ENABLE_HANN != 0) begin : generate_hann_window
            fft_hann_window hann_window_inst (
                .clk(clk),
                .sample_in(sample[23:6]),
                .sample_valid_in(sample_valid && !fft_busy),
                .sample_index(sample_index),
                .sample_out(windowed_sample),
                .sample_valid_out(windowed_sample_valid)
            );
        end else begin : generate_rectangular_window
            assign windowed_sample = sample[23:6];
            assign windowed_sample_valid = sample_valid && !fft_busy;
        end
    endgenerate

    fft_core_iterative fft_core_inst (
        .clk(clk),
        .load_we(load_we),
        .load_addr(load_addr),
        .load_data(load_data),
        .start(fft_start),
        .busy(fft_busy),
        .done(fft_done),
        .peak_bin(peak_bin),
        .peak_power(peak_power),
        .spectrum(spectrum),
        .beat_energy(beat_energy)
    );

    initial begin
        sample_index = 8'd0;
        load_we = 1'b0;
        load_addr = 8'd0;
        load_data = 18'sd0;
        fft_start = 1'b0;
    end

    always @(posedge clk) begin
        load_we <= 1'b0;
        fft_start <= 1'b0;

        if (!fft_busy && windowed_sample_valid) begin
            load_we <= 1'b1;
            load_addr <= reverse_bits(sample_index);
            load_data <= windowed_sample;

            if (sample_index == 8'd255) begin
                sample_index <= 8'd0;
                fft_start <= 1'b1;
            end else begin
                sample_index <= sample_index + 8'd1;
            end
        end
    end

endmodule

`default_nettype wire
