`timescale 1ns/1ps
`default_nettype none

module audio_uart_path_tb;

    localparam integer CLK_HZ = 1000000;
    localparam integer BAUD_RATE = 100000;
    localparam integer CLKS_PER_BIT = CLK_HZ / BAUD_RATE;
    localparam integer MESSAGE_LENGTH = 44;

    reg clk;
    reg start;
    wire sender_busy;
    wire uart_start;
    wire [7:0] uart_data;
    wire uart_busy;
    wire uart_tx_out;

    reg [8 * MESSAGE_LENGTH - 1:0] expected_message;
    reg [7:0] received_byte;
    integer byte_index;

    audio_uart_sender sender_inst (
        .clk(clk),
        .start(start),
        .raw(-24'sd12345),
        .peak(8'd6),
        .rms(8'd4),
        .low(8'd12),
        .mid(8'd5),
        .high(8'd2),
        .busy(sender_busy),
        .uart_start(uart_start),
        .uart_data(uart_data),
        .uart_busy(uart_busy)
    );

    uart_tx #(
        .CLK_HZ(CLK_HZ),
        .BAUD_RATE(BAUD_RATE)
    ) uart_tx_inst (
        .clk(clk),
        .start(uart_start),
        .data(uart_data),
        .busy(uart_busy),
        .tx(uart_tx_out)
    );

    function [7:0] expected_byte;
        input integer index;
        begin
            expected_byte = expected_message[
                ((MESSAGE_LENGTH - index) * 8) - 1 -: 8
            ];
        end
    endfunction

    task receive_uart_byte;
        output [7:0] value;
        integer bit_number;
        begin
            @(negedge uart_tx_out);
            repeat (CLKS_PER_BIT + (CLKS_PER_BIT / 2)) @(posedge clk);

            for (bit_number = 0; bit_number < 8; bit_number = bit_number + 1) begin
                value[bit_number] = uart_tx_out;
                repeat (CLKS_PER_BIT) @(posedge clk);
            end

            if (uart_tx_out !== 1'b1) begin
                $display("FAIL: missing stop bit at character %0d", byte_index);
                $fatal;
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        expected_message = "RAW:-12345 PEAK:6 RMS:4 LOW:12 MID:5 HIGH:2\n";
        start = 1'b0;

        repeat (5) @(negedge clk);
        start = 1'b1;
        @(negedge clk);
        start = 1'b0;

        for (byte_index = 0; byte_index < MESSAGE_LENGTH; byte_index = byte_index + 1) begin
            receive_uart_byte(received_byte);
            if (received_byte !== expected_byte(byte_index)) begin
                $display(
                    "FAIL: character %0d expected 0x%02x (%c), actual 0x%02x (%c)",
                    byte_index,
                    expected_byte(byte_index),
                    expected_byte(byte_index),
                    received_byte,
                    received_byte
                );
                $fatal;
            end
        end

        wait (!sender_busy);
        $display("PASS: audio_uart_path_tb matched all %0d characters", MESSAGE_LENGTH);
        $finish;
    end

    initial begin
        repeat (20000) @(posedge clk);
        $display("FAIL: audio_uart_path_tb timed out");
        $fatal;
    end

endmodule

`default_nettype wire
