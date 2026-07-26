`default_nettype none

module uart_tx #(
    parameter integer CLK_HZ = 27000000,
    parameter integer BAUD_RATE = 115200
) (
    input  wire       clk,
    input  wire       start,
    input  wire [7:0] data,
    output reg        busy,
    output reg        tx
);

    localparam integer CLKS_PER_BIT = CLK_HZ / BAUD_RATE;

    reg [7:0] data_shift;
    reg [8:0] baud_counter;
    reg [3:0] bit_index;

    initial begin
        data_shift = 8'd0;
        baud_counter = 9'd0;
        bit_index = 4'd0;
        busy = 1'b0;
        tx = 1'b1;
    end

    always @(posedge clk) begin
        if (!busy) begin
            tx <= 1'b1;
            baud_counter <= 9'd0;
            bit_index <= 4'd0;

            if (start) begin
                busy <= 1'b1;
                data_shift <= data;
                tx <= 1'b0;
            end
        end else begin
            if (baud_counter == CLKS_PER_BIT - 1) begin
                baud_counter <= 9'd0;

                if (bit_index < 4'd8) begin
                    tx <= data_shift[0];
                    data_shift <= {1'b0, data_shift[7:1]};
                    bit_index <= bit_index + 4'd1;
                end else if (bit_index == 4'd8) begin
                    tx <= 1'b1;
                    bit_index <= bit_index + 4'd1;
                end else begin
                    busy <= 1'b0;
                    bit_index <= 4'd0;
                end
            end else begin
                baud_counter <= baud_counter + 9'd1;
            end
        end
    end

endmodule

`default_nettype wire
