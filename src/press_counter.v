`default_nettype none

module press_counter (
    input  wire        clk,
    input  wire        increment,
    output reg  [31:0] count
);

    initial begin
        count = 32'd0;
    end

    always @(posedge clk) begin
        if (increment) begin
            count <= count + 32'd1;
        end
    end

endmodule

`default_nettype wire
