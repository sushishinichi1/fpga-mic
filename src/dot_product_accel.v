`default_nettype none

module dot_product_accel (
    input  wire        clk,
    input  wire        reset,
    input  wire        start,
    input  wire        clear,
    input  wire [15:0] vector_length,
    output reg         fifo_read_enable,
    input  wire [31:0] fifo_read_data,
    input  wire        fifo_empty,
    input  wire [4:0]  fifo_count,
    output reg         busy,
    output reg         done,
    output reg         error,
    output reg signed [31:0] result,
    output reg [31:0] cycle_count
);

    localparam [1:0] STATE_IDLE  = 2'd0;
    localparam [1:0] STATE_READ  = 2'd1;
    localparam [1:0] STATE_ACCUM = 2'd2;

    reg [1:0] state;
    reg [15:0] processed_count;
    reg signed [31:0] accumulator;
    reg signed [7:0] input_value;
    reg signed [7:0] weight_value;
    reg signed [15:0] product;
    reg signed [31:0] next_accumulator;

    initial begin
        fifo_read_enable = 1'b0;
        busy = 1'b0;
        done = 1'b0;
        error = 1'b0;
        result = 32'sd0;
        cycle_count = 32'd0;
        state = STATE_IDLE;
        processed_count = 16'd0;
        accumulator = 32'sd0;
        input_value = 8'sd0;
        weight_value = 8'sd0;
        product = 16'sd0;
        next_accumulator = 32'sd0;
    end

    always @(posedge clk) begin
        fifo_read_enable <= 1'b0;

        if (reset || clear) begin
            busy <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
            result <= 32'sd0;
            cycle_count <= 32'd0;
            state <= STATE_IDLE;
            processed_count <= 16'd0;
            accumulator <= 32'sd0;
        end else begin
            if (busy && start) begin
                error <= 1'b1;
            end

            if (busy) begin
                cycle_count <= cycle_count + 32'd1;
            end

            case (state)
                STATE_IDLE: begin
                    if (start) begin
                        done <= 1'b0;
                        if ((vector_length == 16'd0) ||
                            (vector_length > 16'd16) ||
                            (vector_length > {11'd0, fifo_count})) begin
                            error <= 1'b1;
                        end else begin
                            busy <= 1'b1;
                            error <= 1'b0;
                            result <= 32'sd0;
                            cycle_count <= 32'd0;
                            processed_count <= 16'd0;
                            accumulator <= 32'sd0;
                            state <= STATE_READ;
                        end
                    end
                end

                STATE_READ: begin
                    if (fifo_empty) begin
                        busy <= 1'b0;
                        error <= 1'b1;
                        state <= STATE_IDLE;
                    end else begin
                        fifo_read_enable <= 1'b1;
                        state <= STATE_ACCUM;
                    end
                end

                STATE_ACCUM: begin
                    input_value = fifo_read_data[7:0];
                    weight_value = fifo_read_data[15:8];
                    product = $signed(input_value) * $signed(weight_value);
                    next_accumulator = accumulator + {{16{product[15]}}, product};
                    accumulator <= next_accumulator;

                    if (processed_count == vector_length - 16'd1) begin
                        result <= next_accumulator;
                        busy <= 1'b0;
                        done <= 1'b1;
                        state <= STATE_IDLE;
                    end else begin
                        processed_count <= processed_count + 16'd1;
                        state <= STATE_READ;
                    end
                end

                default: begin
                    state <= STATE_IDLE;
                end
            endcase
        end
    end

endmodule

`default_nettype wire
