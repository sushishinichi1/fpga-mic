`default_nettype none

module fft_hann_window (
    input  wire               clk,
    input  wire signed [17:0] sample_in,
    input  wire               sample_valid_in,
    input  wire [7:0]         sample_index,
    output reg signed [17:0]  sample_out,
    output reg                sample_valid_out
);

    reg signed [17:0] sample_reg;
    reg signed [15:0] coefficient;
    reg                    valid_reg;
    reg signed [15:0] coefficients [0:127];

    wire [7:0] mirrored_index = (sample_index < 8'd128) ?
                                sample_index : (8'd255 - sample_index);
    wire signed [33:0] window_product = sample_reg * coefficient;
    wire signed [33:0] scaled_product = window_product >>> 15;

    // Store one half because the 256-point Hann window is symmetric.
    initial begin
        coefficients[0] = 16'sd0;
        coefficients[1] = 16'sd5;
        coefficients[2] = 16'sd20;
        coefficients[3] = 16'sd45;
        coefficients[4] = 16'sd80;
        coefficients[5] = 16'sd124;
        coefficients[6] = 16'sd179;
        coefficients[7] = 16'sd243;
        coefficients[8] = 16'sd317;
        coefficients[9] = 16'sd401;
        coefficients[10] = 16'sd495;
        coefficients[11] = 16'sd598;
        coefficients[12] = 16'sd711;
        coefficients[13] = 16'sd833;
        coefficients[14] = 16'sd965;
        coefficients[15] = 16'sd1106;
        coefficients[16] = 16'sd1257;
        coefficients[17] = 16'sd1416;
        coefficients[18] = 16'sd1585;
        coefficients[19] = 16'sd1763;
        coefficients[20] = 16'sd1949;
        coefficients[21] = 16'sd2145;
        coefficients[22] = 16'sd2349;
        coefficients[23] = 16'sd2561;
        coefficients[24] = 16'sd2782;
        coefficients[25] = 16'sd3011;
        coefficients[26] = 16'sd3249;
        coefficients[27] = 16'sd3494;
        coefficients[28] = 16'sd3747;
        coefficients[29] = 16'sd4008;
        coefficients[30] = 16'sd4276;
        coefficients[31] = 16'sd4552;
        coefficients[32] = 16'sd4834;
        coefficients[33] = 16'sd5124;
        coefficients[34] = 16'sd5421;
        coefficients[35] = 16'sd5724;
        coefficients[36] = 16'sd6034;
        coefficients[37] = 16'sd6350;
        coefficients[38] = 16'sd6672;
        coefficients[39] = 16'sd7000;
        coefficients[40] = 16'sd7334;
        coefficients[41] = 16'sd7673;
        coefficients[42] = 16'sd8018;
        coefficients[43] = 16'sd8367;
        coefficients[44] = 16'sd8722;
        coefficients[45] = 16'sd9081;
        coefficients[46] = 16'sd9444;
        coefficients[47] = 16'sd9812;
        coefficients[48] = 16'sd10184;
        coefficients[49] = 16'sd10559;
        coefficients[50] = 16'sd10938;
        coefficients[51] = 16'sd11321;
        coefficients[52] = 16'sd11706;
        coefficients[53] = 16'sd12094;
        coefficients[54] = 16'sd12485;
        coefficients[55] = 16'sd12879;
        coefficients[56] = 16'sd13274;
        coefficients[57] = 16'sd13671;
        coefficients[58] = 16'sd14070;
        coefficients[59] = 16'sd14470;
        coefficients[60] = 16'sd14872;
        coefficients[61] = 16'sd15274;
        coefficients[62] = 16'sd15677;
        coefficients[63] = 16'sd16081;
        coefficients[64] = 16'sd16484;
        coefficients[65] = 16'sd16888;
        coefficients[66] = 16'sd17291;
        coefficients[67] = 16'sd17694;
        coefficients[68] = 16'sd18096;
        coefficients[69] = 16'sd18497;
        coefficients[70] = 16'sd18897;
        coefficients[71] = 16'sd19295;
        coefficients[72] = 16'sd19691;
        coefficients[73] = 16'sd20085;
        coefficients[74] = 16'sd20477;
        coefficients[75] = 16'sd20867;
        coefficients[76] = 16'sd21254;
        coefficients[77] = 16'sd21638;
        coefficients[78] = 16'sd22019;
        coefficients[79] = 16'sd22396;
        coefficients[80] = 16'sd22770;
        coefficients[81] = 16'sd23139;
        coefficients[82] = 16'sd23505;
        coefficients[83] = 16'sd23866;
        coefficients[84] = 16'sd24223;
        coefficients[85] = 16'sd24575;
        coefficients[86] = 16'sd24922;
        coefficients[87] = 16'sd25264;
        coefficients[88] = 16'sd25601;
        coefficients[89] = 16'sd25932;
        coefficients[90] = 16'sd26257;
        coefficients[91] = 16'sd26576;
        coefficients[92] = 16'sd26889;
        coefficients[93] = 16'sd27195;
        coefficients[94] = 16'sd27495;
        coefficients[95] = 16'sd27789;
        coefficients[96] = 16'sd28075;
        coefficients[97] = 16'sd28354;
        coefficients[98] = 16'sd28626;
        coefficients[99] = 16'sd28891;
        coefficients[100] = 16'sd29148;
        coefficients[101] = 16'sd29397;
        coefficients[102] = 16'sd29638;
        coefficients[103] = 16'sd29871;
        coefficients[104] = 16'sd30096;
        coefficients[105] = 16'sd30313;
        coefficients[106] = 16'sd30521;
        coefficients[107] = 16'sd30721;
        coefficients[108] = 16'sd30912;
        coefficients[109] = 16'sd31094;
        coefficients[110] = 16'sd31267;
        coefficients[111] = 16'sd31432;
        coefficients[112] = 16'sd31587;
        coefficients[113] = 16'sd31732;
        coefficients[114] = 16'sd31869;
        coefficients[115] = 16'sd31996;
        coefficients[116] = 16'sd32114;
        coefficients[117] = 16'sd32222;
        coefficients[118] = 16'sd32320;
        coefficients[119] = 16'sd32409;
        coefficients[120] = 16'sd32488;
        coefficients[121] = 16'sd32557;
        coefficients[122] = 16'sd32617;
        coefficients[123] = 16'sd32666;
        coefficients[124] = 16'sd32706;
        coefficients[125] = 16'sd32736;
        coefficients[126] = 16'sd32756;
        coefficients[127] = 16'sd32766;
        sample_reg = 18'sd0;
        coefficient = 16'sd0;
        valid_reg = 1'b0;
        sample_out = 18'sd0;
        sample_valid_out = 1'b0;
    end

    always @(posedge clk) begin
        sample_reg <= sample_in;
        coefficient <= coefficients[mirrored_index[6:0]];
        valid_reg <= sample_valid_in;
        sample_valid_out <= valid_reg;

        if (valid_reg)
            sample_out <= scaled_product[17:0];
    end

endmodule

`default_nettype wire
