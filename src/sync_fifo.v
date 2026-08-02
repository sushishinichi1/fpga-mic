`default_nettype none

module sync_fifo #(
    parameter integer DATA_WIDTH = 32,
    parameter integer DEPTH = 16
) (
    input  wire                  clk,
    input  wire                  reset,
    input  wire                  write_enable,
    input  wire [DATA_WIDTH-1:0] write_data,
    input  wire                  read_enable,
    output reg  [DATA_WIDTH-1:0] read_data,
    output wire                  full,
    output wire                  empty,
    output reg  [4:0]            count,
    output reg                   overflow,
    output reg                   underflow
);

    reg [DATA_WIDTH-1:0] memory [0:DEPTH-1];
    reg [3:0] write_pointer;
    reg [3:0] read_pointer;
    localparam [4:0] DEPTH_COUNT = DEPTH;
    localparam [3:0] DEPTH_LAST = DEPTH - 1;

    wire read_valid;
    wire write_valid;

    assign empty = (count == 5'd0);
    assign full = (count == DEPTH_COUNT);
    assign read_valid = read_enable && !empty;
    assign write_valid = write_enable && (!full || read_valid);

    integer index;

    initial begin
        read_data = {DATA_WIDTH{1'b0}};
        write_pointer = 4'd0;
        read_pointer = 4'd0;
        count = 5'd0;
        overflow = 1'b0;
        underflow = 1'b0;
        for (index = 0; index < DEPTH; index = index + 1) begin
            memory[index] = {DATA_WIDTH{1'b0}};
        end
    end

    always @(*) begin
        if (!empty) begin
            read_data = memory[read_pointer];
        end else begin
            read_data = {DATA_WIDTH{1'b0}};
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            write_pointer <= 4'd0;
            read_pointer <= 4'd0;
            count <= 5'd0;
            overflow <= 1'b0;
            underflow <= 1'b0;
        end else begin
            if (write_enable && full && !read_valid) begin
                overflow <= 1'b1;
            end

            if (read_enable && empty) begin
                underflow <= 1'b1;
            end

            if (write_valid) begin
                memory[write_pointer] <= write_data;
                if (write_pointer == DEPTH_LAST) begin
                    write_pointer <= 4'd0;
                end else begin
                    write_pointer <= write_pointer + 4'd1;
                end
            end

            if (read_valid) begin
                if (read_pointer == DEPTH_LAST) begin
                    read_pointer <= 4'd0;
                end else begin
                    read_pointer <= read_pointer + 4'd1;
                end
            end

            case ({write_valid, read_valid})
                2'b10: count <= count + 5'd1;
                2'b01: count <= count - 5'd1;
                default: count <= count;
            endcase
        end
    end

endmodule

`default_nettype wire
