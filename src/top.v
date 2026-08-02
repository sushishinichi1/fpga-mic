`default_nettype none

module top (
    input  wire clk,
    input  wire button,
    input  wire uart_rx,
    output wire led0,
    output wire uart_tx,
    output wire spi_sclk,
    output wire spi_mosi,
    input  wire spi_miso,
    output wire spi_cs_n
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
    wire [7:0] spi_tx_data;
    wire [7:0] spi_rx_data;
    wire spi_start_pulse;
    wire spi_busy;
    wire spi_done;
    wire fifo_write_pulse;
    wire [31:0] fifo_write_data;
    wire fifo_read_pulse;
    wire [31:0] fifo_read_data;
    wire fifo_empty;
    wire fifo_full;
    wire [4:0] fifo_count;
    wire fifo_overflow;
    wire fifo_underflow;
    wire fifo_clear_pulse;
    wire accel_start_pulse;
    wire accel_clear_pulse;
    wire [15:0] accel_vector_length;
    wire accel_fifo_read_enable;
    wire accel_busy;
    wire accel_done;
    wire accel_error;
    wire [31:0] accel_result;
    wire [31:0] accel_cycle_count;
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
        .spi_rx_data(spi_rx_data),
        .spi_busy(spi_busy),
        .spi_done(spi_done),
        .fifo_read_data(fifo_read_data),
        .fifo_empty(fifo_empty),
        .fifo_full(fifo_full),
        .fifo_count(fifo_count),
        .fifo_overflow(fifo_overflow),
        .fifo_underflow(fifo_underflow),
        .accel_busy(accel_busy),
        .accel_done(accel_done),
        .accel_error(accel_error),
        .accel_result(accel_result),
        .accel_cycle_count(accel_cycle_count),
        .reg_rdata(reg_rdata),
        .reg_ready(reg_ready),
        .reg_error(reg_error),
        .counter_reset_pulse(counter_reset_pulse),
        .led_on(led_on),
        .led_pwm_duty(led_pwm_duty),
        .spi_tx_data(spi_tx_data),
        .spi_start_pulse(spi_start_pulse),
        .fifo_write_pulse(fifo_write_pulse),
        .fifo_write_data(fifo_write_data),
        .fifo_read_pulse(fifo_read_pulse),
        .fifo_clear_pulse(fifo_clear_pulse),
        .accel_start_pulse(accel_start_pulse),
        .accel_clear_pulse(accel_clear_pulse),
        .accel_vector_length(accel_vector_length)
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

    spi_master #(
        .CLK_DIV(27)
    ) spi_master_inst (
        .clk(clk),
        .reset(1'b0),
        .start(spi_start_pulse),
        .tx_data(spi_tx_data),
        .rx_data(spi_rx_data),
        .busy(spi_busy),
        .done(spi_done),
        .spi_sclk(spi_sclk),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .spi_cs_n(spi_cs_n)
    );

    sync_fifo #(
        .DATA_WIDTH(32),
        .DEPTH(16)
    ) input_fifo_inst (
        .clk(clk),
        .reset(fifo_clear_pulse),
        .write_enable(fifo_write_pulse),
        .write_data(fifo_write_data),
        .read_enable(fifo_read_pulse | accel_fifo_read_enable),
        .read_data(fifo_read_data),
        .full(fifo_full),
        .empty(fifo_empty),
        .count(fifo_count),
        .overflow(fifo_overflow),
        .underflow(fifo_underflow)
    );

    dot_product_accel dot_product_accel_inst (
        .clk(clk),
        .reset(1'b0),
        .start(accel_start_pulse),
        .clear(accel_clear_pulse),
        .vector_length(accel_vector_length),
        .fifo_read_enable(accel_fifo_read_enable),
        .fifo_read_data(fifo_read_data),
        .fifo_empty(fifo_empty),
        .fifo_count(fifo_count),
        .busy(accel_busy),
        .done(accel_done),
        .error(accel_error),
        .result(accel_result),
        .cycle_count(accel_cycle_count)
    );

    assign uart_tx = command_tx_active ? command_uart_tx : count_uart_tx;

endmodule

`default_nettype wire
