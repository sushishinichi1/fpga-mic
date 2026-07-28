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
    wire rx_valid;
    wire [7:0] rx_data;
    wire reset_counter;

    assign reset_counter = rx_valid && (rx_data == "r");

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
        .reset(reset_counter),
        .increment(button_pressed),
        .count(press_count)
    );

    uart_rx_byte #(
        .CLK_HZ(CLK_HZ),
        .BAUD_RATE(UART_BAUD)
    ) uart_rx_inst (
        .clk(clk),
        .rx(uart_rx),
        .data(rx_data),
        .valid(rx_valid)
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

module uart_rx_byte #(
    parameter integer CLK_HZ = 27000000,
    parameter integer BAUD_RATE = 115200
) (
    input  wire       clk,
    input  wire       rx,
    output reg  [7:0] data,
    output reg        valid
);

    localparam integer CLKS_PER_BIT = CLK_HZ / BAUD_RATE;
    localparam integer HALF_BIT_CLKS = CLKS_PER_BIT / 2;

    localparam [1:0] STATE_IDLE  = 2'd0;
    localparam [1:0] STATE_START = 2'd1;
    localparam [1:0] STATE_DATA  = 2'd2;
    localparam [1:0] STATE_STOP  = 2'd3;

    reg       rx_sync_0;
    reg       rx_sync_1;
    reg [1:0] state;
    reg [8:0] baud_counter;
    reg [2:0] bit_index;
    reg [7:0] data_shift;

    initial begin
        data = 8'h00;
        valid = 1'b0;
        rx_sync_0 = 1'b1;
        rx_sync_1 = 1'b1;
        state = STATE_IDLE;
        baud_counter = 9'd0;
        bit_index = 3'd0;
        data_shift = 8'h00;
    end

    always @(posedge clk) begin
        rx_sync_0 <= rx;
        rx_sync_1 <= rx_sync_0;
        valid <= 1'b0;

        case (state)
            STATE_IDLE: begin
                baud_counter <= 9'd0;
                bit_index <= 3'd0;
                if (rx_sync_1 == 1'b0) begin
                    state <= STATE_START;
                end
            end

            STATE_START: begin
                if (baud_counter == HALF_BIT_CLKS - 1) begin
                    baud_counter <= 9'd0;
                    if (rx_sync_1 == 1'b0) begin
                        state <= STATE_DATA;
                    end else begin
                        state <= STATE_IDLE;
                    end
                end else begin
                    baud_counter <= baud_counter + 9'd1;
                end
            end

            STATE_DATA: begin
                if (baud_counter == CLKS_PER_BIT - 1) begin
                    baud_counter <= 9'd0;
                    data_shift <= {rx_sync_1, data_shift[7:1]};
                    if (bit_index == 3'd7) begin
                        state <= STATE_STOP;
                    end else begin
                        bit_index <= bit_index + 3'd1;
                    end
                end else begin
                    baud_counter <= baud_counter + 9'd1;
                end
            end

            STATE_STOP: begin
                if (baud_counter == CLKS_PER_BIT - 1) begin
                    baud_counter <= 9'd0;
                    state <= STATE_IDLE;
                    if (rx_sync_1 == 1'b1) begin
                        data <= data_shift;
                        valid <= 1'b1;
                    end
                end else begin
                    baud_counter <= baud_counter + 9'd1;
                end
            end

            default: begin
                state <= STATE_IDLE;
            end
        endcase
    end

endmodule

`default_nettype wire
