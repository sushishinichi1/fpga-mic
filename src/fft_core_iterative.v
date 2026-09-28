`default_nettype none

module fft_core_iterative (
    input  wire               clk,
    input  wire               load_we,
    input  wire [7:0]         load_addr,
    input  wire signed [17:0] load_data,
    input  wire               start,
    output reg                busy,
    output reg                done,
    output reg  [7:0]         peak_bin,
    output reg  [36:0]        peak_power,
    output reg  [255:0]       spectrum,
    output reg  [38:0]        beat_energy
);

    localparam [3:0] ST_IDLE       = 4'd0;
    localparam [3:0] ST_SET_A      = 4'd1;
    localparam [3:0] ST_SET_B      = 4'd2;
    localparam [3:0] ST_EXECUTE    = 4'd3;
    localparam [3:0] ST_WRITE_A    = 4'd4;
    localparam [3:0] ST_WRITE_B    = 4'd5;
    localparam [3:0] ST_SCAN_SET   = 4'd6;
    localparam [3:0] ST_SCAN_CHECK = 4'd7;
    localparam [3:0] ST_FINISH     = 4'd8;
    localparam [3:0] ST_COMPRESS   = 4'd9;
    localparam [3:0] ST_BAND_WRITE = 4'd10;

    reg [3:0] state;
    reg [2:0] stage;
    reg [6:0] butterfly_index;
    reg [7:0] address_a;
    reg [7:0] address_b;
    reg [7:0] scan_bin;
    reg [4:0] spectrum_band_index;
    reg [36:0] spectrum_band_max;
    reg [36:0] spectrum_compress_input;
    reg [7:0] spectrum_compressed_value;
    reg [38:0] beat_energy_accum;

    reg signed [17:0] a_real_reg;
    reg signed [17:0] a_imag_reg;
    reg signed [17:0] result_a_real;
    reg signed [17:0] result_a_imag;
    reg signed [17:0] result_b_real;
    reg signed [17:0] result_b_imag;

    reg                ram_we;
    reg [7:0]          ram_addr;
    reg signed [17:0]  ram_real_in;
    reg signed [17:0]  ram_imag_in;
    wire signed [17:0] ram_real_out;
    wire signed [17:0] ram_imag_out;

    wire [7:0] group_index = {1'b0, butterfly_index} >> stage;
    wire [7:0] position_mask = (8'd1 << stage) - 8'd1;
    wire [7:0] position_in_group = {1'b0, butterfly_index} & position_mask;
    wire [7:0] calculated_a = (group_index << (stage + 1'b1)) + position_in_group;
    wire [7:0] calculated_b = calculated_a + (8'd1 << stage);
    wire [7:0] twiddle_addr_full = position_in_group << (3'd7 - stage);
    wire [6:0] twiddle_addr = twiddle_addr_full[6:0];
    wire signed [15:0] twiddle_real;
    wire signed [15:0] twiddle_imag;

    wire signed [17:0] butterfly_a_real;
    wire signed [17:0] butterfly_a_imag;
    wire signed [17:0] butterfly_b_real;
    wire signed [17:0] butterfly_b_imag;
    wire [36:0] scan_power;
    wire [36:0] spectrum_candidate =
        (scan_power > spectrum_band_max) ? scan_power : spectrum_band_max;

    // Inclusive upper FFT bin for each non-uniform display band.
    function [7:0] spectrum_band_end;
        input [4:0] band_index;
        begin
            case (band_index)
                5'd0:  spectrum_band_end = 8'd1;
                5'd1:  spectrum_band_end = 8'd2;
                5'd2:  spectrum_band_end = 8'd3;
                5'd3:  spectrum_band_end = 8'd4;
                5'd4:  spectrum_band_end = 8'd5;
                5'd5:  spectrum_band_end = 8'd6;
                5'd6:  spectrum_band_end = 8'd7;
                5'd7:  spectrum_band_end = 8'd8;
                5'd8:  spectrum_band_end = 8'd10;
                5'd9:  spectrum_band_end = 8'd12;
                5'd10: spectrum_band_end = 8'd14;
                5'd11: spectrum_band_end = 8'd16;
                5'd12: spectrum_band_end = 8'd18;
                5'd13: spectrum_band_end = 8'd20;
                5'd14: spectrum_band_end = 8'd22;
                5'd15: spectrum_band_end = 8'd24;
                5'd16: spectrum_band_end = 8'd28;
                5'd17: spectrum_band_end = 8'd32;
                5'd18: spectrum_band_end = 8'd36;
                5'd19: spectrum_band_end = 8'd40;
                5'd20: spectrum_band_end = 8'd44;
                5'd21: spectrum_band_end = 8'd48;
                5'd22: spectrum_band_end = 8'd52;
                5'd23: spectrum_band_end = 8'd56;
                5'd24: spectrum_band_end = 8'd65;
                5'd25: spectrum_band_end = 8'd74;
                5'd26: spectrum_band_end = 8'd83;
                5'd27: spectrum_band_end = 8'd92;
                5'd28: spectrum_band_end = 8'd101;
                5'd29: spectrum_band_end = 8'd110;
                5'd30: spectrum_band_end = 8'd119;
                default: spectrum_band_end = 8'd127;
            endcase
        end
    endfunction

    function [7:0] compress_power;
        input [36:0] power_value;
        integer bit_index;
        reg [5:0] msb_position;
        reg [5:0] exponent_code;
        reg [2:0] mantissa;
        reg [36:0] shifted_power;
        begin
            msb_position = 6'd0;
            shifted_power = 37'd0;
            for (bit_index = 0; bit_index < 37; bit_index = bit_index + 1) begin
                if (power_value[bit_index])
                    msb_position = bit_index;
            end

            if (power_value == 37'd0) begin
                compress_power = 8'd0;
            end else if (msb_position >= 6'd31) begin
                compress_power = 8'd255;
            end else begin
                exponent_code = msb_position + 6'd1;
                if (msb_position >= 6'd3)
                    shifted_power = power_value >> (msb_position - 6'd3);
                else
                    shifted_power = power_value << (6'd3 - msb_position);
                mantissa = shifted_power[2:0];
                compress_power = {exponent_code[4:0], mantissa};
            end
        end
    endfunction

    fft_data_ram real_ram_inst (
        .clk(clk), .we(ram_we), .addr(ram_addr),
        .din(ram_real_in), .dout(ram_real_out)
    );

    fft_data_ram imag_ram_inst (
        .clk(clk), .we(ram_we), .addr(ram_addr),
        .din(ram_imag_in), .dout(ram_imag_out)
    );

    fft_twiddle_rom twiddle_rom_inst (
        .clk(clk), .addr(twiddle_addr),
        .twiddle_real(twiddle_real), .twiddle_imag(twiddle_imag)
    );

    fft_butterfly butterfly_inst (
        .a_real(a_real_reg), .a_imag(a_imag_reg),
        .b_real(ram_real_out), .b_imag(ram_imag_out),
        .twiddle_real(twiddle_real), .twiddle_imag(twiddle_imag),
        .out_a_real(butterfly_a_real), .out_a_imag(butterfly_a_imag),
        .out_b_real(butterfly_b_real), .out_b_imag(butterfly_b_imag)
    );

    fft_magnitude magnitude_inst (
        .real_value(ram_real_out),
        .imag_value(ram_imag_out),
        .power(scan_power)
    );

    always @(*) begin
        ram_we = 1'b0;
        ram_addr = 8'd0;
        ram_real_in = 18'sd0;
        ram_imag_in = 18'sd0;

        if (state == ST_IDLE) begin
            ram_we = load_we;
            ram_addr = load_addr;
            ram_real_in = load_data;
        end else if (state == ST_SET_A) begin
            ram_addr = calculated_a;
        end else if (state == ST_SET_B) begin
            ram_addr = calculated_b;
        end else if (state == ST_EXECUTE) begin
            ram_addr = address_b;
        end else if (state == ST_WRITE_A) begin
            ram_we = 1'b1;
            ram_addr = address_a;
            ram_real_in = result_a_real;
            ram_imag_in = result_a_imag;
        end else if (state == ST_WRITE_B) begin
            ram_we = 1'b1;
            ram_addr = address_b;
            ram_real_in = result_b_real;
            ram_imag_in = result_b_imag;
        end else if ((state == ST_SCAN_SET) || (state == ST_SCAN_CHECK)) begin
            ram_addr = scan_bin;
        end
    end

    initial begin
        state = ST_IDLE;
        stage = 3'd0;
        butterfly_index = 7'd0;
        address_a = 8'd0;
        address_b = 8'd0;
        scan_bin = 8'd1;
        spectrum_band_index = 5'd0;
        spectrum_band_max = 37'd0;
        spectrum_compress_input = 37'd0;
        spectrum_compressed_value = 8'd0;
        beat_energy_accum = 39'd0;
        a_real_reg = 18'sd0;
        a_imag_reg = 18'sd0;
        result_a_real = 18'sd0;
        result_a_imag = 18'sd0;
        result_b_real = 18'sd0;
        result_b_imag = 18'sd0;
        busy = 1'b0;
        done = 1'b0;
        peak_bin = 8'd0;
        peak_power = 37'd0;
        spectrum = 256'd0;
        beat_energy = 39'd0;
    end

    always @(posedge clk) begin
        done <= 1'b0;

        case (state)
            ST_IDLE: begin
                busy <= 1'b0;
                if (start) begin
                    busy <= 1'b1;
                    stage <= 3'd0;
                    butterfly_index <= 7'd0;
                    state <= ST_SET_A;
                end
            end

            ST_SET_A: begin
                address_a <= calculated_a;
                address_b <= calculated_b;
                state <= ST_SET_B;
            end

            ST_SET_B: begin
                a_real_reg <= ram_real_out;
                a_imag_reg <= ram_imag_out;
                state <= ST_EXECUTE;
            end

            ST_EXECUTE: begin
                result_a_real <= butterfly_a_real;
                result_a_imag <= butterfly_a_imag;
                result_b_real <= butterfly_b_real;
                result_b_imag <= butterfly_b_imag;
                state <= ST_WRITE_A;
            end

            ST_WRITE_A: begin
                state <= ST_WRITE_B;
            end

            ST_WRITE_B: begin
                if (butterfly_index == 7'd127) begin
                    butterfly_index <= 7'd0;
                    if (stage == 3'd7) begin
                        scan_bin <= 8'd1;
                        peak_bin <= 8'd1;
                        peak_power <= 37'd0;
                        spectrum <= 256'd0;
                        spectrum_band_index <= 5'd0;
                        spectrum_band_max <= 37'd0;
                        beat_energy_accum <= 39'd0;
                        state <= ST_SCAN_SET;
                    end else begin
                        stage <= stage + 3'd1;
                        state <= ST_SET_A;
                    end
                end else begin
                    butterfly_index <= butterfly_index + 7'd1;
                    state <= ST_SET_A;
                end
            end

            ST_SCAN_SET: begin
                state <= ST_SCAN_CHECK;
            end

            ST_SCAN_CHECK: begin
                if (scan_power > peak_power) begin
                    peak_power <= scan_power;
                    peak_bin <= scan_bin;
                end

                if ((scan_bin >= 8'd1) && (scan_bin <= 8'd3)) begin
                    beat_energy_accum <= beat_energy_accum + {2'd0, scan_power};
                    if (scan_bin == 8'd3)
                        beat_energy <= beat_energy_accum + {2'd0, scan_power};
                end

                if (scan_bin == spectrum_band_end(spectrum_band_index)) begin
                    spectrum_compress_input <= spectrum_candidate;
                    state <= ST_COMPRESS;
                end else begin
                    spectrum_band_max <= spectrum_candidate;
                    scan_bin <= scan_bin + 8'd1;
                    state <= ST_SCAN_SET;
                end
            end

            ST_COMPRESS: begin
                spectrum_compressed_value <= compress_power(spectrum_compress_input);
                state <= ST_BAND_WRITE;
            end

            ST_BAND_WRITE: begin
                spectrum[(spectrum_band_index * 8) +: 8] <= spectrum_compressed_value;
                spectrum_band_max <= 37'd0;
                spectrum_band_index <= spectrum_band_index + 5'd1;

                if (scan_bin == 8'd127)
                    state <= ST_FINISH;
                else begin
                    scan_bin <= scan_bin + 8'd1;
                    state <= ST_SCAN_SET;
                end
            end

            ST_FINISH: begin
                busy <= 1'b0;
                done <= 1'b1;
                state <= ST_IDLE;
            end

            default: state <= ST_IDLE;
        endcase
    end

endmodule

`default_nettype wire
