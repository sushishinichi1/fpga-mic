`default_nettype none

module fft_butterfly (
    input  wire signed [17:0] a_real,
    input  wire signed [17:0] a_imag,
    input  wire signed [17:0] b_real,
    input  wire signed [17:0] b_imag,
    input  wire signed [15:0] twiddle_real,
    input  wire signed [15:0] twiddle_imag,
    output wire signed [17:0] out_a_real,
    output wire signed [17:0] out_a_imag,
    output wire signed [17:0] out_b_real,
    output wire signed [17:0] out_b_imag
);

    // Multiplication operators are kept explicit so synthesis can use DSP blocks.
    wire signed [33:0] product_rr = b_real * twiddle_real;
    wire signed [33:0] product_ii = b_imag * twiddle_imag;
    wire signed [33:0] product_ri = b_real * twiddle_imag;
    wire signed [33:0] product_ir = b_imag * twiddle_real;

    wire signed [34:0] rotated_real_full =
        {{1{product_rr[33]}}, product_rr} - {{1{product_ii[33]}}, product_ii};
    wire signed [34:0] rotated_imag_full =
        {{1{product_ri[33]}}, product_ri} + {{1{product_ir[33]}}, product_ir};

    wire signed [18:0] rotated_real = rotated_real_full[33:15];
    wire signed [18:0] rotated_imag = rotated_imag_full[33:15];
    wire signed [18:0] a_real_ext = {a_real[17], a_real};
    wire signed [18:0] a_imag_ext = {a_imag[17], a_imag};

    // Divide every butterfly output by two. Eight stages give 1/256 scaling.
    assign out_a_real = (a_real_ext + rotated_real) >>> 1;
    assign out_a_imag = (a_imag_ext + rotated_imag) >>> 1;
    assign out_b_real = (a_real_ext - rotated_real) >>> 1;
    assign out_b_imag = (a_imag_ext - rotated_imag) >>> 1;

endmodule

`default_nettype wire
