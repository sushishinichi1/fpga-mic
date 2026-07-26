`default_nettype none

module count_uart_sender #(
    parameter integer CLK_HZ = 27000000,
    parameter integer BAUD_RATE = 115200
) (
    input  wire        clk,
    input  wire        start,
    input  wire [31:0] count_value,
    output wire        busy,
    output wire        uart_tx
);

    localparam integer MESSAGE_LEN = 17;

    reg [31:0] latched_count;
    reg [4:0]  byte_index;
    reg        active;
    reg        tx_start;
    reg [7:0]  tx_data;
    wire       tx_busy;

    assign busy = active | tx_busy;

    uart_tx #(
        .CLK_HZ(CLK_HZ),
        .BAUD_RATE(BAUD_RATE)
    ) uart_tx_inst (
        .clk(clk),
        .start(tx_start),
        .data(tx_data),
        .busy(tx_busy),
        .tx(uart_tx)
    );

    initial begin
        latched_count = 32'd0;
        byte_index = 5'd0;
        active = 1'b0;
        tx_start = 1'b0;
        tx_data = 8'h00;
    end

    always @(posedge clk) begin
        tx_start <= 1'b0;

        if (!active) begin
            byte_index <= 5'd0;
            if (start) begin
                active <= 1'b1;
                latched_count <= count_value;
            end
        end else if (!tx_busy && !tx_start) begin
            if (byte_index < MESSAGE_LEN) begin
                tx_data <= message_byte(byte_index, latched_count);
                tx_start <= 1'b1;
                byte_index <= byte_index + 5'd1;
            end else begin
                active <= 1'b0;
            end
        end
    end

    function [7:0] hex_digit;
        input [3:0] value;
        begin
            if (value < 4'd10) begin
                hex_digit = 8'h30 + value;
            end else begin
                hex_digit = 8'h41 + (value - 4'd10);
            end
        end
    endfunction

    function [7:0] message_byte;
        input [4:0] index;
        input [31:0] value;
        begin
            case (index)
                5'd0:  message_byte = "C";
                5'd1:  message_byte = "O";
                5'd2:  message_byte = "U";
                5'd3:  message_byte = "N";
                5'd4:  message_byte = "T";
                5'd5:  message_byte = ":";
                5'd6:  message_byte = " ";
                5'd7:  message_byte = hex_digit(value[31:28]);
                5'd8:  message_byte = hex_digit(value[27:24]);
                5'd9:  message_byte = hex_digit(value[23:20]);
                5'd10: message_byte = hex_digit(value[19:16]);
                5'd11: message_byte = hex_digit(value[15:12]);
                5'd12: message_byte = hex_digit(value[11:8]);
                5'd13: message_byte = hex_digit(value[7:4]);
                5'd14: message_byte = hex_digit(value[3:0]);
                5'd15: message_byte = 8'h0d;
                5'd16: message_byte = 8'h0a;
                default: message_byte = 8'h00;
            endcase
        end
    endfunction

endmodule

`default_nettype wire
