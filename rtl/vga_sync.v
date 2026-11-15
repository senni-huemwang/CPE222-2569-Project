`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: vga_sync
// Description: 640x480 @ 60Hz VGA timing generator using a 25 MHz pixel enable
//              derived from the 100 MHz system clock.
//////////////////////////////////////////////////////////////////////////////////
module vga_sync (
    input  wire       clk,
    input  wire       rst,
    output wire       pix_en,
    output wire [9:0] pix_x,
    output wire [9:0] pix_y,
    output wire       video_on,
    output reg        hsync,
    output reg        vsync,
    output wire       frame_tick
);
    // 640x480 @ 60Hz standard VGA timings
    localparam integer H_DISPLAY = 640;
    localparam integer H_FP      = 16;
    localparam integer H_SYNC    = 96;
    localparam integer H_BP      = 48;
    localparam integer H_TOTAL   = H_DISPLAY + H_FP + H_SYNC + H_BP; // 800

    localparam integer V_DISPLAY = 480;
    localparam integer V_FP      = 10;
    localparam integer V_SYNC    = 2;
    localparam integer V_BP      = 33;
    localparam integer V_TOTAL   = V_DISPLAY + V_FP + V_SYNC + V_BP; // 525

    reg [1:0] clk_div;
    reg [9:0] h_cnt;
    reg [9:0] v_cnt;

    assign pix_en     = (clk_div == 2'd3);
    assign pix_x      = h_cnt;
    assign pix_y      = v_cnt;
    assign video_on   = (h_cnt < H_DISPLAY) && (v_cnt < V_DISPLAY);
    assign frame_tick = pix_en && (h_cnt == 10'd0) && (v_cnt == V_DISPLAY);

    always @(posedge clk) begin
        if (rst) begin
            clk_div <= 2'd0;
            h_cnt   <= 10'd0;
            v_cnt   <= 10'd0;
            hsync   <= 1'b1;
            vsync   <= 1'b1;
        end else begin
            clk_div <= clk_div + 2'd1;

            if (pix_en) begin
                if (h_cnt == H_TOTAL - 1) begin
                    h_cnt <= 10'd0;
                    if (v_cnt == V_TOTAL - 1) begin
                        v_cnt <= 10'd0;
                    end else begin
                        v_cnt <= v_cnt + 10'd1;
                    end
                end else begin
                    h_cnt <= h_cnt + 10'd1;
                end
            end

            // Registered sync outputs (active LOW)
            hsync <= ~((h_cnt >= (H_DISPLAY + H_FP)) &&
                       (h_cnt <  (H_DISPLAY + H_FP + H_SYNC)));
            vsync <= ~((v_cnt >= (V_DISPLAY + V_FP)) &&
                       (v_cnt <  (V_DISPLAY + V_FP + V_SYNC)));
        end
    end

endmodule
