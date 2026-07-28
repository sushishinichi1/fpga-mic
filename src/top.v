`default_nettype none

module top (
    input  wire clk,
    input  wire button,
    input  wire uart_rx,
    output wire led0,
    output wire uart_tx
);

    localparam integer CLK_HZ = 27000000;
    localparam integer DEBOUNCE_MS = 20;
    localparam integer UART_BAUD = 115200;

    wire button_pressed;
    wire [31:0] press_count;
    wire sender_busy;
    wire count_uart_tx;
    wire rx_valid;
    wire [7:0] rx_data;
    wire reg_req;
    wire reg_write;
    wire [7:0] reg_addr;
    wire [31:0] reg_wdata;
    wire [31:0] reg_rdata;
    wire reg_ready;
    wire reg_error;
    wire counter_reset_pulse;
    wire led_on;
    wire [7:0] led_pwm_duty;
    wire command_busy;
    wire command_tx_active;
    wire command_uart_tx;

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
        .reset(counter_reset_pulse),
        .increment(button_pressed),
        .count(press_count)
    );

    uart_rx #(
        .CLK_HZ(CLK_HZ),
        .BAUD_RATE(UART_BAUD)
    ) uart_rx_inst (
        .clk(clk),
        .rx(uart_rx),
        .data(rx_data),
        .valid(rx_valid)
    );

    command_parser #(
        .CLK_HZ(CLK_HZ),
        .BAUD_RATE(UART_BAUD),
        .COMMAND_TIMEOUT_CYCLES(CLK_HZ)
    ) command_parser_inst (
        .clk(clk),
        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .reg_req(reg_req),
        .reg_write(reg_write),
        .reg_addr(reg_addr),
        .reg_wdata(reg_wdata),
        .reg_rdata(reg_rdata),
        .reg_ready(reg_ready),
        .reg_error(reg_error),
        .tx_allowed(!sender_busy),
        .busy(command_busy),
        .tx_active(command_tx_active),
        .uart_tx(command_uart_tx)
    );

    register_bus register_bus_inst (
        .clk(clk),
        .reg_req(reg_req),
        .reg_write(reg_write),
        .reg_addr(reg_addr),
        .reg_wdata(reg_wdata),
        .counter_value(press_count),
        .reg_rdata(reg_rdata),
        .reg_ready(reg_ready),
        .reg_error(reg_error),
        .counter_reset_pulse(counter_reset_pulse),
        .led_on(led_on),
        .led_pwm_duty(led_pwm_duty)
    );

    count_uart_sender #(
        .CLK_HZ(CLK_HZ),
        .BAUD_RATE(UART_BAUD)
    ) count_uart_sender_inst (
        .clk(clk),
        .start(button_pressed && !command_busy),
        .count_value(press_count + 32'd1),
        .busy(sender_busy),
        .uart_tx(count_uart_tx)
    );

    pwm_led pwm_led_inst (
        .clk(clk),
        .enable(led_on),
        .duty(led_pwm_duty),
        .led_pin(led0)
    );

    assign uart_tx = command_tx_active ? command_uart_tx : count_uart_tx;

endmodule

`default_nettype wire
