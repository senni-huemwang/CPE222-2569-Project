`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: acl_driver
// Description: Simple SPI Mode-0 driver for Nexys A7-100T onboard ADXL362
//              3-axis accelerometer. Configures Measurement Mode (reg 0x2D=0x02)
//              and continuously polls signed 8-bit XDATA (0x08) & YDATA (0x09).
//////////////////////////////////////////////////////////////////////////////////
module acl_driver #(
    parameter integer CLK_FREQ_HZ = 80_000_000
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       acl_miso,
    output reg        acl_mosi,
    output reg        acl_sclk,
    output reg        acl_csn,
    output reg signed [7:0] acl_x,
    output reg signed [7:0] acl_y
);
    localparam integer HALF_SPI = CLK_FREQ_HZ / 2_000_000; // 1 MHz SCLK

    localparam [2:0] S_INIT_WAIT = 3'd0,
                     S_CFG_START = 3'd1,
                     S_CFG_SHIFT = 3'd2,
                     S_IDLE_WAIT = 3'd3,
                     S_RD_START  = 3'd4,
                     S_RD_SHIFT  = 3'd5;

    reg [2:0]  state;
    reg [19:0] wait_cnt;
    reg [6:0]  spi_div;
    reg [5:0]  bit_idx;
    reg [23:0] tx_cfg;
    reg [31:0] tx_rd;
    reg [15:0] rx_buf;

    always @(posedge clk) begin
        if (rst) begin
            state    <= S_INIT_WAIT;
            wait_cnt <= 20'd0;
            spi_div  <= 7'd0;
            bit_idx  <= 6'd0;
            acl_csn  <= 1'b1;
            acl_sclk <= 1'b0;
            acl_mosi <= 1'b0;
            acl_x    <= 8'sd0;
            acl_y    <= 8'sd0;
            tx_cfg   <= 24'h0A_2D_02; // Write reg 0x2D = 0x02 (Measure)
            tx_rd    <= 32'h0B_08_0000; // Read reg 0x08 (XDATA), 0x09 (YDATA)
            rx_buf   <= 16'd0;
        end else begin
            case (state)
                S_INIT_WAIT: begin
                    acl_csn  <= 1'b1;
                    acl_sclk <= 1'b0;
                    if (wait_cnt >= 20'd400_000) begin // ~5 ms startup
                        wait_cnt <= 20'd0;
                        state    <= S_CFG_START;
                    end else begin
                        wait_cnt <= wait_cnt + 20'd1;
                    end
                end

                S_CFG_START: begin
                    acl_csn  <= 1'b0;
                    acl_sclk <= 1'b0;
                    acl_mosi <= tx_cfg[23];
                    bit_idx  <= 6'd23;
                    spi_div  <= 7'd0;
                    state    <= S_CFG_SHIFT;
                end

                S_CFG_SHIFT: begin
                    if (spi_div >= HALF_SPI - 1) begin
                        spi_div <= 7'd0;
                        if (!acl_sclk) begin
                            acl_sclk <= 1'b1;
                        end else begin
                            acl_sclk <= 1'b0;
                            if (bit_idx == 6'd0) begin
                                acl_csn  <= 1'b1;
                                wait_cnt <= 20'd0;
                                state    <= S_IDLE_WAIT;
                            end else begin
                                bit_idx  <= bit_idx - 6'd1;
                                acl_mosi <= tx_cfg[bit_idx - 6'd1];
                            end
                        end
                    end else begin
                        spi_div <= spi_div + 7'd1;
                    end
                end

                S_IDLE_WAIT: begin
                    acl_csn  <= 1'b1;
                    acl_sclk <= 1'b0;
                    if (wait_cnt >= 20'd400_000) begin // ~200 Hz poll rate
                        wait_cnt <= 20'd0;
                        state    <= S_RD_START;
                    end else begin
                        wait_cnt <= wait_cnt + 20'd1;
                    end
                end

                S_RD_START: begin
                    acl_csn  <= 1'b0;
                    acl_sclk <= 1'b0;
                    acl_mosi <= tx_rd[31];
                    bit_idx  <= 6'd31;
                    spi_div  <= 7'd0;
                    state    <= S_RD_SHIFT;
                end

                S_RD_SHIFT: begin
                    if (spi_div >= HALF_SPI - 1) begin
                        spi_div <= 7'd0;
                        if (!acl_sclk) begin
                            acl_sclk <= 1'b1;
                            if (bit_idx <= 6'd15) begin
                                rx_buf[bit_idx[3:0]] <= acl_miso;
                            end
                        end else begin
                            acl_sclk <= 1'b0;
                            if (bit_idx == 6'd0) begin
                                acl_csn  <= 1'b1;
                                acl_x    <= $signed(rx_buf[15:8]);
                                acl_y    <= $signed(rx_buf[7:0]);
                                wait_cnt <= 20'd0;
                                state    <= S_IDLE_WAIT;
                            end else begin
                                bit_idx  <= bit_idx - 6'd1;
                                acl_mosi <= tx_rd[bit_idx - 6'd1];
                            end
                        end
                    end else begin
                        spi_div <= spi_div + 7'd1;
                    end
                end

                default: state <= S_INIT_WAIT;
            endcase
        end
    end

endmodule
