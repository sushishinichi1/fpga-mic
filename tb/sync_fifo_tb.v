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
        $dumpfile("build/sim/sync_fifo_tb.vcd");
        $dumpvars(0, sync_fifo_tb);
    end

    initial begin
        #1000000;
        $display("FAIL: sync_fifo_tb simulation timeout");
        $fatal;
    end

    initial begin
        reset = 1'b0;
        write_enable = 1'b0;
        write_data = 32'd0;
        read_enable = 1'b0;

        reset_fifo;
        test_reset_state;
        test_single_word;
        test_fifo_order;
        test_full_overflow_preserves_data;
        test_empty_underflow;
        test_clear_resets_state;
        test_simultaneous_read_write;

        $display("PASS: sync_fifo_tb");
        $finish;
    end

    task reset_fifo;
        begin
            @(negedge clk);
            reset = 1'b1;
            write_enable = 1'b0;
            read_enable = 1'b0;
            write_data = 32'd0;
            @(negedge clk);
            reset = 1'b0;
            @(negedge clk);
        end
    endtask

    task check_reset_state;
        begin
            if (empty !== 1'b1) begin
                $display("FAIL: empty is not 1 after reset");
                $fatal;
            end
            if (full !== 1'b0) begin
                $display("FAIL: full is not 0 after reset");
                $fatal;
            end
            if (count !== 5'd0) begin
                $display("FAIL: count is not 0 after reset");
                $fatal;
            end
            if (overflow !== 1'b0 || underflow !== 1'b0) begin
                $display("FAIL: overflow/underflow flags are not clear after reset");
                $fatal;
            end
        end
    endtask

    task write_word;
        input [31:0] value;
        begin
            @(negedge clk);
            write_data = value;
            write_enable = 1'b1;
            @(negedge clk);
            write_enable = 1'b0;
            write_data = 32'd0;
        end
    endtask

    task read_word;
        input [31:0] expected;
        begin
            @(negedge clk);
            if (read_data !== expected) begin
                $display("FAIL: read data mismatch, expected %08h got %08h", expected, read_data);
                $fatal;
            end
            read_enable = 1'b1;
            @(negedge clk);
            read_enable = 1'b0;
        end
    endtask

    task test_reset_state;
        begin
            check_reset_state;
        end
    endtask

    task test_single_word;
        begin
            write_word(32'h1234abcd);
            if (empty !== 1'b0 || count !== 5'd1) begin
                $display("FAIL: FIFO state is wrong after one write");
                $fatal;
            end
            read_word(32'h1234abcd);
            if (empty !== 1'b1 || count !== 5'd0) begin
                $display("FAIL: FIFO state is wrong after one read");
                $fatal;
            end
        end
    endtask

    task test_fifo_order;
        integer index;
        begin
            reset_fifo;
            for (index = 0; index < 4; index = index + 1) begin
                write_word(32'h10000000 + index);
            end
            if (count !== 5'd4) begin
                $display("FAIL: count is not 4 after multiple writes");
                $fatal;
            end
            for (index = 0; index < 4; index = index + 1) begin
                read_word(32'h10000000 + index);
            end
            if (empty !== 1'b1 || count !== 5'd0) begin
                $display("FAIL: FIFO is not empty after ordered reads");
                $fatal;
            end
        end
    endtask

    task test_full_overflow_preserves_data;
        integer index;
        begin
            reset_fifo;
            for (index = 0; index < 16; index = index + 1) begin
                write_word(32'h20000000 + index);
            end
            if (full !== 1'b1 || count !== 5'd16) begin
                $display("FAIL: FIFO is not full after 16 writes");
                $fatal;
            end

            write_word(32'hffffffff);
            if (count !== 5'd16 || full !== 1'b1 || overflow !== 1'b1) begin
                $display("FAIL: full write did not keep count/full and latch overflow");
                $fatal;
            end

            for (index = 0; index < 16; index = index + 1) begin
                read_word(32'h20000000 + index);
            end
            if (empty !== 1'b1 || count !== 5'd0) begin
                $display("FAIL: FIFO is not empty after reading 16 preserved words");
                $fatal;
            end
        end
    endtask

    task test_empty_underflow;
        begin
            reset_fifo;
            read_word(32'h00000000);
            if (count !== 5'd0 || empty !== 1'b1 || underflow !== 1'b1) begin
                $display("FAIL: empty read did not keep count/empty and latch underflow");
                $fatal;
            end
        end
    endtask

    task test_clear_resets_state;
        begin
            reset_fifo;
            write_word(32'haaaaaaaa);
            reset_fifo;
            check_reset_state;
            write_word(32'h55555555);
            read_word(32'h55555555);
        end
    endtask

    task test_simultaneous_read_write;
        begin
            reset_fifo;
            write_word(32'h00000011);
            @(negedge clk);
            if (read_data !== 32'h00000011) begin
                $display("FAIL: unexpected head before simultaneous read/write");
                $fatal;
            end
            write_data = 32'h00000022;
            write_enable = 1'b1;
            read_enable = 1'b1;
            @(negedge clk);
            write_enable = 1'b0;
            read_enable = 1'b0;
            write_data = 32'd0;

            if (count !== 5'd1 || empty !== 1'b0 || full !== 1'b0) begin
                $display("FAIL: count/state wrong after simultaneous read/write");
                $fatal;
            end
            if (read_data !== 32'h00000022) begin
                $display("FAIL: data order broken after simultaneous read/write");
                $fatal;
            end
            read_word(32'h00000022);
            if (empty !== 1'b1 || count !== 5'd0) begin
                $display("FAIL: FIFO not empty after final simultaneous test read");
                $fatal;
            end
        end
    endtask
endmodule

`default_nettype wire
