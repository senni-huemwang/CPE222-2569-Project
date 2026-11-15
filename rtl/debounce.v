`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: debounce
// Description: 2-FF input synchronizer + 20ms glitch-free button debouncer
//              for 100 MHz system clock.
//////////////////////////////////////////////////////////////////////////////////
module debounce #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer DEBOUNCE_MS = 20
)(
    input  wire clk,
    input  wire rst,
    input  wire btn_in,
    output reg  btn_out,
    output wire btn_rise
);
    localparam integer MAX_CNT = (CLK_FREQ_HZ / 1000) * DEBOUNCE_MS;

    reg sync_0, sync_1;
    reg [21:0] cnt;
    reg prev_out;

    always @(posedge clk) begin
        if (rst) begin
            sync_0   <= 1'b0;
            sync_1   <= 1'b0;
            cnt      <= 22'd0;
            btn_out  <= 1'b0;
            prev_out <= 1'b0;
        end else begin
            sync_0   <= btn_in;
            sync_1   <= sync_0;
            prev_out <= btn_out;

            if (sync_1 == btn_out) begin
                cnt <= 22'd0;
            end else if (cnt >= MAX_CNT - 1) begin
                btn_out <= sync_1;
                cnt     <= 22'd0;
            end else begin
                cnt <= cnt + 22'd1;
            end
        end
    end

    assign btn_rise = btn_out & ~prev_out;

endmodule
