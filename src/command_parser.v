`default_nettype none

module command_parser #(
    parameter integer CLK_HZ = 27000000,
    parameter integer BAUD_RATE = 115200,
    parameter integer COMMAND_TIMEOUT_CYCLES = 27000000
) (
    input  wire        clk,
    input  wire [7:0]  rx_data,
    input  wire        rx_valid,
    output reg         reg_req,
    output reg         reg_write,
    output reg  [7:0]  reg_addr,
    output reg  [31:0] reg_wdata,
    input  wire [31:0] reg_rdata,
    input  wire        reg_ready,
    input  wire        reg_error,
    input  wire        tx_allowed,
    output reg         busy,
    output wire        tx_active,
    output wire        uart_tx
);

    localparam integer MAX_COMMAND_LEN = 14;
    localparam [2:0] STATE_COLLECT = 3'd0;
    localparam [2:0] STATE_EXEC    = 3'd1;
    localparam [2:0] STATE_WAIT    = 3'd2;
    localparam [2:0] STATE_REPLY   = 3'd3;

    reg [2:0] state;
    reg [7:0] command [0:MAX_COMMAND_LEN-1];
    reg [3:0] command_len;
    reg [31:0] timeout_counter;
    reg [31:0] reply_data;
    reg [1:0] reply_kind;
    reg [3:0] reply_index;
    reg tx_start;
    reg [7:0] tx_data;
    wire tx_busy;

    assign tx_active = tx_busy | tx_start;

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
        state = STATE_COLLECT;
        command_len = 4'd0;
        timeout_counter = 32'd0;
        reply_data = 32'd0;
        reply_kind = 2'd0;
        reply_index = 4'd0;
        reg_req = 1'b0;
        reg_write = 1'b0;
        reg_addr = 8'h00;
        reg_wdata = 32'd0;
        busy = 1'b0;
        tx_start = 1'b0;
        tx_data = 8'h00;
    end

    always @(posedge clk) begin
        reg_req <= 1'b0;
        tx_start <= 1'b0;
        busy <= (state != STATE_COLLECT) | tx_busy;

        if ((command_len != 4'd0) && (state == STATE_COLLECT)) begin
            if (timeout_counter == COMMAND_TIMEOUT_CYCLES - 1) begin
                command_len <= 4'd0;
                timeout_counter <= 32'd0;
            end else begin
                timeout_counter <= timeout_counter + 32'd1;
            end
        end else begin
            timeout_counter <= 32'd0;
        end

        case (state)
            STATE_COLLECT: begin
                if (rx_valid) begin
                    if (rx_data == 8'h0a || rx_data == 8'h0d) begin
                        if (command_len != 4'd0) begin
                            parse_command;
                            state <= STATE_EXEC;
                        end
                    end else if ((rx_data == "r") && (command_len == 4'd0)) begin
                        reg_write <= 1'b1;
                        reg_addr <= 8'h04;
                        reg_wdata <= 32'd1;
                        reply_kind <= 2'd1;
                        state <= STATE_EXEC;
                    end else if (command_len < MAX_COMMAND_LEN) begin
                        command[command_len] <= rx_data;
                        command_len <= command_len + 4'd1;
                    end else begin
                        command_len <= 4'd0;
                        reply_kind <= 2'd2;
                        state <= STATE_REPLY;
                    end
                end
            end

            STATE_EXEC: begin
                if (reply_kind == 2'd2) begin
                    reply_index <= 4'd0;
                    state <= STATE_REPLY;
                end else begin
                    reg_req <= 1'b1;
                    state <= STATE_WAIT;
                end
                command_len <= 4'd0;
            end

            STATE_WAIT: begin
                if (reg_ready) begin
                    if (reg_error) begin
                        reply_kind <= 2'd2;
                    end else if (!reg_write) begin
                        reply_kind <= 2'd0;
                        reply_data <= reg_rdata;
                    end else begin
                        reply_kind <= 2'd1;
                    end
                    reply_index <= 4'd0;
                    state <= STATE_REPLY;
                end
            end

            STATE_REPLY: begin
                if (tx_allowed && !tx_busy && !tx_start) begin
                    if (reply_index < reply_length(reply_kind)) begin
                        tx_data <= reply_byte(reply_kind, reply_index, reply_data);
                        tx_start <= 1'b1;
                        reply_index <= reply_index + 4'd1;
                    end else begin
                        state <= STATE_COLLECT;
                    end
                end
            end

            default: begin
                state <= STATE_COLLECT;
            end
        endcase
    end

    task parse_command;
        reg [7:0] parsed_addr;
        reg [31:0] parsed_data;
        begin
            parsed_addr = 8'h00;
            parsed_data = 32'd0;
            reg_write <= 1'b0;
            reg_addr <= 8'h00;
            reg_wdata <= 32'd0;
            reply_kind <= 2'd2;

            if ((command_len == 4'd4) &&
                (command[0] == "R") &&
                (command[1] == " ") &&
                is_hex(command[2]) &&
                is_hex(command[3])) begin
                parsed_addr = {hex_value(command[2]), hex_value(command[3])};
                reg_write <= 1'b0;
                reg_addr <= parsed_addr;
                reply_kind <= 2'd1;
            end else if ((command_len == 4'd13) &&
                (command[0] == "W") &&
                (command[1] == " ") &&
                is_hex(command[2]) &&
                is_hex(command[3]) &&
                (command[4] == " ") &&
                is_hex(command[5]) &&
                is_hex(command[6]) &&
                is_hex(command[7]) &&
                is_hex(command[8]) &&
                is_hex(command[9]) &&
                is_hex(command[10]) &&
                is_hex(command[11]) &&
                is_hex(command[12])) begin
                parsed_addr = {hex_value(command[2]), hex_value(command[3])};
                parsed_data = {
                    hex_value(command[5]),
                    hex_value(command[6]),
                    hex_value(command[7]),
                    hex_value(command[8]),
                    hex_value(command[9]),
                    hex_value(command[10]),
                    hex_value(command[11]),
                    hex_value(command[12])
                };
                reg_write <= 1'b1;
                reg_addr <= parsed_addr;
                reg_wdata <= parsed_data;
                reply_kind <= 2'd1;
            end
        end
    endtask

    function [3:0] hex_value;
        input [7:0] char;
        begin
            if ((char >= "0") && (char <= "9")) begin
                hex_value = char - "0";
            end else if ((char >= "A") && (char <= "F")) begin
                hex_value = char - "A" + 4'd10;
            end else if ((char >= "a") && (char <= "f")) begin
                hex_value = char - "a" + 4'd10;
            end else begin
                hex_value = 4'd0;
            end
        end
    endfunction

    function is_hex;
        input [7:0] char;
        begin
            is_hex = ((char >= "0") && (char <= "9")) ||
                ((char >= "A") && (char <= "F")) ||
                ((char >= "a") && (char <= "f"));
        end
    endfunction

    function [3:0] reply_length;
        input [1:0] kind;
        begin
            case (kind)
                2'd0: reply_length = 4'd12;
                2'd1: reply_length = 4'd3;
                default: reply_length = 4'd4;
            endcase
        end
    endfunction

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

    function [7:0] reply_byte;
        input [1:0] kind;
        input [3:0] index;
        input [31:0] value;
        begin
            case (kind)
                2'd0: begin
                    case (index)
                        4'd0: reply_byte = "O";
                        4'd1: reply_byte = "K";
                        4'd2: reply_byte = " ";
                        4'd3: reply_byte = hex_digit(value[31:28]);
                        4'd4: reply_byte = hex_digit(value[27:24]);
                        4'd5: reply_byte = hex_digit(value[23:20]);
                        4'd6: reply_byte = hex_digit(value[19:16]);
                        4'd7: reply_byte = hex_digit(value[15:12]);
                        4'd8: reply_byte = hex_digit(value[11:8]);
                        4'd9: reply_byte = hex_digit(value[7:4]);
                        4'd10: reply_byte = hex_digit(value[3:0]);
                        4'd11: reply_byte = 8'h0a;
                        default: reply_byte = 8'h00;
                    endcase
                end

                2'd1: begin
                    case (index)
                        4'd0: reply_byte = "O";
                        4'd1: reply_byte = "K";
                        4'd2: reply_byte = 8'h0a;
                        default: reply_byte = 8'h00;
                    endcase
                end

                default: begin
                    case (index)
                        4'd0: reply_byte = "E";
                        4'd1: reply_byte = "R";
                        4'd2: reply_byte = "R";
                        4'd3: reply_byte = 8'h0a;
                        default: reply_byte = 8'h00;
                    endcase
                end
            endcase
        end
    endfunction

endmodule

`default_nettype wire
