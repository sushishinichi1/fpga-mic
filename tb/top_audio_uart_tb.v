`timescale 1ns/1ps
`default_nettype none

module top_audio_uart_tb;

    localparam integer CLK_HZ = 27000000;
    localparam integer BAUD_RATE = 115200;
    localparam integer CLKS_PER_BIT = CLK_HZ / BAUD_RATE;
    localparam integer MESSAGE_LENGTH = 38;
    localparam integer REPORT_INTERVAL = 2700000;

    reg clk;
    reg mic_sd;
    wire mic_sck;
    wire mic_ws;
    wire mic_lr;
    wire uart_tx_out;
    wire led0;

    reg [8 * MESSAGE_LENGTH - 1:0] expected_message;
    reg [7:0] received_byte;
    integer byte_index;
    integer line_index;
    integer cycle_count;
    integer byte_start_cycle;
    integer first_line_cycle;
    integer second_line_cycle;

    top dut (
        .clk(clk),
        .mic_sd(mic_sd),
        .mic_sck(mic_sck),
        .mic_ws(mic_ws),
        .mic_lr(mic_lr),
        .uart_tx(uart_tx_out),
        .led0(led0)
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
        output integer start_cycle;
        integer bit_number;
        begin
            @(negedge uart_tx_out);
            start_cycle = cycle_count;
            repeat (CLKS_PER_BIT + (CLKS_PER_BIT / 2)) @(posedge clk);

            for (bit_number = 0; bit_number < 8; bit_number = bit_number + 1) begin
                value[bit_number] = uart_tx_out;
                repeat (CLKS_PER_BIT) @(posedge clk);
            end

            if (uart_tx_out !== 1'b1) begin
                $display(
                    "FAIL: line %0d character %0d has no stop bit",
                    line_index,
                    byte_index
                );
                $fatal;
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always @(posedge clk)
        cycle_count = cycle_count + 1;

    initial begin
        expected_message = "RAW:0 PEAK:0 RMS:0 LOW:0 MID:0 HIGH:0\n";
        mic_sd = 1'b0;
        cycle_count = 0;
        first_line_cycle = 0;
        second_line_cycle = 0;

        for (line_index = 0; line_index < 2; line_index = line_index + 1) begin
            for (byte_index = 0; byte_index < MESSAGE_LENGTH; byte_index = byte_index + 1) begin
                receive_uart_byte(received_byte, byte_start_cycle);

                if (byte_index == 0) begin
                    if (line_index == 0)
                        first_line_cycle = byte_start_cycle;
                    else
                        second_line_cycle = byte_start_cycle;
                end

                if (received_byte !== expected_byte(byte_index)) begin
                    $display(
                        "FAIL: line %0d character %0d expected 0x%02x (%c), actual 0x%02x (%c)",
                        line_index,
                        byte_index,
                        expected_byte(byte_index),
                        expected_byte(byte_index),
                        received_byte,
                        received_byte
                    );
                    $fatal;
                end
            end
        end

        if ((second_line_cycle - first_line_cycle) < (REPORT_INTERVAL - 16) ||
            (second_line_cycle - first_line_cycle) > (REPORT_INTERVAL + 16)) begin
            $display(
                "FAIL: report interval expected about %0d cycles, actual %0d cycles",
                REPORT_INTERVAL,
                second_line_cycle - first_line_cycle
            );
            $fatal;
        end

        $display(
            "PASS: top_audio_uart_tb matched two reports, interval=%0d cycles",
            second_line_cycle - first_line_cycle
        );
        $finish;
    end

    initial begin
        repeat (6000000) @(posedge clk);
        $display("FAIL: top_audio_uart_tb timed out");
        $fatal;
    end

endmodule

`default_nettype wire
