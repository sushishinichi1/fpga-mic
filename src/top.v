`default_nettype none

module top (
    input  wire clk,
    input  wire button,
    output wire led0
);

    // Synchronize the external button input to the FPGA clock.
    reg button_sync_0 = 1'b1;
    reg button_sync_1 = 1'b1;
    reg button_prev   = 1'b1;

    // Store the LED state.
    reg led_on = 1'b0;

    always @(posedge clk) begin
        button_sync_0 <= button;
        button_sync_1 <= button_sync_0;
        button_prev   <= button_sync_1;

        // The button is Active Low.
        // Toggle the LED when the button changes from 1 to 0.
        if ((button_prev == 1'b1) && (button_sync_1 == 1'b0)) begin
            led_on <= ~led_on;
        end
    end

    // LED0 is Active Low.
    assign led0 = ~led_on;

endmodule

`default_nettype wire