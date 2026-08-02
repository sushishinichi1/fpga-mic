`timescale 1ns / 1ps
`default_nettype none

module dot_product_accel_tb;
    reg clk;
    reg reset;
    reg start;
    reg clear;
    reg [15:0] vector_length;
    wire fifo_read_enable;
    reg [31:0] fifo_read_data;
    reg fifo_empty;
    reg [4:0] fifo_count;
    wire busy;
    wire done;
    wire error;
    wire signed [31:0] result;
    wire [31:0] cycle_count;

    reg [31:0] vector [0:15];
    integer read_index;

    dot_product_accel dut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .clear(clear),
        .vector_length(vector_length),
        .fifo_read_enable(fifo_read_enable),
        .fifo_read_data(fifo_read_data),
        .fifo_empty(fifo_empty),
        .fifo_count(fifo_count),
        .busy(busy),
        .done(done),
        .error(error),
        .result(result),
        .cycle_count(cycle_count)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always @(*) begin
        if (!fifo_empty) begin
            fifo_read_data = vector[read_index];
        end else begin
            fifo_read_data = 32'd0;
        end
    end

    always @(posedge clk) begin
        if (fifo_read_enable) begin
            read_index <= read_index + 1;
            fifo_count <= fifo_count - 5'd1;
            if (fifo_count == 5'd1) begin
                fifo_empty <= 1'b1;
            end
        end
    end

    initial begin
        reset = 1'b1;
        start = 1'b0;
        clear = 1'b0;
        vector_length = 16'd0;
        fifo_empty = 1'b1;
        fifo_count = 5'd0;
        read_index = 0;
        repeat (2) @(posedge clk);
        reset = 1'b0;

        run_case_70;
        run_case_negative_70;
        run_error_cases;

        $finish;
    end

    task start_and_wait;
        begin
            start = 1'b1;
            @(posedge clk);
            start = 1'b0;
            while (busy) begin
                @(posedge clk);
            end
            @(posedge clk);
        end
    endtask

    task clear_accel;
        begin
            clear = 1'b1;
            @(posedge clk);
            clear = 1'b0;
            @(posedge clk);
            read_index = 0;
        end
    endtask

    task run_case_70;
        begin
            clear_accel;
            vector[0] = 32'h00000501;
            vector[1] = 32'h00000602;
            vector[2] = 32'h00000703;
            vector[3] = 32'h00000804;
            vector_length = 16'd4;
            fifo_count = 5'd4;
            fifo_empty = 1'b0;
            start_and_wait;
            if (!done || error || result != 32'sd70) $stop;
        end
    endtask

    task run_case_negative_70;
        begin
            clear_accel;
            vector[0] = 32'h000005ff;
            vector[1] = 32'h0000fa02;
            vector[2] = 32'h000007fd;
            vector[3] = 32'h0000f804;
            vector_length = 16'd4;
            fifo_count = 5'd4;
            fifo_empty = 1'b0;
            start_and_wait;
            if (!done || error || result != -32'sd70) $stop;
        end
    endtask

    task run_error_cases;
        begin
            clear_accel;
            vector_length = 16'd0;
            fifo_count = 5'd0;
            fifo_empty = 1'b1;
            start_and_wait;
            if (!error) $stop;

            clear_accel;
            vector_length = 16'd4;
            fifo_count = 5'd2;
            fifo_empty = 1'b0;
            start_and_wait;
            if (!error) $stop;
        end
    endtask
endmodule

`default_nettype wire
