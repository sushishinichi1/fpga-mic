`default_nettype none

module spi_master #(
    parameter integer CLK_DIV = 27
) (
    input  wire       clk,
    input  wire       reset,
    input  wire       start,
    input  wire [7:0] tx_data,

    output reg  [7:0] rx_data,
    output reg        busy,
    output reg        done,

    output reg        spi_sclk,
    output reg        spi_mosi,
    input  wire       spi_miso,
    output reg        spi_cs_n
);

    reg [7:0] tx_shift;
    reg [7:0] rx_shift;
    reg [4:0] clk_counter;
    reg [3:0] bit_index;

    initial begin
        rx_data = 8'h00;
        busy = 1'b0;
        done = 1'b0;
        spi_sclk = 1'b0;
        spi_mosi = 1'b0;
        spi_cs_n = 1'b1;
        tx_shift = 8'h00;
        rx_shift = 8'h00;
        clk_counter = 5'd0;
        bit_index = 4'd0;
    end

    always @(posedge clk) begin
        done <= 1'b0;

        if (reset) begin
            rx_data <= 8'h00;
            busy <= 1'b0;
            spi_sclk <= 1'b0;
            spi_mosi <= 1'b0;
            spi_cs_n <= 1'b1;
            tx_shift <= 8'h00;
            rx_shift <= 8'h00;
            clk_counter <= 5'd0;
            bit_index <= 4'd0;
        end else if (!busy) begin
            spi_sclk <= 1'b0;
            spi_cs_n <= 1'b1;
            clk_counter <= 5'd0;

            if (start) begin
                busy <= 1'b1;
                spi_cs_n <= 1'b0;
                tx_shift <= tx_data;
                rx_shift <= 8'h00;
                spi_mosi <= tx_data[7];
                bit_index <= 4'd7;
            end
        end else begin
            if (clk_counter == CLK_DIV - 1) begin
                clk_counter <= 5'd0;

                if (spi_sclk == 1'b0) begin
                    spi_sclk <= 1'b1;
                    rx_shift[bit_index] <= spi_miso;

                    if (bit_index == 4'd0) begin
                        rx_data <= {rx_shift[7:1], spi_miso};
                        busy <= 1'b0;
                        done <= 1'b1;
                        spi_cs_n <= 1'b1;
                        spi_sclk <= 1'b0;
                    end
                end else begin
                    spi_sclk <= 1'b0;
                    if (bit_index != 4'd0) begin
                        bit_index <= bit_index - 4'd1;
                        spi_mosi <= tx_shift[bit_index - 4'd1];
                    end
                end
            end else begin
                clk_counter <= clk_counter + 5'd1;
            end
        end
    end

endmodule

`default_nettype wire
