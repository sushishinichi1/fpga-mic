`default_nettype none

module fft_magnitude (
    input  wire signed [17:0] real_value,
    input  wire signed [17:0] imag_value,
    output wire        [36:0] power
);

    wire signed [35:0] real_square = real_value * real_value;
    wire signed [35:0] imag_square = imag_value * imag_value;

    assign power = {1'b0, real_square} + {1'b0, imag_square};

endmodule

`default_nettype wire
