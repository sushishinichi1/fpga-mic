`default_nettype none

module top (
    input  wire clk,

    input  wire mic_sd,
    output reg  mic_sck,
    output reg  mic_ws,
    output wire mic_lr,

    output wire uart_tx,
    output wire led0
);

    localparam integer CLK_HZ    = 27000000;
    localparam integer BAUD_RATE = 115200;

    // 27 MHz / (2 * 6) = 2.25 MHz.
    // With 64 SCK clocks per stereo frame, the sample rate is about 35.16 kHz.
    localparam [3:0] SCK_DIV_MAX = 4'd5;

    // Send one debug line about every 100 ms.
    localparam [21:0] REPORT_INTERVAL = 22'd2700000;

    // INMP441 selects the left channel when L/R is low.
    // This output only works if the microphone L/R pin is wired to FPGA pin 28.
    assign mic_lr = 1'b0;

    reg [3:0]  sck_div;
    reg [5:0]  bit_pos;
    reg [23:0] shift_reg;
    reg [23:0] raw_sample;
    reg [23:0] peak_accum;
    reg [21:0] report_counter;
    reg        report_toggle;
    reg [21:0] led_hold;

    reg [23:0] report_raw;
    reg [23:0] report_peak;
    reg [7:0]  report_vol;

    wire [23:0] next_sample = {shift_reg[22:0], mic_sd};
    wire [23:0] next_abs    = abs24(next_sample);

    assign led0 = (led_hold != 22'd0) ? 1'b0 : 1'b1;

    function [23:0] abs24;
        input [23:0] value;
        begin
            if (value[23])
                abs24 = (~value) + 24'd1;
            else
                abs24 = value;
        end
    endfunction

    function [7:0] scale_peak;
        input [23:0] peak;
        begin
            // Softer than the previous fixed peak[22:15] mapping.
            // This is still only an initial view; tune it after reading PEAK.
            if (peak >= 24'd1044480)
                scale_peak = 8'd255;
            else
                scale_peak = peak[19:12];
        end
    endfunction

    initial begin
        mic_sck = 1'b0;
        mic_ws = 1'b0;
        sck_div = 4'd0;
        bit_pos = 6'd0;
        shift_reg = 24'd0;
        raw_sample = 24'd0;
        peak_accum = 24'd0;
        report_counter = 22'd0;
        report_toggle = 1'b0;
        led_hold = 22'd0;
        report_raw = 24'd0;
        report_peak = 24'd0;
        report_vol = 8'd0;
    end

    always @(posedge clk) begin
        if (led_hold != 22'd0)
            led_hold <= led_hold - 22'd1;

        if (report_counter == REPORT_INTERVAL - 22'd1) begin
            report_counter <= 22'd0;
            report_raw <= raw_sample;
            report_peak <= peak_accum;
            report_vol <= scale_peak(peak_accum);
            report_toggle <= ~report_toggle;
            peak_accum <= 24'd0;
        end else begin
            report_counter <= report_counter + 22'd1;
        end

        if (sck_div == SCK_DIV_MAX) begin
            sck_div <= 4'd0;
            mic_sck <= ~mic_sck;

            // INMP441 uses Philips I2S. The receiver samples SD on SCK rising
            // edges. The MSB is valid one SCK after the WS transition.
            if (mic_sck == 1'b0) begin
                if ((mic_ws == 1'b0) && (bit_pos >= 6'd1) && (bit_pos <= 6'd24)) begin
                    shift_reg <= next_sample;

                    // Only the first 24 bits in the 32-bit left-channel slot
                    // are audio data. The remaining 8 bits are ignored.
                    if (bit_pos == 6'd24) begin
                        raw_sample <= next_sample;

                        if (next_abs > peak_accum)
                            peak_accum <= next_abs;

                        if (next_abs > 24'd32768)
                            led_hold <= 22'd675000;
                    end
                end
            end

            // WS changes on SCK falling edges, after each 32-bit slot.
            if (mic_sck == 1'b1) begin
                if (bit_pos == 6'd31) begin
                    bit_pos <= 6'd0;
                    mic_ws <= ~mic_ws;
                end else begin
                    bit_pos <= bit_pos + 6'd1;
                end
            end
        end else begin
            sck_div <= sck_div + 4'd1;
        end
    end

    reg       uart_start;
    wire      uart_busy;
    reg [7:0] uart_data;

    uart_tx #(
        .CLK_HZ(CLK_HZ),
        .BAUD_RATE(BAUD_RATE)
    ) uart_tx_inst (
        .clk(clk),
        .start(uart_start),
        .data(uart_data),
        .busy(uart_busy),
        .tx(uart_tx)
    );

    localparam [3:0]
        TX_IDLE       = 4'd0,
        TX_RAW_LABEL  = 4'd1,
        TX_RAW_SIGN   = 4'd2,
        TX_RAW_DIGITS = 4'd3,
        TX_PEAK_LABEL = 4'd4,
        TX_PEAK_DIGITS= 4'd5,
        TX_VOL_LABEL  = 4'd6,
        TX_VOL_DIGITS = 4'd7,
        TX_NEWLINE    = 4'd8;

    reg [3:0] tx_state;
    reg [3:0] label_index;
    reg [2:0] digit_pos;
    reg       digit_started;

    reg [23:0] tx_raw;
    reg [23:0] tx_peak;
    reg [7:0]  tx_vol;
    reg        seen_report_toggle;

    wire        tx_raw_negative = tx_raw[23];
    wire [23:0] tx_raw_abs = tx_raw_negative ? ((~tx_raw) + 24'd1) : tx_raw;

    function [7:0] digit24;
        input [23:0] value;
        input [2:0]  pos;
        reg [23:0] quotient;
        begin
            case (pos)
                3'd6: quotient = value / 24'd1000000;
                3'd5: quotient = value / 24'd100000;
                3'd4: quotient = value / 24'd10000;
                3'd3: quotient = value / 24'd1000;
                3'd2: quotient = value / 24'd100;
                3'd1: quotient = value / 24'd10;
                default: quotient = value;
            endcase
            digit24 = "0" + (quotient % 24'd10);
        end
    endfunction

    function [7:0] digit8;
        input [7:0] value;
        input [1:0] pos;
        reg [7:0] quotient;
        begin
            case (pos)
                2'd2: quotient = value / 8'd100;
                2'd1: quotient = value / 8'd10;
                default: quotient = value;
            endcase
            digit8 = "0" + (quotient % 8'd10);
        end
    endfunction

    function digit24_nonzero;
        input [23:0] value;
        input [2:0]  pos;
        begin
            case (pos)
                3'd6: digit24_nonzero = (value >= 24'd1000000);
                3'd5: digit24_nonzero = (value >= 24'd100000);
                3'd4: digit24_nonzero = (value >= 24'd10000);
                3'd3: digit24_nonzero = (value >= 24'd1000);
                3'd2: digit24_nonzero = (value >= 24'd100);
                3'd1: digit24_nonzero = (value >= 24'd10);
                default: digit24_nonzero = 1'b1;
            endcase
        end
    endfunction

    function digit8_nonzero;
        input [7:0] value;
        input [1:0] pos;
        begin
            case (pos)
                2'd2: digit8_nonzero = (value >= 8'd100);
                2'd1: digit8_nonzero = (value >= 8'd10);
                default: digit8_nonzero = 1'b1;
            endcase
        end
    endfunction

    function [7:0] current_uart_data;
        input dummy;
        begin
            current_uart_data =
                (tx_state == TX_RAW_LABEL && label_index == 4'd0)  ? "R" :
                (tx_state == TX_RAW_LABEL && label_index == 4'd1)  ? "A" :
                (tx_state == TX_RAW_LABEL && label_index == 4'd2)  ? "W" :
                (tx_state == TX_RAW_LABEL && label_index == 4'd3)  ? ":" :
                (tx_state == TX_RAW_SIGN)                          ? "-" :
                (tx_state == TX_RAW_DIGITS)                        ? digit24(tx_raw_abs, digit_pos) :
                (tx_state == TX_PEAK_LABEL && label_index == 4'd0) ? " " :
                (tx_state == TX_PEAK_LABEL && label_index == 4'd1) ? "P" :
                (tx_state == TX_PEAK_LABEL && label_index == 4'd2) ? "E" :
                (tx_state == TX_PEAK_LABEL && label_index == 4'd3) ? "A" :
                (tx_state == TX_PEAK_LABEL && label_index == 4'd4) ? "K" :
                (tx_state == TX_PEAK_LABEL && label_index == 4'd5) ? ":" :
                (tx_state == TX_PEAK_DIGITS)                       ? digit24(tx_peak, digit_pos) :
                (tx_state == TX_VOL_LABEL && label_index == 4'd0)  ? " " :
                (tx_state == TX_VOL_LABEL && label_index == 4'd1)  ? "V" :
                (tx_state == TX_VOL_LABEL && label_index == 4'd2)  ? "O" :
                (tx_state == TX_VOL_LABEL && label_index == 4'd3)  ? "L" :
                (tx_state == TX_VOL_LABEL && label_index == 4'd4)  ? ":" :
                (tx_state == TX_VOL_DIGITS)                        ? digit8(tx_vol, digit_pos[1:0]) :
                                                                      8'h0a;
        end
    endfunction

    initial begin
        uart_start = 1'b0;
        uart_data = 8'h0a;
        tx_state = TX_IDLE;
        label_index = 4'd0;
        digit_pos = 3'd0;
        digit_started = 1'b0;
        tx_raw = 24'd0;
        tx_peak = 24'd0;
        tx_vol = 8'd0;
        seen_report_toggle = 1'b0;
    end

    always @(posedge clk) begin
        uart_start <= 1'b0;

        if (tx_state == TX_IDLE) begin
            if (seen_report_toggle != report_toggle) begin
                seen_report_toggle <= report_toggle;
                tx_raw <= report_raw;
                tx_peak <= report_peak;
                tx_vol <= report_vol;
                tx_state <= TX_RAW_LABEL;
                label_index <= 4'd0;
            end
        end else if (!uart_busy && !uart_start) begin
            case (tx_state)
                TX_RAW_LABEL: begin
                    uart_data <= current_uart_data(1'b0);
                    uart_start <= 1'b1;
                    if (label_index == 4'd3) begin
                        label_index <= 4'd0;
                        if (tx_raw_negative)
                            tx_state <= TX_RAW_SIGN;
                        else begin
                            tx_state <= TX_RAW_DIGITS;
                            digit_pos <= 3'd6;
                            digit_started <= 1'b0;
                        end
                    end else begin
                        label_index <= label_index + 4'd1;
                    end
                end

                TX_RAW_SIGN: begin
                    uart_data <= current_uart_data(1'b0);
                    uart_start <= 1'b1;
                    tx_state <= TX_RAW_DIGITS;
                    digit_pos <= 3'd6;
                    digit_started <= 1'b0;
                end

                TX_RAW_DIGITS: begin
                    if (digit_started || digit24_nonzero(tx_raw_abs, digit_pos)) begin
                        uart_data <= current_uart_data(1'b0);
                        uart_start <= 1'b1;
                        digit_started <= 1'b1;
                    end

                    if (digit_pos == 3'd0) begin
                        tx_state <= TX_PEAK_LABEL;
                        label_index <= 4'd0;
                    end else begin
                        digit_pos <= digit_pos - 3'd1;
                    end
                end

                TX_PEAK_LABEL: begin
                    uart_data <= current_uart_data(1'b0);
                    uart_start <= 1'b1;
                    if (label_index == 4'd5) begin
                        tx_state <= TX_PEAK_DIGITS;
                        label_index <= 4'd0;
                        digit_pos <= 3'd6;
                        digit_started <= 1'b0;
                    end else begin
                        label_index <= label_index + 4'd1;
                    end
                end

                TX_PEAK_DIGITS: begin
                    if (digit_started || digit24_nonzero(tx_peak, digit_pos)) begin
                        uart_data <= current_uart_data(1'b0);
                        uart_start <= 1'b1;
                        digit_started <= 1'b1;
                    end

                    if (digit_pos == 3'd0) begin
                        tx_state <= TX_VOL_LABEL;
                        label_index <= 4'd0;
                    end else begin
                        digit_pos <= digit_pos - 3'd1;
                    end
                end

                TX_VOL_LABEL: begin
                    uart_data <= current_uart_data(1'b0);
                    uart_start <= 1'b1;
                    if (label_index == 4'd4) begin
                        tx_state <= TX_VOL_DIGITS;
                        label_index <= 4'd0;
                        digit_pos <= 3'd2;
                        digit_started <= 1'b0;
                    end else begin
                        label_index <= label_index + 4'd1;
                    end
                end

                TX_VOL_DIGITS: begin
                    if (digit_started || digit8_nonzero(tx_vol, digit_pos[1:0])) begin
                        uart_data <= current_uart_data(1'b0);
                        uart_start <= 1'b1;
                        digit_started <= 1'b1;
                    end

                    if (digit_pos == 3'd0) begin
                        tx_state <= TX_NEWLINE;
                    end else begin
                        digit_pos <= digit_pos - 3'd1;
                    end
                end

                default: begin
                    uart_data <= current_uart_data(1'b0);
                    uart_start <= 1'b1;
                    tx_state <= TX_IDLE;
                end
            endcase
        end
    end

endmodule

`default_nettype wire
