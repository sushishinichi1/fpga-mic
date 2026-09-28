`default_nettype none

module fft_data_ram (
    input  wire               clk,
    input  wire               we,
    input  wire [7:0]         addr,
    input  wire signed [17:0] din,
    output reg  signed [17:0] dout
);

    // A synchronous, single-port memory description suitable for BSRAM inference.
    reg signed [17:0] memory [0:255];

    always @(posedge clk) begin
        if (we)
            memory[addr] <= din;
        else
            dout <= memory[addr];
    end

endmodule

`default_nettype wire
