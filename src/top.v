`default_nettype none

// Tang Nano 9K の最上位モジュールです。
// 27MHz のクロックを数えて、LED0 だけを約1秒周期で点滅させます。
module top (
    input  wire clk,   // 基板上の 27MHz クロック入力
    output wire led0   // LED0 出力。Tang Nano 9K のLEDは Active Low です
);

    // 27MHz の半分である 13,500,000 クロックを数えると約0.5秒になります。
    // 0.5秒ごとに led_on を反転するので、LEDは約1秒周期で点滅します。
    localparam integer CLK_HZ = 27_000_000;
    localparam integer HALF_PERIOD_COUNT = CLK_HZ / 2;

    reg [24:0] blink_counter = 25'd0;
    reg        led_on = 1'b0;

    always @(posedge clk) begin
        if (blink_counter == HALF_PERIOD_COUNT - 1) begin
            blink_counter <= 25'd0;
            led_on <= ~led_on;
        end else begin
            blink_counter <= blink_counter + 25'd1;
        end
    end

    // Active Low なので、0を出すと点灯、1を出すと消灯します。
    assign led0 = ~led_on;

endmodule

`default_nettype wire
