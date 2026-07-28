`default_nettype none

module press_counter (
    input  wire        clk,
    input  wire        reset,
    input  wire        increment,
    output reg  [31:0] count
);

    initial begin
        count = 32'd0;
    end

    always @(posedge clk) begin
        if (reset) begin
            count <= 32'd0;
        end else if (increment) begin
            count <= count + 32'd1;
        end
    end

endmodule

`default_nettype wire
