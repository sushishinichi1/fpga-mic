`default_nettype none

module top (
    input  wire clk,
    input  wire button,
    output wire led0,
    output wire uart_tx
);

    localparam integer CLK_HZ = 27000000;
    localparam integer DEBOUNCE_MS = 20;
    localparam integer UART_BAUD = 115200;

    wire button_pressed;
    wire [31:0] press_count;
    wire sender_busy;

    button_debounce #(
        .CLK_HZ(CLK_HZ),
        .DEBOUNCE_MS(DEBOUNCE_MS)
    ) button_debounce_inst (
        .clk(clk),
        .button_n(button),
        .press_pulse(button_pressed)
    );

    press_counter press_counter_inst (
        .clk(clk),
        .increment(button_pressed),
        .count(press_count)
    );

    count_uart_sender #(
        .CLK_HZ(CLK_HZ),
        .BAUD_RATE(UART_BAUD)
    ) count_uart_sender_inst (
        .clk(clk),
        .start(button_pressed),
        .count_value(press_count + 32'd1),
        .busy(sender_busy),
        .uart_tx(uart_tx)
    );

    // LED0 is active low. The LED mirrors the counter LSB after each valid press.
    assign led0 = ~press_count[0];

endmodule

`default_nettype wire
