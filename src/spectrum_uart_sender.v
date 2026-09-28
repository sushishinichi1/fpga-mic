`default_nettype none

module spectrum_uart_sender (
    input  wire         clk,
    input  wire         start,
    input  wire [255:0] spectrum,
    output reg          busy,
    output reg          uart_start,
    output reg  [7:0]   uart_data,
    input  wire         uart_busy
);

    localparam [3:0] ST_IDLE           = 4'd0;
    localparam [3:0] ST_LABEL          = 4'd1;
    localparam [3:0] ST_DIGIT_PREP     = 4'd2;
    localparam [3:0] ST_DIGIT_INIT     = 4'd3;
    localparam [3:0] ST_DIGIT_CALC     = 4'd4;
    localparam [3:0] ST_DIGIT_SEND     = 4'd5;
    localparam [3:0] ST_SEPARATOR      = 4'd6;
    localparam [3:0] ST_NEWLINE        = 4'd7;
    localparam [3:0] ST_WAIT_BUSY_HIGH = 4'd8;
    localparam [3:0] ST_WAIT_BUSY_LOW  = 4'd9;

    reg [3:0] state;
    reg [3:0] resume_state;
    reg [2:0] label_index;
    reg [4:0] band_index;
    reg [1:0] digit_pos;
    reg       digit_started;
    reg [7:0] value_work;
    reg [7:0] divisor;
    reg [3:0] digit_value;
    reg [255:0] tx_spectrum;

    wire [7:0] current_value = tx_spectrum[(band_index * 8) +: 8];

    function [7:0] label_char;
        input [2:0] position;
        begin
            case (position)
                3'd0: label_char = "S";
                3'd1: label_char = "P";
                3'd2: label_char = "E";
                3'd3: label_char = "C";
                default: label_char = ":";
            endcase
        end
    endfunction

    function [7:0] digit_divisor;
        input [1:0] position;
        begin
            case (position)
                2'd2: digit_divisor = 8'd100;
                2'd1: digit_divisor = 8'd10;
                default: digit_divisor = 8'd1;
            endcase
        end
    endfunction

    initial begin
        state = ST_IDLE;
        resume_state = ST_IDLE;
        label_index = 3'd0;
        band_index = 5'd0;
        digit_pos = 2'd0;
        digit_started = 1'b0;
        value_work = 8'd0;
        divisor = 8'd1;
        digit_value = 4'd0;
        tx_spectrum = 256'd0;
        busy = 1'b0;
        uart_start = 1'b0;
        uart_data = 8'h0a;
    end

    always @(posedge clk) begin
        uart_start <= 1'b0;

        case (state)
            ST_IDLE: begin
                busy <= 1'b0;
                if (start) begin
                    tx_spectrum <= spectrum;
                    label_index <= 3'd0;
                    band_index <= 5'd0;
                    busy <= 1'b1;
                    state <= ST_LABEL;
                end
            end

            ST_LABEL: begin
                busy <= 1'b1;
                if (!uart_busy) begin
                    uart_data <= label_char(label_index);
                    uart_start <= 1'b1;
                    state <= ST_WAIT_BUSY_HIGH;
                    if (label_index == 3'd4) begin
                        resume_state <= ST_DIGIT_PREP;
                    end else begin
                        label_index <= label_index + 3'd1;
                        resume_state <= ST_LABEL;
                    end
                end
            end

            ST_DIGIT_PREP: begin
                digit_pos <= 2'd2;
                digit_started <= 1'b0;
                value_work <= current_value;
                state <= ST_DIGIT_INIT;
            end

            ST_DIGIT_INIT: begin
                divisor <= digit_divisor(digit_pos);
                digit_value <= 4'd0;
                state <= ST_DIGIT_CALC;
            end

            ST_DIGIT_CALC: begin
                if (value_work >= divisor) begin
                    value_work <= value_work - divisor;
                    digit_value <= digit_value + 4'd1;
                end else begin
                    state <= ST_DIGIT_SEND;
                end
            end

            ST_DIGIT_SEND: begin
                if (!uart_busy) begin
                    if (digit_started || (digit_value != 4'd0) || (digit_pos == 2'd0)) begin
                        uart_data <= "0" + digit_value;
                        uart_start <= 1'b1;
                        digit_started <= 1'b1;
                        resume_state <= (digit_pos == 2'd0) ?
                            ((band_index == 5'd31) ? ST_NEWLINE : ST_SEPARATOR) :
                            ST_DIGIT_INIT;
                        state <= ST_WAIT_BUSY_HIGH;
                    end else begin
                        state <= (digit_pos == 2'd0) ?
                            ((band_index == 5'd31) ? ST_NEWLINE : ST_SEPARATOR) :
                            ST_DIGIT_INIT;
                    end

                    if (digit_pos != 2'd0)
                        digit_pos <= digit_pos - 2'd1;
                end
            end

            ST_SEPARATOR: begin
                if (!uart_busy) begin
                    uart_data <= ",";
                    uart_start <= 1'b1;
                    band_index <= band_index + 5'd1;
                    resume_state <= ST_DIGIT_PREP;
                    state <= ST_WAIT_BUSY_HIGH;
                end
            end

            ST_NEWLINE: begin
                if (!uart_busy) begin
                    uart_data <= 8'h0a;
                    uart_start <= 1'b1;
                    resume_state <= ST_IDLE;
                    state <= ST_WAIT_BUSY_HIGH;
                end
            end

            ST_WAIT_BUSY_HIGH: begin
                if (uart_busy)
                    state <= ST_WAIT_BUSY_LOW;
            end

            ST_WAIT_BUSY_LOW: begin
                if (!uart_busy)
                    state <= resume_state;
            end

            default: state <= ST_IDLE;
        endcase
    end

endmodule

`default_nettype wire
