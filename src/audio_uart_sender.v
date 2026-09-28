`default_nettype none

module audio_uart_sender (
    input  wire              clk,
    input  wire              start,
    input  wire signed [23:0] raw,
    input  wire [7:0]        peak,
    input  wire [7:0]        rms,
    input  wire [7:0]        low,
    input  wire [7:0]        mid,
    input  wire [7:0]        high,
    output reg               busy,
    output reg               uart_start,
    output reg [7:0]         uart_data,
    input  wire              uart_busy
);

    localparam [3:0]
        ST_IDLE       = 4'd0,
        ST_LABEL      = 4'd1,
        ST_SIGN       = 4'd2,
        ST_DIGIT_INIT = 4'd3,
        ST_DIGIT_CALC = 4'd4,
        ST_DIGIT_SEND = 4'd5,
        ST_SPACE          = 4'd6,
        ST_NEWLINE        = 4'd7,
        ST_WAIT_BUSY_HIGH = 4'd8,
        ST_WAIT_BUSY_LOW  = 4'd9;

    reg [3:0] state;
    reg [3:0] resume_state;
    reg [2:0] field_index;
    reg [2:0] label_index;
    reg [2:0] digit_pos;
    reg       digit_started;

    reg signed [23:0] tx_raw;
    reg [7:0] tx_peak;
    reg [7:0] tx_rms;
    reg [7:0] tx_low;
    reg [7:0] tx_mid;
    reg [7:0] tx_high;
    reg [23:0] value_work;
    reg [23:0] divisor;
    reg [3:0] digit_value;

    wire raw_negative = tx_raw[23];
    wire [23:0] raw_abs = raw_negative ? ((~tx_raw) + 24'd1) : tx_raw;
    wire [7:0] current_u8 =
        (field_index == 3'd1) ? tx_peak :
        (field_index == 3'd2) ? tx_rms :
        (field_index == 3'd3) ? tx_low :
        (field_index == 3'd4) ? tx_mid :
                                tx_high;

    function [7:0] label_char;
        input [2:0] field;
        input [2:0] pos;
        begin
            case (field)
                3'd0: begin
                    case (pos)
                        3'd0: label_char = "R";
                        3'd1: label_char = "A";
                        3'd2: label_char = "W";
                        default: label_char = ":";
                    endcase
                end
                3'd1: begin
                    case (pos)
                        3'd0: label_char = "P";
                        3'd1: label_char = "E";
                        3'd2: label_char = "A";
                        3'd3: label_char = "K";
                        default: label_char = ":";
                    endcase
                end
                3'd2: begin
                    case (pos)
                        3'd0: label_char = "R";
                        3'd1: label_char = "M";
                        3'd2: label_char = "S";
                        default: label_char = ":";
                    endcase
                end
                3'd3: begin
                    case (pos)
                        3'd0: label_char = "L";
                        3'd1: label_char = "O";
                        3'd2: label_char = "W";
                        default: label_char = ":";
                    endcase
                end
                3'd4: begin
                    case (pos)
                        3'd0: label_char = "M";
                        3'd1: label_char = "I";
                        3'd2: label_char = "D";
                        default: label_char = ":";
                    endcase
                end
                default: begin
                    case (pos)
                        3'd0: label_char = "H";
                        3'd1: label_char = "I";
                        3'd2: label_char = "G";
                        3'd3: label_char = "H";
                        default: label_char = ":";
                    endcase
                end
            endcase
        end
    endfunction

    function label_done;
        input [2:0] field;
        input [2:0] pos;
        begin
            case (field)
                3'd0: label_done = (pos == 3'd3);
                3'd1: label_done = (pos == 3'd4);
                3'd2: label_done = (pos == 3'd3);
                3'd3: label_done = (pos == 3'd3);
                3'd4: label_done = (pos == 3'd3);
                default: label_done = (pos == 3'd4);
            endcase
        end
    endfunction

    function [23:0] digit_divisor;
        input [2:0] pos;
        begin
            case (pos)
                3'd6: digit_divisor = 24'd1000000;
                3'd5: digit_divisor = 24'd100000;
                3'd4: digit_divisor = 24'd10000;
                3'd3: digit_divisor = 24'd1000;
                3'd2: digit_divisor = 24'd100;
                3'd1: digit_divisor = 24'd10;
                default: digit_divisor = 24'd1;
            endcase
        end
    endfunction

    initial begin
        state = ST_IDLE;
        resume_state = ST_IDLE;
        field_index = 3'd0;
        label_index = 3'd0;
        digit_pos = 3'd0;
        digit_started = 1'b0;
        tx_raw = 24'sd0;
        tx_peak = 8'd0;
        tx_rms = 8'd0;
        tx_low = 8'd0;
        tx_mid = 8'd0;
        tx_high = 8'd0;
        value_work = 24'd0;
        divisor = 24'd1;
        digit_value = 4'd0;
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
                    tx_raw <= raw;
                    tx_peak <= peak;
                    tx_rms <= rms;
                    tx_low <= low;
                    tx_mid <= mid;
                    tx_high <= high;
                    field_index <= 3'd0;
                    label_index <= 3'd0;
                    busy <= 1'b1;
                    state <= ST_LABEL;
                end
            end

            ST_LABEL: begin
                busy <= 1'b1;
                if (!uart_busy) begin
                    uart_data <= label_char(field_index, label_index);
                    uart_start <= 1'b1;
                    state <= ST_WAIT_BUSY_HIGH;

                    if (label_done(field_index, label_index)) begin
                        label_index <= 3'd0;
                        digit_started <= 1'b0;

                        if ((field_index == 3'd0) && raw_negative) begin
                            resume_state <= ST_SIGN;
                        end else begin
                            digit_pos <= (field_index == 3'd0) ? 3'd6 : 3'd2;
                            value_work <= (field_index == 3'd0) ? raw_abs : {16'd0, current_u8};
                            resume_state <= ST_DIGIT_INIT;
                        end
                    end else begin
                        label_index <= label_index + 3'd1;
                        resume_state <= ST_LABEL;
                    end
                end
            end

            ST_SIGN: begin
                if (!uart_busy) begin
                    uart_data <= "-";
                    uart_start <= 1'b1;
                    digit_pos <= 3'd6;
                    value_work <= raw_abs;
                    digit_started <= 1'b0;
                    resume_state <= ST_DIGIT_INIT;
                    state <= ST_WAIT_BUSY_HIGH;
                end
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
                    if (digit_started || (digit_value != 4'd0) || (digit_pos == 3'd0)) begin
                        uart_data <= "0" + digit_value[3:0];
                        uart_start <= 1'b1;
                        digit_started <= 1'b1;
                        resume_state <= (digit_pos == 3'd0) ?
                            ((field_index == 3'd5) ? ST_NEWLINE : ST_SPACE) :
                            ST_DIGIT_INIT;
                        state <= ST_WAIT_BUSY_HIGH;
                    end else begin
                        state <= (digit_pos == 3'd0) ?
                            ((field_index == 3'd5) ? ST_NEWLINE : ST_SPACE) :
                            ST_DIGIT_INIT;
                    end

                    if (digit_pos != 3'd0)
                        digit_pos <= digit_pos - 3'd1;
                end
            end

            ST_SPACE: begin
                if (!uart_busy) begin
                    uart_data <= " ";
                    uart_start <= 1'b1;
                    field_index <= field_index + 3'd1;
                    label_index <= 3'd0;
                    resume_state <= ST_LABEL;
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
