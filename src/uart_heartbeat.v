`default_nettype none

module uart_heartbeat #(
    parameter integer INTERVAL_CYCLES = 27000000
) (
    input  wire       clk,
    input  wire       uart_busy,
    output reg        uart_start,
    output reg  [7:0] uart_data,
    output reg        heartbeat_toggle
);

    localparam [2:0]
        ST_WAIT_INTERVAL = 3'd0,
        ST_ISSUE_BYTE    = 3'd1,
        ST_WAIT_ACCEPT   = 3'd2,
        ST_WAIT_COMPLETE = 3'd3;

    reg [2:0]  state;
    reg [2:0]  char_index;
    reg [31:0] interval_counter;

    function [7:0] message_char;
        input [2:0] index;
        begin
            case (index)
                3'd0: message_char = "T";
                3'd1: message_char = "E";
                3'd2: message_char = "S";
                3'd3: message_char = "T";
                default: message_char = 8'h0a;
            endcase
        end
    endfunction

    initial begin
        state = ST_WAIT_INTERVAL;
        char_index = 3'd0;
        interval_counter = 32'd0;
        uart_start = 1'b0;
        uart_data = 8'h0a;
        heartbeat_toggle = 1'b0;
    end

    always @(posedge clk) begin
        uart_start <= 1'b0;

        case (state)
            ST_WAIT_INTERVAL: begin
                if (interval_counter == INTERVAL_CYCLES - 1) begin
                    interval_counter <= 32'd0;
                    char_index <= 3'd0;
                    state <= ST_ISSUE_BYTE;
                end else begin
                    interval_counter <= interval_counter + 32'd1;
                end
            end

            ST_ISSUE_BYTE: begin
                if (!uart_busy) begin
                    uart_data <= message_char(char_index);
                    uart_start <= 1'b1;
                    state <= ST_WAIT_ACCEPT;
                end
            end

            ST_WAIT_ACCEPT: begin
                // Hold start until uart_tx has sampled the request.
                uart_start <= 1'b1;
                if (uart_busy) begin
                    uart_start <= 1'b0;
                    state <= ST_WAIT_COMPLETE;
                end
            end

            default: begin
                if (!uart_busy) begin
                    if (char_index == 3'd4) begin
                        heartbeat_toggle <= ~heartbeat_toggle;
                        state <= ST_WAIT_INTERVAL;
                    end else begin
                        char_index <= char_index + 3'd1;
                        state <= ST_ISSUE_BYTE;
                    end
                end
            end
        endcase
    end

endmodule

`default_nettype wire
