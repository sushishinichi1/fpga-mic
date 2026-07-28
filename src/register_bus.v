`default_nettype none

module register_bus (
    input  wire        clk,
    input  wire        reg_req,
    input  wire        reg_write,
    input  wire [7:0]  reg_addr,
    input  wire [31:0] reg_wdata,
    input  wire [31:0] counter_value,
    output reg  [31:0] reg_rdata,
    output reg         reg_ready,
    output reg         reg_error,
    output reg         counter_reset_pulse,
    output reg         led_on
);

    localparam [7:0] ADDR_COUNTER = 8'h00;
    localparam [7:0] ADDR_CONTROL = 8'h04;
    localparam [7:0] ADDR_LED     = 8'h08;

    initial begin
        reg_rdata = 32'd0;
        reg_ready = 1'b0;
        reg_error = 1'b0;
        counter_reset_pulse = 1'b0;
        led_on = 1'b0;
    end

    always @(posedge clk) begin
        reg_ready <= 1'b0;
        reg_error <= 1'b0;
        counter_reset_pulse <= 1'b0;

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
