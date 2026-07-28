`default_nettype none

module pwm_led (
    input  wire       clk,
    input  wire       enable,
    input  wire [7:0] duty,
    output wire       led_pin
);

    reg [7:0] pwm_counter;
    wire pwm_active;

    assign pwm_active = enable && (pwm_counter < duty);

    // LED0 is active low, so drive low while the PWM output is active.
    assign led_pin = ~pwm_active;

    initial begin
        pwm_counter = 8'd0;
    end

    always @(posedge clk) begin
        pwm_counter <= pwm_counter + 8'd1;
    end

endmodule

`default_nettype wire
