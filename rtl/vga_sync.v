`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: vga_sync
// Description: 800x600 @ 60Hz VESA VGA timing generator using a 40 MHz pixel
//              enable derived from the 80 MHz system clock.
//////////////////////////////////////////////////////////////////////////////////
module vga_sync (
    input  wire        clk,
    input  wire        rst,
    output wire        pix_en,
    output wire [10:0] pix_x,
    output wire [9:0]  pix_y,
    output wire        video_on,
    output reg         hsync,
    output reg         vsync,
    output wire        frame_tick
);
    localparam integer H_DISPLAY = 800;
    localparam integer H_FP      = 40;
    localparam integer H_SYNC    = 128;
    localparam integer H_BP      = 88;
    localparam integer H_TOTAL   = H_DISPLAY + H_FP + H_SYNC + H_BP; // 1056

    localparam integer V_DISPLAY = 600;
    localparam integer V_FP      = 1;
    localparam integer V_SYNC    = 4;
    localparam integer V_BP      = 23;
    localparam integer V_TOTAL   = V_DISPLAY + V_FP + V_SYNC + V_BP; // 628

    reg        clk_div;
    reg [10:0] h_cnt;
    reg [9:0]  v_cnt;

    assign pix_en     = clk_div;
    assign pix_x      = h_cnt;
    assign pix_y      = v_cnt;
    assign video_on   = (h_cnt < H_DISPLAY) && (v_cnt < V_DISPLAY);
    assign frame_tick = pix_en && (h_cnt == 11'd0) && (v_cnt == V_DISPLAY);

    always @(posedge clk) begin
        if (rst) begin
            clk_div <= 1'b0;
            h_cnt   <= 11'd0;
            v_cnt   <= 10'd0;
            hsync   <= 1'b0;
            vsync   <= 1'b0;
        end else begin
            clk_div <= ~clk_div;

            if (pix_en) begin
                if (h_cnt == H_TOTAL - 1) begin
                    h_cnt <= 11'd0;
                    if (v_cnt == V_TOTAL - 1) v_cnt <= 10'd0;
                    else                      v_cnt <= v_cnt + 10'd1;
                end else begin
                    h_cnt <= h_cnt + 11'd1;
                end
            end

            // VESA 800x600@60Hz uses positive sync pulses
            hsync <= (h_cnt >= (H_DISPLAY + H_FP)) &&
                     (h_cnt <  (H_DISPLAY + H_FP + H_SYNC));
            vsync <= (v_cnt >= (V_DISPLAY + V_FP)) &&
                     (v_cnt <  (V_DISPLAY + V_FP + V_SYNC));
        end
    end

endmodule
