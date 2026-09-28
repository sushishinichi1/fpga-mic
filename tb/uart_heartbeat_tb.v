`timescale 1ns/1ps
`default_nettype none

module uart_heartbeat_tb;

    localparam integer CLK_HZ = 1000000;
    localparam integer BAUD_RATE = 100000;
    localparam integer CLKS_PER_BIT = CLK_HZ / BAUD_RATE;

    reg clk;
    wire uart_start;
    wire [7:0] uart_data;
    wire uart_busy;
    wire uart_tx_out;
    wire heartbeat_toggle;

    integer byte_index;
    integer bit_index;
    reg [7:0] received_byte;

    uart_heartbeat #(
        .INTERVAL_CYCLES(50)
    ) heartbeat_inst (
        .clk(clk),
        .uart_busy(uart_busy),
        .uart_start(uart_start),
        .uart_data(uart_data),
        .heartbeat_toggle(heartbeat_toggle)
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
            case (index)
                0: expected_byte = "T";
                1: expected_byte = "E";
                2: expected_byte = "S";
                3: expected_byte = "T";
                default: expected_byte = 8'h0a;
            endcase
        end
    endfunction

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        for (byte_index = 0; byte_index < 5; byte_index = byte_index + 1) begin
            @(negedge uart_tx_out);
            repeat (CLKS_PER_BIT + (CLKS_PER_BIT / 2)) @(posedge clk);

            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                received_byte[bit_index] = uart_tx_out;
                repeat (CLKS_PER_BIT) @(posedge clk);
            end

            if (uart_tx_out !== 1'b1) begin
                $display("[FAIL] Missing stop bit for byte %0d", byte_index);
                $finish;
            end

            if (received_byte !== expected_byte(byte_index)) begin
                $display(
                    "[FAIL] Byte %0d: expected 0x%02x, received 0x%02x",
                    byte_index,
                    expected_byte(byte_index),
                    received_byte
                );
                $finish;
            end
        end

        wait (heartbeat_toggle == 1'b1);

        $display("[PASS] uart_heartbeat_tb received TEST newline");
        $finish;
    end

    initial begin
        repeat (10000) @(posedge clk);
        $display("[FAIL] uart_heartbeat_tb timed out");
        $finish;
    end

endmodule

`default_nettype wire
