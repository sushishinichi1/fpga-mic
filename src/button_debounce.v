`default_nettype none

module button_debounce #(
    parameter integer CLK_HZ = 27000000,
    parameter integer DEBOUNCE_MS = 20
) (
    input  wire clk,
    input  wire button_n,
    output reg  press_pulse
);

    localparam integer DEBOUNCE_CYCLES = (CLK_HZ / 1000) * DEBOUNCE_MS;

    reg button_sync_0;
    reg button_sync_1;
    reg button_stable;
    reg button_prev;
    reg [19:0] debounce_counter;

    initial begin
        button_sync_0 = 1'b1;
        button_sync_1 = 1'b1;
        button_stable = 1'b1;
        button_prev = 1'b1;
        debounce_counter = 20'd0;
        press_pulse = 1'b0;
    end

    always @(posedge clk) begin
        button_sync_0 <= button_n;
        button_sync_1 <= button_sync_0;
        press_pulse <= 1'b0;

        if (button_sync_1 != button_stable) begin
            if (debounce_counter == DEBOUNCE_CYCLES - 1) begin
                button_stable <= button_sync_1;
                debounce_counter <= 20'd0;
            end else begin
                debounce_counter <= debounce_counter + 20'd1;
            end
        end else begin
            debounce_counter <= 20'd0;
        end

        button_prev <= button_stable;

        // The button is active low, so a stable 1-to-0 transition is one press.
        if ((button_prev == 1'b1) && (button_stable == 1'b0)) begin
            press_pulse <= 1'b1;
        end
    end

endmodule

`default_nettype wire
