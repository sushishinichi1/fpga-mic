`default_nettype none

module register_bus (
    input  wire        clk,
    input  wire        reg_req,
    input  wire        reg_write,
    input  wire [7:0]  reg_addr,
    input  wire [31:0] reg_wdata,
    input  wire [31:0] counter_value,
    input  wire [7:0]  spi_rx_data,
    input  wire        spi_busy,
    input  wire        spi_done,
    input  wire [31:0] fifo_read_data,
    input  wire        fifo_empty,
    input  wire        fifo_full,
    input  wire [4:0]  fifo_count,
    input  wire        fifo_overflow,
    input  wire        fifo_underflow,
    input  wire        accel_busy,
    input  wire        accel_done,
    input  wire        accel_error,
    input  wire [31:0] accel_result,
    input  wire [31:0] accel_cycle_count,
    output reg  [31:0] reg_rdata,
    output reg         reg_ready,
    output reg         reg_error,
    output reg         counter_reset_pulse,
    output reg         led_on,
    output reg  [7:0]  led_pwm_duty,
    output reg  [7:0]  spi_tx_data,
    output reg         spi_start_pulse,
    output reg         fifo_write_pulse,
    output reg  [31:0] fifo_write_data,
    output reg         fifo_read_pulse,
    output reg         fifo_clear_pulse,
    output reg         accel_start_pulse,
    output reg         accel_clear_pulse,
    output reg  [15:0] accel_vector_length
);

    localparam [7:0] ADDR_COUNTER = 8'h00;
    localparam [7:0] ADDR_CONTROL = 8'h04;
    localparam [7:0] ADDR_LED     = 8'h08;
    localparam [7:0] ADDR_LED_PWM = 8'h0c;
    localparam [7:0] ADDR_SPI_TX      = 8'h10;
    localparam [7:0] ADDR_SPI_RX      = 8'h14;
    localparam [7:0] ADDR_SPI_CONTROL = 8'h18;
    localparam [7:0] ADDR_SPI_STATUS  = 8'h1c;
    localparam [7:0] ADDR_FIFO_WRITE    = 8'h20;
    localparam [7:0] ADDR_FIFO_READ     = 8'h24;
    localparam [7:0] ADDR_FIFO_STATUS   = 8'h28;
    localparam [7:0] ADDR_FIFO_CONTROL  = 8'h2c;
    localparam [7:0] ADDR_ACCEL_CONTROL = 8'h30;
    localparam [7:0] ADDR_ACCEL_STATUS  = 8'h34;
    localparam [7:0] ADDR_VECTOR_LENGTH = 8'h38;
    localparam [7:0] ADDR_ACCEL_RESULT  = 8'h3c;
    localparam [7:0] ADDR_ACCEL_CYCLES  = 8'h40;

    reg spi_done_latched;
    reg spi_error_latched;
    reg accel_done_latched;

    initial begin
        reg_rdata = 32'd0;
        reg_ready = 1'b0;
        reg_error = 1'b0;
        counter_reset_pulse = 1'b0;
        led_on = 1'b0;
        led_pwm_duty = 8'hff;
        spi_tx_data = 8'h00;
        spi_start_pulse = 1'b0;
        fifo_write_pulse = 1'b0;
        fifo_write_data = 32'd0;
        fifo_read_pulse = 1'b0;
        fifo_clear_pulse = 1'b0;
        accel_start_pulse = 1'b0;
        accel_clear_pulse = 1'b0;
        accel_vector_length = 16'd0;
        spi_done_latched = 1'b0;
        spi_error_latched = 1'b0;
        accel_done_latched = 1'b0;
    end

    always @(posedge clk) begin
        reg_ready <= 1'b0;
        reg_error <= 1'b0;
        counter_reset_pulse <= 1'b0;
        spi_start_pulse <= 1'b0;
        fifo_write_pulse <= 1'b0;
        fifo_read_pulse <= 1'b0;
        fifo_clear_pulse <= 1'b0;
        accel_start_pulse <= 1'b0;
        accel_clear_pulse <= 1'b0;

        if (spi_done) begin
            spi_done_latched <= 1'b1;
        end

        if (accel_done) begin
            accel_done_latched <= 1'b1;
        end

        if (reg_req) begin
            reg_ready <= 1'b1;

            if (reg_write) begin
                case (reg_addr)
                    ADDR_CONTROL: begin
                        if (reg_wdata[0]) begin
                            counter_reset_pulse <= 1'b1;
                        end
                    end

                    ADDR_LED: begin
                        led_on <= reg_wdata[0];
                    end

                    ADDR_LED_PWM: begin
                        led_pwm_duty <= reg_wdata[7:0];
                    end

                    ADDR_SPI_TX: begin
                        spi_tx_data <= reg_wdata[7:0];
                    end

                    ADDR_SPI_CONTROL: begin
                        if (reg_wdata[0]) begin
                            if (!spi_busy) begin
                                spi_start_pulse <= 1'b1;
                                spi_done_latched <= 1'b0;
                                spi_error_latched <= 1'b0;
                            end else begin
                                spi_error_latched <= 1'b1;
                            end
                        end
                    end

                    ADDR_FIFO_WRITE: begin
                        fifo_write_data <= reg_wdata;
                        fifo_write_pulse <= 1'b1;
                    end

                    ADDR_FIFO_CONTROL: begin
                        if (reg_wdata[0]) begin
                            fifo_clear_pulse <= 1'b1;
                        end
                    end

                    ADDR_ACCEL_CONTROL: begin
                        if (reg_wdata[1]) begin
                            accel_clear_pulse <= 1'b1;
                            accel_done_latched <= 1'b0;
                        end
                        if (reg_wdata[0]) begin
                            accel_start_pulse <= 1'b1;
                            accel_done_latched <= 1'b0;
                        end
                    end

                    ADDR_VECTOR_LENGTH: begin
                        accel_vector_length <= reg_wdata[15:0];
                    end

                    default: begin
                        reg_error <= 1'b1;
                    end
                endcase
            end else begin
                case (reg_addr)
                    ADDR_COUNTER: begin
                        reg_rdata <= counter_value;
                    end

                    ADDR_LED: begin
                        reg_rdata <= {31'd0, led_on};
                    end

                    ADDR_LED_PWM: begin
                        reg_rdata <= {24'd0, led_pwm_duty};
                    end

                    ADDR_SPI_TX: begin
                        reg_rdata <= {24'd0, spi_tx_data};
                    end

                    ADDR_SPI_RX: begin
                        reg_rdata <= {24'd0, spi_rx_data};
                    end

                    ADDR_SPI_STATUS: begin
                        reg_rdata <= {29'd0, spi_error_latched, spi_done_latched, spi_busy};
                        spi_done_latched <= 1'b0;
                    end

                    ADDR_FIFO_READ: begin
                        reg_rdata <= fifo_read_data;
                        fifo_read_pulse <= 1'b1;
                    end

                    ADDR_FIFO_STATUS: begin
                        reg_rdata <= {
                            19'd0,
                            fifo_count,
                            4'd0,
                            fifo_underflow,
                            fifo_overflow,
                            fifo_full,
                            fifo_empty
                        };
                    end

                    ADDR_VECTOR_LENGTH: begin
                        reg_rdata <= {16'd0, accel_vector_length};
                    end

                    ADDR_ACCEL_STATUS: begin
                        reg_rdata <= {29'd0, accel_error, accel_done_latched, accel_busy};
                        accel_done_latched <= 1'b0;
                    end

                    ADDR_ACCEL_RESULT: begin
                        reg_rdata <= accel_result;
                    end

                    ADDR_ACCEL_CYCLES: begin
                        reg_rdata <= accel_cycle_count;
                    end

                    default: begin
                        reg_rdata <= 32'd0;
                        reg_error <= 1'b1;
                    end
                endcase
            end
        end
    end

endmodule

`default_nettype wire
