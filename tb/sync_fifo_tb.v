`timescale 1ns / 1ps
`default_nettype none

module sync_fifo_tb;
    reg clk;
    reg reset;
    reg write_enable;
    reg [31:0] write_data;
    reg read_enable;
    wire [31:0] read_data;
    wire full;
    wire empty;
    wire [4:0] count;
    wire overflow;
    wire underflow;

    sync_fifo #(
        .DATA_WIDTH(32),
        .DEPTH(16)
    ) dut (
        .clk(clk),
        .reset(reset),
        .write_enable(write_enable),
        .write_data(write_data),
        .read_enable(read_enable),
        .read_data(read_data),
        .full(full),
        .empty(empty),
        .count(count),
        .overflow(overflow),
        .underflow(underflow)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        reset = 1'b1;
        write_enable = 1'b0;
        write_data = 32'd0;
        read_enable = 1'b0;
        repeat (2) @(posedge clk);
        reset = 1'b0;

        if (!empty || count != 5'd0) $stop;

        write_word(32'h00000001);
        write_word(32'h00000002);
        write_word(32'h00000003);
        read_word(32'h00000001);
        read_word(32'h00000002);
        read_word(32'h00000003);

        fill_fifo;
        if (!full || count != 5'd16) $stop;
        write_word(32'hffffffff);
        if (!overflow) $stop;

        reset_fifo;
        read_word(32'h00000000);
        if (!underflow) $stop;

        reset_fifo;
        write_word(32'h00000011);
        write_enable = 1'b1;
        write_data = 32'h00000022;
        read_enable = 1'b1;
        @(posedge clk);
        write_enable = 1'b0;
        read_enable = 1'b0;
        if (count != 5'd1 || read_data != 32'h00000022) $stop;

        $finish;
    end

    task reset_fifo;
        begin
            reset = 1'b1;
            @(posedge clk);
            reset = 1'b0;
            @(posedge clk);
        end
    endtask

    task write_word;
        input [31:0] value;
        begin
            write_data = value;
            write_enable = 1'b1;
            @(posedge clk);
            write_enable = 1'b0;
            @(posedge clk);
        end
    endtask

    task read_word;
        input [31:0] expected;
        begin
            if (read_data != expected) $stop;
            read_enable = 1'b1;
            @(posedge clk);
            read_enable = 1'b0;
            @(posedge clk);
        end
    endtask

    task fill_fifo;
        integer index;
        begin
            for (index = 0; index < 16; index = index + 1) begin
                write_word(index);
            end
        end
    endtask
endmodule

`default_nettype wire
