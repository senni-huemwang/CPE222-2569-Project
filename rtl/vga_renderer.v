`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: vga_renderer
// Description: On-the-fly 640x480 12-bit RGB444 Pixel Art renderer:
//              sky gradient, scrolling clouds, 3 shaded pixel pipes, scrolling
//              grass/dirt ground, 48x48 Pigeon AI sprite, voice meter bar,
//              live score HUD, and IDLE / PAUSED / GAME OVER banners.
//////////////////////////////////////////////////////////////////////////////////
module vga_renderer (
    input  wire        clk,
    input  wire        rst,
    input  wire        pix_en,
    input  wire        video_on,
    input  wire [9:0]  pix_x,
    input  wire [9:0]  pix_y,
    // Game state inputs
    input  wire [1:0]  state,
    input  wire [9:0]  bird_y,
    input  wire        bird_pose,
    input  wire signed [10:0] pipe0_x,
    input  wire signed [10:0] pipe1_x,
    input  wire signed [10:0] pipe2_x,
    input  wire [9:0]  pipe0_gap_y,
    input  wire [9:0]  pipe1_gap_y,
    input  wire [9:0]  pipe2_gap_y,
    input  wire [9:0]  pipe_gap_h,
    input  wire [9:0]  ground_scroll,
    input  wire [9:0]  cloud_scroll,
    input  wire [15:0] score_bcd,
    input  wire [15:0] high_score_bcd,
    // Voice HUD inputs
    input  wire [7:0]  volume,
    input  wire [7:0]  threshold,
    input  wire        voice_active,
    // VGA RGB444 outputs
    output reg  [3:0]  vga_r,
    output reg  [3:0]  vga_g,
    output reg  [3:0]  vga_b
);
    localparam [1:0] ST_IDLE     = 2'd0,
                     ST_PLAY     = 2'd1,
                     ST_PAUSE    = 2'd2,
                     ST_GAMEOVER = 2'd3;

    localparam integer BIRD_X   = 120;
    localparam integer GROUND_Y = 440;
    localparam integer PIPE_W   = 56;
    localparam integer CAP_H    = 22;

    wire signed [10:0] sx = $signed({1'b0, pix_x});
    wire signed [10:0] sy = $signed({1'b0, pix_y});

    // -------------------------------------------------------------------------
    // 1. Pigeon AI 48x48 Sprite ROM
    // -------------------------------------------------------------------------
    wire in_bird_box = (pix_x >= BIRD_X) && (pix_x < BIRD_X + 48) &&
                       (pix_y >= bird_y) && (pix_y < bird_y + 48);
    wire [5:0] bird_dx = pix_x - BIRD_X;
    wire [5:0] bird_dy = pix_y - bird_y;
    wire [11:0] bird_rgb;

    pigeon_rom u_pigeon_rom (
        .clk     (clk),
        .pose    (bird_pose),
        .x       (in_bird_box ? bird_dx : 6'd0),
        .y       (in_bird_box ? bird_dy : 6'd0),
        .rgb_out (bird_rgb)
    );

    wire bird_pixel_on = in_bird_box && (bird_rgb != 12'hF0F);

    // -------------------------------------------------------------------------
    // 2. Text & Font ROM Mux (non-overlapping HUD and Banner regions)
    // -------------------------------------------------------------------------
    reg        in_text_box;
    reg [6:0]  font_char;
    reg [2:0]  font_row;
    reg [2:0]  font_col;
    reg [11:0] text_color;
    wire       font_pix_on;

    font_rom u_font_rom (
        .clk       (clk),
        .char_code (font_char),
        .row       (font_row),
        .col       (font_col),
        .pix_on    (font_pix_on)
    );

    // Helper coordinates for text regions
    reg [3:0] ch_idx;
    reg [9:0] rel_tx, rel_ty;

    always @(*) begin
        in_text_box = 1'b0;
        font_char   = 7'h20;
        font_row    = 3'd0;
        font_col    = 3'd0;
        text_color  = 12'hFFF;
        ch_idx      = 4'd0;
        rel_tx      = 10'd0;
        rel_ty      = 10'd0;

        // A) Live Score HUD (top-center, 3x scale: 3 digits * 24px = 72px, X=284..355, Y=16..39)
        if ((state == ST_PLAY || state == ST_PAUSE) &&
            (pix_x >= 10'd284) && (pix_x < 10'd356) &&
            (pix_y >= 10'd16)  && (pix_y < 10'd40)) begin
            in_text_box = 1'b1;
            rel_tx = pix_x - 10'd284;
            rel_ty = pix_y - 10'd16;
            // Divide by 24 via comparison (clean, no divider)
            if (rel_tx < 10'd24) begin
                font_char = {3'b011, score_bcd[11:8]};
                font_col  = rel_tx / 3;
            end else if (rel_tx < 10'd48) begin
                font_char = {3'b011, score_bcd[7:4]};
                font_col  = (rel_tx - 10'd24) / 3;
            end else begin
                font_char = {3'b011, score_bcd[3:0]};
                font_col  = (rel_tx - 10'd48) / 3;
            end
            font_row   = rel_ty / 3;
            text_color = 12'hFFF;
        end
        // B) IDLE Banner Line 1: "FLAPPY PIGEON" (13 chars @ 3x = 312px, X=164..475, Y=96..119)
        else if ((state == ST_IDLE) &&
                 (pix_x >= 10'd164) && (pix_x < 10'd476) &&
                 (pix_y >= 10'd96)  && (pix_y < 10'd120)) begin
            in_text_box = 1'b1;
            rel_tx = pix_x - 10'd164;
            rel_ty = pix_y - 10'd96;
            ch_idx = rel_tx / 24;
            font_col = (rel_tx % 24) / 3;
            font_row = rel_ty / 3;
            text_color = 12'hFD2;
            case (ch_idx)
                4'd0:  font_char = 7'h46; // F
                4'd1:  font_char = 7'h4C; // L
                4'd2:  font_char = 7'h41; // A
                4'd3:  font_char = 7'h50; // P
                4'd4:  font_char = 7'h50; // P
                4'd5:  font_char = 7'h59; // Y
                4'd6:  font_char = 7'h20; // ' '
                4'd7:  font_char = 7'h50; // P
                4'd8:  font_char = 7'h49; // I
                4'd9:  font_char = 7'h47; // G
                4'd10: font_char = 7'h45; // E
                4'd11: font_char = 7'h4F; // O
                4'd12: font_char = 7'h4E; // N
                default: font_char = 7'h20;
            endcase
        end
        // C) IDLE Banner Line 2: "SPEAK OR BTNC" (13 chars @ 2x = 208px, X=216..423, Y=136..151)
        else if ((state == ST_IDLE) &&
                 (pix_x >= 10'd216) && (pix_x < 10'd424) &&
                 (pix_y >= 10'd136) && (pix_y < 10'd152)) begin
            in_text_box = 1'b1;
            rel_tx = pix_x - 10'd216;
            rel_ty = pix_y - 10'd136;
            ch_idx = rel_tx[7:4];
            font_col = rel_tx[3:1];
            font_row = rel_ty[3:1];
            text_color = 12'hFFF;
            case (ch_idx)
                4'd0:  font_char = 7'h53; // S
                4'd1:  font_char = 7'h50; // P
                4'd2:  font_char = 7'h45; // E
                4'd3:  font_char = 7'h41; // A
                4'd4:  font_char = 7'h4B; // K
                4'd5:  font_char = 7'h20; // ' '
                4'd6:  font_char = 7'h4F; // O
                4'd7:  font_char = 7'h52; // R
                4'd8:  font_char = 7'h20; // ' '
                4'd9:  font_char = 7'h42; // B
                4'd10: font_char = 7'h54; // T
                4'd11: font_char = 7'h4E; // N
                4'd12: font_char = 7'h43; // C
                default: font_char = 7'h20;
            endcase
        end
        // D) PAUSED Banner: "PAUSED" (6 chars @ 3x = 144px, X=248..391, Y=208..231)
        else if ((state == ST_PAUSE) &&
                 (pix_x >= 10'd248) && (pix_x < 10'd392) &&
                 (pix_y >= 10'd208) && (pix_y < 10'd232)) begin
            in_text_box = 1'b1;
            rel_tx = pix_x - 10'd248;
            rel_ty = pix_y - 10'd208;
            ch_idx = rel_tx / 24;
            font_col = (rel_tx % 24) / 3;
            font_row = rel_ty / 3;
            text_color = 12'hFF4;
            case (ch_idx)
                4'd0: font_char = 7'h50; // P
                4'd1: font_char = 7'h41; // A
                4'd2: font_char = 7'h55; // U
                4'd3: font_char = 7'h53; // S
                4'd4: font_char = 7'h45; // E
                4'd5: font_char = 7'h44; // D
                default: font_char = 7'h20;
            endcase
        end
        // E) GAME OVER Title: "GAME OVER" (9 chars @ 3x = 216px, X=212..427, Y=156..179)
        else if ((state == ST_GAMEOVER) &&
                 (pix_x >= 10'd212) && (pix_x < 10'd428) &&
                 (pix_y >= 10'd156) && (pix_y < 10'd180)) begin
            in_text_box = 1'b1;
            rel_tx = pix_x - 10'd212;
            rel_ty = pix_y - 10'd156;
            ch_idx = rel_tx / 24;
            font_col = (rel_tx % 24) / 3;
            font_row = rel_ty / 3;
            text_color = 12'hF43;
            case (ch_idx)
                4'd0: font_char = 7'h47; // G
                4'd1: font_char = 7'h41; // A
                4'd2: font_char = 7'h4D; // M
                4'd3: font_char = 7'h45; // E
                4'd4: font_char = 7'h20; // ' '
                4'd5: font_char = 7'h4F; // O
                4'd6: font_char = 7'h56; // V
                4'd7: font_char = 7'h45; // E
                4'd8: font_char = 7'h52; // R
                default: font_char = 7'h20;
            endcase
        end
        // F) GAME OVER Score: "SCORE:XXX" (9 chars @ 2x = 144px, X=248..391, Y=200..215)
        else if ((state == ST_GAMEOVER) &&
                 (pix_x >= 10'd248) && (pix_x < 10'd392) &&
                 (pix_y >= 10'd200) && (pix_y < 10'd216)) begin
            in_text_box = 1'b1;
            rel_tx = pix_x - 10'd248;
            rel_ty = pix_y - 10'd200;
            ch_idx = rel_tx[7:4];
            font_col = rel_tx[3:1];
            font_row = rel_ty[3:1];
            text_color = 12'hFFF;
            case (ch_idx)
                4'd0: font_char = 7'h53; // S
                4'd1: font_char = 7'h43; // C
                4'd2: font_char = 7'h4F; // O
                4'd3: font_char = 7'h52; // R
                4'd4: font_char = 7'h45; // E
                4'd5: font_char = 7'h3A; // :
                4'd6: font_char = {3'b011, score_bcd[11:8]};
                4'd7: font_char = {3'b011, score_bcd[7:4]};
                4'd8: font_char = {3'b011, score_bcd[3:0]};
                default: font_char = 7'h20;
            endcase
        end
        // G) GAME OVER Best: "BEST :XXX" (9 chars @ 2x = 144px, X=248..391, Y=226..241)
        else if ((state == ST_GAMEOVER) &&
                 (pix_x >= 10'd248) && (pix_x < 10'd392) &&
                 (pix_y >= 10'd226) && (pix_y < 10'd242)) begin
            in_text_box = 1'b1;
            rel_tx = pix_x - 10'd248;
            rel_ty = pix_y - 10'd226;
            ch_idx = rel_tx[7:4];
            font_col = rel_tx[3:1];
            font_row = rel_ty[3:1];
            text_color = 12'hFD2;
            case (ch_idx)
                4'd0: font_char = 7'h42; // B
                4'd1: font_char = 7'h45; // E
                4'd2: font_char = 7'h53; // S
                4'd3: font_char = 7'h54; // T
                4'd4: font_char = 7'h20; // ' '
                4'd5: font_char = 7'h3A; // :
                4'd6: font_char = {3'b011, high_score_bcd[11:8]};
                4'd7: font_char = {3'b011, high_score_bcd[7:4]};
                4'd8: font_char = {3'b011, high_score_bcd[3:0]};
                default: font_char = 7'h20;
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // 3. Pipes, Clouds, Ground, Sky, Voice Meter & Banner Boxes
    // -------------------------------------------------------------------------
    reg        in_pipe;
    reg [11:0] pipe_color;

    wire signed [10:0] p_x  [0:2];
    wire        [9:0]  p_gy [0:2];
    assign p_x[0]  = pipe0_x;     assign p_x[1]  = pipe1_x;     assign p_x[2]  = pipe2_x;
    assign p_gy[0] = pipe0_gap_y; assign p_gy[1] = pipe1_gap_y; assign p_gy[2] = pipe2_gap_y;

    integer p;
    reg signed [10:0] dx_body, dx_cap;
    reg        [9:0]  gap_bot;
    reg               in_top_cap, in_bot_cap, in_top_shaft, in_bot_shaft;

    always @(*) begin
        in_pipe      = 1'b0;
        pipe_color   = 12'h4C4;
        dx_body      = 11'sd0;
        dx_cap       = 11'sd0;
        gap_bot      = 10'd0;
        in_top_cap   = 1'b0;
        in_bot_cap   = 1'b0;
        in_top_shaft = 1'b0;
        in_bot_shaft = 1'b0;

        if (state != ST_IDLE) begin
            for (p = 0; p < 3; p = p + 1) begin
                gap_bot      = p_gy[p] + pipe_gap_h;
                dx_body      = sx - p_x[p];
                dx_cap       = sx - (p_x[p] - 11'sd4);
                in_top_cap   = (sx >= (p_x[p] - 11'sd4)) && (sx < (p_x[p] + PIPE_W + 4)) &&
                               (pix_y >= (p_gy[p] - CAP_H)) && (pix_y < p_gy[p]);
                in_bot_cap   = (sx >= (p_x[p] - 11'sd4)) && (sx < (p_x[p] + PIPE_W + 4)) &&
                               (pix_y >= gap_bot) && (pix_y < (gap_bot + CAP_H));
                in_top_shaft = (sx >= p_x[p]) && (sx < (p_x[p] + PIPE_W)) &&
                               (pix_y < (p_gy[p] - CAP_H));
                in_bot_shaft = (sx >= p_x[p]) && (sx < (p_x[p] + PIPE_W)) &&
                               (pix_y >= (gap_bot + CAP_H)) && (pix_y < GROUND_Y);

                if (in_top_cap || in_bot_cap) begin
                    in_pipe = 1'b1;
                    if ((dx_cap < 11'sd2) || (dx_cap >= (PIPE_W + 6)) ||
                        (in_top_cap && (pix_y == (p_gy[p] - CAP_H) || pix_y == (p_gy[p] - 1))) ||
                        (in_bot_cap && (pix_y == gap_bot || pix_y == (gap_bot + CAP_H - 1)))) begin
                        pipe_color = 12'h141; // Dark green pixel border
                    end else if (dx_cap >= 11'sd6 && dx_cap < 11'sd14) begin
                        pipe_color = 12'h8F6; // Highlight
                    end else if (dx_cap >= 11'sd48) begin
                        pipe_color = 12'h282; // Shadow
                    end else begin
                        pipe_color = 12'h4C4; // Main pipe green
                    end
                end else if (in_top_shaft || in_bot_shaft) begin
                    in_pipe = 1'b1;
                    if ((dx_body < 11'sd2) || (dx_body >= (PIPE_W - 2))) begin
                        pipe_color = 12'h141;
                    end else if (dx_body >= 11'sd6 && dx_body < 11'sd13) begin
                        pipe_color = 12'h8F6;
                    end else if (dx_body >= 11'sd42) begin
                        pipe_color = 12'h282;
                    end else begin
                        pipe_color = 12'h4C4;
                    end
                end
            end
        end
    end

    // Scrolling Pixel Clouds
    wire [10:0] cx_sum = {1'b0, pix_x} + {1'b0, cloud_scroll};
    wire [9:0]  cx     = (cx_sum >= 11'd640) ? (cx_sum - 11'd640) : cx_sum[9:0];
    wire in_cloud =
        // Cloud 1
        ((cx >= 10'd60  && cx < 10'd124 && pix_y >= 10'd72  && pix_y < 10'd96) ||
         (cx >= 10'd76  && cx < 10'd112 && pix_y >= 10'd56  && pix_y < 10'd72)) ||
        // Cloud 2
        ((cx >= 10'd280 && cx < 10'd360 && pix_y >= 10'd108 && pix_y < 10'd134) ||
         (cx >= 10'd298 && cx < 10'd342 && pix_y >= 10'd90  && pix_y < 10'd108)) ||
        // Cloud 3
        ((cx >= 10'd480 && cx < 10'd552 && pix_y >= 10'd64  && pix_y < 10'd88) ||
         (cx >= 10'd496 && cx < 10'd536 && pix_y >= 10'd48  && pix_y < 10'd64));

    // Ground (Y >= 440)
    wire [9:0] gx = pix_x + ground_scroll;
    wire [11:0] ground_color =
        (pix_y < 10'd442) ? 12'h251 :
        (pix_y < 10'd456) ? ((((gx + pix_y) & 10'd16) != 10'd0) ? 12'h6D3 : 12'h4A2) :
                            ((((gx[3] ^ pix_y[3])) == 1'b1) ? 12'hC95 : 12'hB84);

    // Sky gradient
    wire [11:0] sky_color =
        (pix_y < 10'd160) ? 12'h4BC :
        (pix_y < 10'd320) ? 12'h6DE : 12'h9EF;

    // On-screen Voice Meter Bar (X=16..145, Y=16..29)
    wire in_mic_box    = (pix_x >= 10'd16) && (pix_x < 10'd146) &&
                         (pix_y >= 10'd16) && (pix_y < 10'd30);
    wire in_mic_border = in_mic_box &&
                         (pix_x == 10'd16 || pix_x == 10'd145 ||
                          pix_y == 10'd16 || pix_y == 10'd29);
    wire [7:0] mic_rel_x   = pix_x - 10'd17; // 0..127
    wire       on_thresh   = (mic_rel_x == threshold[7:1]);
    wire       in_mic_fill = (mic_rel_x < volume[7:1]);

    // Overlay panel boxes for IDLE / PAUSE / GAMEOVER
    wire in_panel =
        ((state == ST_IDLE)     && pix_x >= 10'd144 && pix_x < 10'd496 && pix_y >= 10'd80  && pix_y < 10'd168) ||
        ((state == ST_PAUSE)    && pix_x >= 10'd220 && pix_x < 10'd420 && pix_y >= 10'd192 && pix_y < 10'd248) ||
        ((state == ST_GAMEOVER) && pix_x >= 10'd184 && pix_x < 10'd456 && pix_y >= 10'd140 && pix_y < 10'd258);

    wire in_panel_border =
        ((state == ST_IDLE)     && in_panel && (pix_x < 10'd148 || pix_x >= 10'd492 || pix_y < 10'd84  || pix_y >= 10'd164)) ||
        ((state == ST_PAUSE)    && in_panel && (pix_x < 10'd224 || pix_x >= 10'd416 || pix_y < 10'd196 || pix_y >= 10'd244)) ||
        ((state == ST_GAMEOVER) && in_panel && (pix_x < 10'd188 || pix_x >= 10'd452 || pix_y < 10'd144 || pix_y >= 10'd254));

    // Combine non-ROM background layer first
    reg [11:0] bg_rgb;
    always @(*) begin
        if (pix_y >= GROUND_Y) begin
            bg_rgb = ground_color;
        end else if (in_pipe) begin
            bg_rgb = pipe_color;
        end else if (in_cloud) begin
            bg_rgb = (pix_y > 10'd84 && pix_y < 10'd96) ? 12'hDEF : 12'hFFF;
        end else begin
            bg_rgb = sky_color;
        end

        if (in_panel_border) begin
            bg_rgb = 12'hFD2;
        end else if (in_panel) begin
            bg_rgb = 12'h124;
        end

        if (in_mic_border) begin
            bg_rgb = 12'hFFF;
        end else if (in_mic_box) begin
            if (on_thresh) begin
                bg_rgb = 12'hF22; // Threshold marker line
            end else if (in_mic_fill) begin
                bg_rgb = voice_active ? 12'h3E5 : 12'hFB3;
            end else begin
                bg_rgb = 12'h123;
            end
        end
    end

    // Final pixel mux synchronized to pix_en (after synchronous ROM read settles)
    always @(posedge clk) begin
        if (rst) begin
            vga_r <= 4'h0;
            vga_g <= 4'h0;
            vga_b <= 4'h0;
        end else if (pix_en) begin
            if (!video_on) begin
                {vga_r, vga_g, vga_b} <= 12'h000;
            end else if (in_text_box && font_pix_on) begin
                {vga_r, vga_g, vga_b} <= text_color;
            end else if (bird_pixel_on) begin
                {vga_r, vga_g, vga_b} <= bird_rgb;
            end else begin
                {vga_r, vga_g, vga_b} <= bg_rgb;
            end
        end
    end

endmodule
