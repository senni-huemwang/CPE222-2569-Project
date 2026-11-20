`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: vga_renderer
// Description: 800x600 @ 60Hz RGB444 Pixel Art renderer:
//              - Feeding-Frenzy style Top HUD Bar (Y=0..73)
//              - Space background in Flappy Attack + Sky Bonustime
//              - Round bordered bullets, 64x64 BirdPlayer, 144x144 Boss_TA2 + blink
//              - Outlined Boss HP countdown (150->0), FLAPZY letters, PHASE X banner
//////////////////////////////////////////////////////////////////////////////////
module vga_renderer (
    input  wire        clk,
    input  wire        rst,
    input  wire        pix_en,
    input  wire        video_on,
    input  wire [10:0] pix_x,
    input  wire [9:0]  pix_y,
    // Shared State
    input  wire [2:0]  state,
    input  wire        active_mode,
    input  wire [2:0]  sens_sw,
    input  wire [9:0]  bird_x,
    input  wire [9:0]  bird_y,
    input  wire        bird_pose,
    input  wire [9:0]  ground_scroll,
    input  wire [9:0]  cloud_scroll,
    input  wire [15:0] score_bcd,
    input  wire [15:0] high_score_bcd,
    input  wire [15:0] boss_hp_bcd,
    // Voice HUD
    input  wire [7:0]  volume,
    input  wire [7:0]  threshold,
    input  wire        voice_active,
    // Classic Pipes
    input  wire signed [11:0] pipe0_x, pipe1_x, pipe2_x,
    input  wire [9:0]  pipe0_gap_y, pipe1_gap_y, pipe2_gap_y,
    input  wire [9:0]  pipe_gap_h,
    // Attack Mode State
    input  wire [2:0]  player_hp,
    input  wire        player_invuln,
    input  wire        shield_on,
    input  wire        triple_on,
    input  wire        rapid_on,
    input  wire [8:0]  buff_timer_bar,
    input  wire        floor_warn,
    input  wire        floor_hazard,
    input  wire [7:0]  en_act,
    input  wire [95:0] en_x_flat,
    input  wire [79:0] en_y_flat,
    input  wire [15:0] pb_act,
    input  wire [159:0] pb_x_flat,
    input  wire [159:0] pb_y_flat,
    input  wire [11:0] eb_act,
    input  wire [119:0] eb_x_flat,
    input  wire [119:0] eb_y_flat,
    input  wire        boss_active,
    input  wire [9:0]  boss_x,
    input  wire [9:0]  boss_y,
    input  wire [9:0]  boss_hp,
    input  wire [9:0]  boss_max_hp,
    input  wire        boss_blink,
    input  wire        boss_victory,
    input  wire        boss_knocked_down,
    input  wire        show_phase_banner,
    input  wire        show_boss_warning,
    input  wire [3:0]  current_phase,
    input  wire        buff_act,
    input  wire [9:0]  buff_x,
    input  wire [9:0]  buff_y,
    input  wire [1:0]  buff_type,
    // FLAPZY & BONUSTIME
    input  wire [5:0]  flapzy_mask,
    input  wire        letter_act,
    input  wire [9:0]  letter_x,
    input  wire [9:0]  letter_y,
    input  wire [2:0]  letter_idx,
    input  wire        bonus_intro,
    input  wire        bonus_active,
    input  wire [3:0]  frenzy_dim_cnt,
    input  wire [9:0]  star_act,
    input  wire [99:0] star_x_flat,
    input  wire [99:0] star_y_flat,
    // VGA RGB444 outputs
    output reg  [3:0]  vga_r,
    output reg  [3:0]  vga_g,
    output reg  [3:0]  vga_b
);
    localparam [2:0] ST_HOME     = 3'd0,
                     ST_MODE     = 3'd1,
                     ST_TUTORIAL = 3'd2,
                     ST_PLAY     = 3'd3,
                     ST_PAUSE    = 3'd4,
                     ST_GAMEOVER = 3'd5;

    localparam integer TOP_Y    = 74;
    localparam integer GROUND_Y = 552;
    localparam integer PIPE_W   = 64;
    localparam integer CAP_H    = 24;

    wire signed [11:0] sx = $signed({1'b0, pix_x});

    // Unpack Arrays
    wire signed [11:0] en_x [0:7];
    wire        [9:0]  en_y [0:7];
    wire        [9:0]  pb_x [0:15];
    wire        [9:0]  pb_y [0:15];
    wire        [9:0]  eb_x [0:11];
    wire        [9:0]  eb_y [0:11];
    wire        [9:0]  star_x [0:9];
    wire        [9:0]  star_y [0:9];

    genvar g;
    generate
        for (g = 0; g < 8; g = g + 1) begin : gen_en_unpack
            assign en_x[g] = en_x_flat[g*12 +: 12];
            assign en_y[g] = en_y_flat[g*10 +: 10];
        end
        for (g = 0; g < 16; g = g + 1) begin : gen_pb_unpack
            assign pb_x[g] = pb_x_flat[g*10 +: 10];
            assign pb_y[g] = pb_y_flat[g*10 +: 10];
        end
        for (g = 0; g < 12; g = g + 1) begin : gen_eb_unpack
            assign eb_x[g] = eb_x_flat[g*10 +: 10];
            assign eb_y[g] = eb_y_flat[g*10 +: 10];
        end
        for (g = 0; g < 10; g = g + 1) begin : gen_s_unpack
            assign star_x[g] = star_x_flat[g*10 +: 10];
            assign star_y[g] = star_y_flat[g*10 +: 10];
        end
    endgenerate

    // -------------------------------------------------------------------------
    // 1. Sprite ROMs
    // -------------------------------------------------------------------------
    // HomePage (160x120 scaled 5x to 800x600)
    wire [7:0] home_rx = pix_x / 5;
    wire [6:0] home_ry = pix_y / 5;
    wire [11:0] home_rgb;
    home_rom u_home_rom (
        .clk     (clk),
        .x       ((state == ST_HOME) ? home_rx : 8'd0),
        .y       ((state == ST_HOME) ? home_ry : 7'd0),
        .rgb_out (home_rgb)
    );

    // BirdPlayer (64x64 native)
    wire show_bird   = (state == ST_PLAY || state == ST_PAUSE || state == ST_GAMEOVER) && !player_invuln;
    wire in_bird_box = show_bird && (pix_x >= bird_x) && (pix_x < bird_x + 11'd64) &&
                                    (pix_y >= bird_y) && (pix_y < bird_y + 10'd64);
    wire [5:0] bird_dx = pix_x - bird_x;
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

    // Circular Shield Aura around 64x64 BirdPlayer (r = 34..38 px)
    wire signed [11:0] s_dx    = $signed({1'b0, pix_x}) - $signed({2'b00, bird_x}) - 12'sd32;
    wire signed [11:0] s_dy    = $signed({1'b0, pix_y}) - $signed({2'b00, bird_y}) - 12'sd32;
    wire        [23:0] s_dist2 = (s_dx * s_dx) + (s_dy * s_dy);
    wire in_shield_ring = active_mode && shield_on && (state == ST_PLAY || state == ST_PAUSE) &&
                          (s_dist2 >= 24'd1156) && (s_dist2 <= 24'd1444);

    // Glowing Bird Aura during FRENZY intro & sky bonustime (double glowing halo around 64x64 bird)
    wire in_bonus_aura_inner = active_mode && (bonus_intro || bonus_active) && (state == ST_PLAY || state == ST_PAUSE) &&
                               (s_dist2 >= 24'd1156) && (s_dist2 <= 24'd1444); // r=34..38
    wire in_bonus_aura_outer = active_mode && (bonus_intro || bonus_active) && (state == ST_PLAY || state == ST_PAUSE) &&
                               (s_dist2 > 24'd1444) && (s_dist2 <= 24'd2025); // r=39..45
    wire in_bonus_aura       = in_bonus_aura_inner || in_bonus_aura_outer;
    wire [11:0] bonus_aura_col = in_bonus_aura_inner ? 12'hFD2 :
                                 (cloud_scroll[1:0] == 2'd0) ? 12'h5FF :
                                 (cloud_scroll[1:0] == 2'd1) ? 12'hFF6 :
                                 (cloud_scroll[1:0] == 2'd2) ? 12'hF6D : 12'h5F8;

    // Chibi Boss_TA2 (144x144 = 48x48 x3) + hit blink + 90-degree knockdown rotation
    wire in_boss_box = active_mode && boss_active && !boss_blink && !bonus_active && !bonus_intro &&
                       (state == ST_PLAY || state == ST_PAUSE) &&
                       (pix_x >= boss_x) && (pix_x < (boss_x + 11'd144)) &&
                       (pix_y >= boss_y) && (pix_y < (boss_y + 10'd144));
    wire [7:0] boss_rel_x = pix_x - boss_x;
    wire [7:0] boss_rel_y = pix_y - boss_y;
    wire [5:0] boss_rom_x = boss_rel_x / 3;
    wire [5:0] boss_rom_y = boss_rel_y / 3;
    wire [5:0] boss_eff_x = boss_knocked_down ? boss_rom_y : boss_rom_x;
    wire [5:0] boss_eff_y = boss_knocked_down ? (6'd47 - boss_rom_x) : boss_rom_y;
    wire [11:0] boss_rgb_raw;

    boss_rom u_boss_rom (
        .clk     (clk),
        .x       (in_boss_box ? boss_eff_x : 6'd0),
        .y       (in_boss_box ? boss_eff_y : 6'd0),
        .rgb_out (boss_rgb_raw)
    );

    // Phase 1: Student Uniform | Phase 2: Unbuttoned Shop Jacket (#435D6E) + White Tee
    // Phase 3: Red Graduation Gown | Phase 4+: Business Suit + Black Sunglasses
    wire in_sunglasses = (current_phase >= 4'd4) && (boss_eff_y >= 6'd16 && boss_eff_y <= 6'd20) &&
                         (((boss_eff_y == 6'd17) && (boss_eff_x >= 6'd12 && boss_eff_x <= 6'd35)) ||
                          ((boss_eff_y >= 6'd17 && boss_eff_y <= 6'd20) &&
                           ((boss_eff_x >= 6'd15 && boss_eff_x <= 6'd22) || (boss_eff_x >= 6'd26 && boss_eff_x <= 6'd33))));
    wire in_glass_shine = in_sunglasses && ((boss_eff_y == 6'd18) && (boss_eff_x == 6'd17 || boss_eff_x == 6'd28));

    reg [11:0] boss_outfit_rgb;
    always @(*) begin
        boss_outfit_rgb = 12'hF0F;
        if (boss_eff_y >= 6'd32) begin
            if (current_phase == 4'd1) begin
                // Phase 1: Student Uniform
                if (boss_eff_y < 6'd40) begin
                    if (boss_eff_x >= 6'd14 && boss_eff_x <= 6'd33) begin
                        if (boss_eff_x == 6'd14 || boss_eff_x == 6'd33) boss_outfit_rgb = 12'h222;
                        else if (boss_eff_y == 6'd39) begin
                            if (boss_eff_x >= 6'd23 && boss_eff_x <= 6'd24) boss_outfit_rgb = 12'hCCC;
                            else                                            boss_outfit_rgb = 12'h111;
                        end else if (boss_eff_x >= 6'd22 && boss_eff_x <= 6'd25) begin
                            if (boss_eff_y == 6'd35 && (boss_eff_x == 6'd23 || boss_eff_x == 6'd24))
                                boss_outfit_rgb = 12'hF61;
                            else
                                boss_outfit_rgb = 12'h113;
                        end else if ((boss_eff_y >= 6'd37) && (boss_eff_x <= 6'd15 || boss_eff_x >= 6'd32))
                            boss_outfit_rgb = 12'hEC9;
                        else
                            boss_outfit_rgb = 12'hFFF;
                    end
                end else if (boss_eff_y < 6'd45) begin
                    if (boss_eff_x >= 6'd16 && boss_eff_x <= 6'd31) begin
                        if ((boss_eff_y >= 6'd42) && (boss_eff_x >= 6'd23 && boss_eff_x <= 6'd24))
                            boss_outfit_rgb = 12'hF0F;
                        else
                            boss_outfit_rgb = 12'h112;
                    end
                end else if (boss_eff_y < 6'd47) begin
                    if ((boss_eff_x >= 6'd15 && boss_eff_x <= 6'd21) || (boss_eff_x >= 6'd26 && boss_eff_x <= 6'd32))
                        boss_outfit_rgb = 12'h111;
                end
            end else if (current_phase == 4'd2) begin
                // Phase 2: Engineering Workshop Shirt (#435D6E = 12'h467) unbuttoned over white tee
                if (boss_eff_y < 6'd40) begin
                    if (boss_eff_x >= 6'd13 && boss_eff_x <= 6'd34) begin
                        if (boss_eff_x == 6'd13 || boss_eff_x == 6'd34)
                            boss_outfit_rgb = 12'h234; // Dark slate outline
                        else if ((boss_eff_y >= 6'd37) && (boss_eff_x <= 6'd14 || boss_eff_x >= 6'd33))
                            boss_outfit_rgb = 12'hEC9; // Hands under short sleeves
                        else if (boss_eff_x >= 6'd21 && boss_eff_x <= 6'd26)
                            boss_outfit_rgb = (boss_eff_y == 6'd32) ? 12'hDDE : 12'hFFF; // White inner t-shirt
                        else if ((boss_eff_x == 6'd20 || boss_eff_x == 6'd27) ||
                                 (boss_eff_y == 6'd37 && ((boss_eff_x >= 6'd15 && boss_eff_x <= 6'd18) ||
                                                          (boss_eff_x >= 6'd29 && boss_eff_x <= 6'd32))))
                            boss_outfit_rgb = 12'h9AB; // Silver lapel/pocket trim
                        else if ((boss_eff_y == 6'd34 || boss_eff_y == 6'd35) && (boss_eff_x >= 6'd16 && boss_eff_x <= 6'd18))
                            boss_outfit_rgb = 12'hF61; // KMITL Gear/Crest emblem on chest
                        else
                            boss_outfit_rgb = 12'h467; // Workshop blue-slate #435D6E
                    end
                end else if (boss_eff_y < 6'd45) begin
                    if (boss_eff_x >= 6'd16 && boss_eff_x <= 6'd31) begin
                        if ((boss_eff_y >= 6'd42) && (boss_eff_x >= 6'd23 && boss_eff_x <= 6'd24))
                            boss_outfit_rgb = 12'hF0F;
                        else
                            boss_outfit_rgb = 12'h112;
                    end
                end else if (boss_eff_y < 6'd47) begin
                    if ((boss_eff_x >= 6'd15 && boss_eff_x <= 6'd21) || (boss_eff_x >= 6'd26 && boss_eff_x <= 6'd32))
                        boss_outfit_rgb = 12'h111;
                end
            end else if (current_phase == 4'd3) begin
                // Phase 3: Red Graduation Gown with Gold-Black-Gold Trim
                if (boss_eff_y < 6'd45) begin
                    if (boss_eff_x >= 6'd13 && boss_eff_x <= 6'd34) begin
                        if (boss_eff_x == 6'd13 || boss_eff_x == 6'd34) begin
                            boss_outfit_rgb = 12'h600;
                        end else if (boss_eff_x >= 6'd22 && boss_eff_x <= 6'd25) begin
                            if (boss_eff_y <= 6'd38 && (boss_eff_y == 6'd33 || boss_eff_y == 6'd35 || boss_eff_y == 6'd37) &&
                                (boss_eff_x == 6'd23 || boss_eff_x == 6'd24))
                                boss_outfit_rgb = 12'hFD2;
                            else if (boss_eff_y >= 6'd41 && (boss_eff_x == 6'd23 || boss_eff_x == 6'd24))
                                boss_outfit_rgb = 12'hF0F;
                            else
                                boss_outfit_rgb = 12'hFFF;
                        end else if ((boss_eff_x == 6'd19 || boss_eff_x == 6'd21 || boss_eff_x == 6'd26 || boss_eff_x == 6'd28) ||
                                     ((boss_eff_y == 6'd42 || boss_eff_y == 6'd44) && boss_eff_x >= 6'd14 && boss_eff_x <= 6'd33) ||
                                     ((boss_eff_y == 6'd37 || boss_eff_y == 6'd39) && (boss_eff_x <= 6'd15 || boss_eff_x >= 6'd32))) begin
                            boss_outfit_rgb = 12'hFC2;
                        end else if ((boss_eff_x == 6'd20 || boss_eff_x == 6'd27) ||
                                     (boss_eff_y == 6'd43 && boss_eff_x >= 6'd14 && boss_eff_x <= 6'd33) ||
                                     (boss_eff_y == 6'd38 && (boss_eff_x <= 6'd15 || boss_eff_x >= 6'd32))) begin
                            boss_outfit_rgb = 12'h111;
                        end else begin
                            boss_outfit_rgb = 12'hE11;
                        end
                    end
                end else if (boss_eff_y == 6'd45) begin
                    if ((boss_eff_x >= 6'd17 && boss_eff_x <= 6'd21) || (boss_eff_x >= 6'd26 && boss_eff_x <= 6'd30))
                        boss_outfit_rgb = 12'hEEF;
                end else if (boss_eff_y >= 6'd46) begin
                    if ((boss_eff_x >= 6'd16 && boss_eff_x <= 6'd21) || (boss_eff_x >= 6'd26 && boss_eff_x <= 6'd31))
                        boss_outfit_rgb = 12'h111;
                end
            end else begin
                // Phase 4+: Secret Agent Black Suit + Red Tie (+ Sunglasses on head!)
                if (boss_eff_y < 6'd40) begin
                    if (boss_eff_x >= 6'd13 && boss_eff_x <= 6'd34) begin
                        if (boss_eff_x == 6'd13 || boss_eff_x == 6'd34)
                            boss_outfit_rgb = 12'h000;
                        else if ((boss_eff_y >= 6'd38) && (boss_eff_x <= 6'd15 || boss_eff_x >= 6'd32))
                            boss_outfit_rgb = 12'hEC9; // Hands
                        else if (boss_eff_y <= 6'd36 && boss_eff_x >= 6'd21 && boss_eff_x <= 6'd26 &&
                                 ((boss_eff_y <= 6'd33) || (boss_eff_x >= 6'd22 && boss_eff_x <= 6'd25))) begin
                            if (boss_eff_x >= 6'd23 && boss_eff_x <= 6'd24 && boss_eff_y >= 6'd33)
                                boss_outfit_rgb = 12'hD11; // Crisp red power tie
                            else
                                boss_outfit_rgb = 12'hFFF; // White dress shirt V
                        end else if (boss_eff_y == 6'd35 && (boss_eff_x == 6'd16 || boss_eff_x == 6'd17))
                            boss_outfit_rgb = 12'hFFF; // Pocket square
                        else if (boss_eff_x == 6'd20 || boss_eff_x == 6'd27)
                            boss_outfit_rgb = 12'h445; // Suit lapel highlight
                        else
                            boss_outfit_rgb = 12'h112; // Sleek black suit jacket
                    end
                end else if (boss_eff_y < 6'd45) begin
                    if (boss_eff_x >= 6'd16 && boss_eff_x <= 6'd31) begin
                        if ((boss_eff_y >= 6'd42) && (boss_eff_x >= 6'd23 && boss_eff_x <= 6'd24))
                            boss_outfit_rgb = 12'hF0F;
                        else
                            boss_outfit_rgb = 12'h112; // Suit trousers
                    end
                end else if (boss_eff_y < 6'd47) begin
                    if ((boss_eff_x >= 6'd15 && boss_eff_x <= 6'd21) || (boss_eff_x >= 6'd26 && boss_eff_x <= 6'd32))
                        boss_outfit_rgb = 12'h111; // Shoes
                end
            end
        end
    end
    wire [11:0] boss_head_col = in_sunglasses ? (in_glass_shine ? 12'hFFF : 12'h000) : boss_rgb_raw;
    wire [11:0] boss_rgb      = (boss_eff_y >= 6'd32) ? boss_outfit_rgb : boss_head_col;
    wire        boss_pixel_on = in_boss_box && (boss_rgb != 12'hF0F);

    // ModeSelect Cards (800x600 centered: Left X=160..255, Right X=544..639, Y=120..215)
    wire in_ping_box = (state == ST_MODE) && (pix_x >= 11'd160 && pix_x < 11'd256 && pix_y >= 10'd120 && pix_y < 10'd216);
    wire in_peem_box = (state == ST_MODE) && (pix_x >= 11'd544 && pix_x < 11'd640 && pix_y >= 10'd120 && pix_y < 10'd216);
    wire [6:0] card_dx = in_ping_box ? (pix_x - 11'd160) : (pix_x - 11'd544);
    wire [6:0] card_dy = pix_y - 10'd120;
    wire [11:0] card_rgb_raw;

    card_rom u_card_rom (
        .clk     (clk),
        .sel     (in_peem_box),
        .x       ((in_ping_box || in_peem_box) ? card_dx[6:1] : 6'd0),
        .y       ((in_ping_box || in_peem_box) ? card_dy[6:1] : 6'd0),
        .rgb_out (card_rgb_raw)
    );
    wire [5:0] card_gray_sum = {2'b00, card_rgb_raw[11:8]} + {2'b00, card_rgb_raw[7:4]} + {2'b00, card_rgb_raw[3:0]};
    wire [3:0] card_gray_val = card_gray_sum[5:2];
    wire       card_is_color = (in_ping_box && !active_mode) || (in_peem_box && active_mode);
    wire [11:0] card_rgb     = card_is_color ? card_rgb_raw : {3{card_gray_val}};
    wire        card_pixel_on = (in_ping_box || in_peem_box) && (card_rgb_raw != 12'hF0F);

    // -------------------------------------------------------------------------
    // 2. Font ROM & Text Layout (800x600)
    // -------------------------------------------------------------------------
    reg        in_text_box, text_outline_en;
    reg [6:0]  font_char;
    reg [2:0]  font_row, font_col;
    reg [11:0] text_color;
    wire       font_pix_on, font_outline_on;

    font_rom u_font_rom (
        .clk        (clk),
        .char_code  (font_char),
        .row        (font_row),
        .col        (font_col),
        .pix_on     (font_pix_on),
        .outline_on (font_outline_on)
    );

    reg [5:0]  ch_idx;
    reg [10:0] rel_tx;
    reg [9:0]  rel_ty;
    wire [1:0] active_sens = sens_sw[2] ? 2'd2 : (sens_sw[1] ? 2'd1 : 2'd0);
    wire       in_hud_area = (state == ST_PLAY || state == ST_PAUSE) && (pix_y < TOP_Y);

    always @(*) begin
        in_text_box = 1'b0; text_outline_en = 1'b0; font_char = 7'h20; font_row = 3'd0; font_col = 3'd0;
        text_color = 12'hFFF; ch_idx = 6'd0; rel_tx = 11'd0; rel_ty = 10'd0;

        // ---- HOME SCREEN (800x600: HISCORE & START at bottom) ----
        if (state == ST_HOME) begin
            if (pix_x >= 11'd304 && pix_x < 11'd496 && pix_y >= 10'd444 && pix_y < 10'd460) begin
                in_text_box = 1'b1; rel_tx = pix_x - 11'd304; rel_ty = pix_y - 10'd444;
                ch_idx = rel_tx[7:4]; font_col = rel_tx[3:1]; font_row = rel_ty[3:1];
                text_color = 12'hFD2; // HISCORE:XXXX
                case (ch_idx)
                    6'd0:font_char=7'h48; 6'd1:font_char=7'h49; 6'd2:font_char=7'h53;
                    6'd3:font_char=7'h43; 6'd4:font_char=7'h4F; 6'd5:font_char=7'h52;
                    6'd6:font_char=7'h45; 6'd7:font_char=7'h3A;
                    6'd8:font_char={3'b011, high_score_bcd[15:12]};
                    6'd9:font_char={3'b011, high_score_bcd[11:8]};
                    6'd10:font_char={3'b011, high_score_bcd[7:4]};
                    6'd11:font_char={3'b011, high_score_bcd[3:0]};
                    default:font_char=7'h20;
                endcase
            end else if (pix_x >= 11'd360 && pix_x < 11'd440 && pix_y >= 10'd496 && pix_y < 10'd512) begin
                in_text_box = 1'b1; rel_tx = pix_x - 11'd360; rel_ty = pix_y - 10'd496;
                ch_idx = rel_tx[7:4]; font_col = rel_tx[3:1]; font_row = rel_ty[3:1];
                text_color = 12'hFFF; // START
                case (ch_idx)
                    6'd0:font_char=7'h53; 6'd1:font_char=7'h54; 6'd2:font_char=7'h41;
                    6'd3:font_char=7'h52; 6'd4:font_char=7'h54; default:font_char=7'h20;
                endcase
            end
        end

        // ---- MODE SELECT + SETTING (800x600) ----
        else if (state == ST_MODE) begin
            if (pix_x >= 11'd136 && pix_x < 11'd280 && pix_y >= 10'd84 && pix_y < 10'd100) begin
                in_text_box = 1'b1; rel_tx = pix_x - 11'd136; rel_ty = pix_y - 10'd84;
                ch_idx = rel_tx[7:4]; font_col = rel_tx[3:1]; font_row = rel_ty[3:1];
                text_color = (!active_mode) ? 12'hFD2 : 12'hBBB; // 1-CLASSIC
                case (ch_idx)
                    6'd0:font_char=7'h31; 6'd1:font_char=7'h2D; 6'd2:font_char=7'h43;
                    6'd3:font_char=7'h4C; 6'd4:font_char=7'h41; 6'd5:font_char=7'h53;
                    6'd6:font_char=7'h53; 6'd7:font_char=7'h49; 6'd8:font_char=7'h43;
                    default:font_char=7'h20;
                endcase
            end else if (pix_x >= 11'd528 && pix_x < 11'd656 && pix_y >= 10'd84 && pix_y < 10'd100) begin
                in_text_box = 1'b1; rel_tx = pix_x - 11'd528; rel_ty = pix_y - 10'd84;
                ch_idx = rel_tx[7:4]; font_col = rel_tx[3:1]; font_row = rel_ty[3:1];
                text_color = (active_mode) ? 12'hFD2 : 12'hBBB; // 2-ATTACK
                case (ch_idx)
                    6'd0:font_char=7'h32; 6'd1:font_char=7'h2D; 6'd2:font_char=7'h41;
                    6'd3:font_char=7'h54; 6'd4:font_char=7'h54; 6'd5:font_char=7'h41;
                    6'd6:font_char=7'h43; 6'd7:font_char=7'h4B; default:font_char=7'h20;
                endcase
            end else if (pix_x >= 11'd312 && pix_x < 11'd488 && pix_y >= 10'd292 && pix_y < 10'd308) begin
                in_text_box = 1'b1; rel_tx = pix_x - 11'd312; rel_ty = pix_y - 10'd292;
                ch_idx = rel_tx[7:4]; font_col = rel_tx[3:1]; font_row = rel_ty[3:1];
                text_color = 12'h6EF; // MIC SETTING
                case (ch_idx)
                    6'd0:font_char=7'h4D; 6'd1:font_char=7'h49; 6'd2:font_char=7'h43;
                    6'd3:font_char=7'h20; 6'd4:font_char=7'h53; 6'd5:font_char=7'h45;
                    6'd6:font_char=7'h54; 6'd7:font_char=7'h54; 6'd8:font_char=7'h49;
                    6'd9:font_char=7'h4E; 6'd10:font_char=7'h47; default:font_char=7'h20;
                endcase
            end else if (pix_x >= 11'd240 && pix_x < 11'd448 && pix_y >= 10'd326 && pix_y < 10'd342) begin
                in_text_box = 1'b1; rel_tx = pix_x - 11'd240; rel_ty = pix_y - 10'd326;
                ch_idx = rel_tx[7:4]; font_col = rel_tx[3:1]; font_row = rel_ty[3:1];
                text_color = (active_sens == 2'd0) ? 12'h3F5 : 12'h999; // SW1:Sensitive
                case (ch_idx)
                    6'd0:font_char=7'h53; 6'd1:font_char=7'h57; 6'd2:font_char=7'h31;
                    6'd3:font_char=7'h3A; 6'd4:font_char=7'h53; 6'd5:font_char=7'h65;
                    6'd6:font_char=7'h6E; 6'd7:font_char=7'h73; 6'd8:font_char=7'h69;
                    6'd9:font_char=7'h74; 6'd10:font_char=7'h69;6'd11:font_char=7'h76;
                    6'd12:font_char=7'h65; default:font_char=7'h20;
                endcase
            end else if (pix_x >= 11'd240 && pix_x < 11'd400 && pix_y >= 10'd354 && pix_y < 10'd370) begin
                in_text_box = 1'b1; rel_tx = pix_x - 11'd240; rel_ty = pix_y - 10'd354;
                ch_idx = rel_tx[7:4]; font_col = rel_tx[3:1]; font_row = rel_ty[3:1];
                text_color = (active_sens == 2'd1) ? 12'hFD2 : 12'h999; // SW2:Normal
                case (ch_idx)
                    6'd0:font_char=7'h53; 6'd1:font_char=7'h57; 6'd2:font_char=7'h32;
                    6'd3:font_char=7'h3A; 6'd4:font_char=7'h4E; 6'd5:font_char=7'h6F;
                    6'd6:font_char=7'h72; 6'd7:font_char=7'h6D; 6'd8:font_char=7'h61;
                    6'd9:font_char=7'h6C; default:font_char=7'h20;
                endcase
            end else if (pix_x >= 11'd240 && pix_x < 11'd384 && pix_y >= 10'd382 && pix_y < 10'd398) begin
                in_text_box = 1'b1; rel_tx = pix_x - 11'd240; rel_ty = pix_y - 10'd382;
                ch_idx = rel_tx[7:4]; font_col = rel_tx[3:1]; font_row = rel_ty[3:1];
                text_color = (active_sens == 2'd2) ? 12'hF43 : 12'h999; // SW3:Chaos
                case (ch_idx)
                    6'd0:font_char=7'h53; 6'd1:font_char=7'h57; 6'd2:font_char=7'h33;
                    6'd3:font_char=7'h3A; 6'd4:font_char=7'h43; 6'd5:font_char=7'h68;
                    6'd6:font_char=7'h61; 6'd7:font_char=7'h6F; 6'd8:font_char=7'h73;
                    default:font_char=7'h20;
                endcase
            end else if (pix_x >= 11'd304 && pix_x < 11'd496 && pix_y >= 10'd456 && pix_y < 10'd472) begin
                in_text_box = 1'b1; rel_tx = pix_x - 11'd304; rel_ty = pix_y - 10'd456;
                ch_idx = rel_tx[7:4]; font_col = rel_tx[3:1]; font_row = rel_ty[3:1];
                text_color = 12'hFFF; // Confirm BTNC
                case (ch_idx)
                    6'd0:font_char=7'h43; 6'd1:font_char=7'h6F; 6'd2:font_char=7'h6E;
                    6'd3:font_char=7'h66; 6'd4:font_char=7'h69; 6'd5:font_char=7'h72;
                    6'd6:font_char=7'h6D; 6'd7:font_char=7'h20; 6'd8:font_char=7'h42;
                    6'd9:font_char=7'h54; 6'd10:font_char=7'h4E;6'd11:font_char=7'h43;
                    default:font_char=7'h20;
                endcase
            end
        end

        // ---- TUTORIAL SCREEN (800x600 centered) ----
        else if (state == ST_TUTORIAL) begin
            if (!active_mode && pix_x >= 11'd232 && pix_x < 11'd568 && pix_y >= 10'd110 && pix_y < 10'd134) begin
                in_text_box = 1'b1; rel_tx = pix_x - 11'd232; rel_ty = pix_y - 10'd110;
                ch_idx = rel_tx / 24; font_col = (rel_tx % 24) / 3; font_row = rel_ty / 3;
                text_color = 12'h3F5; // Classic Flappy
                case (ch_idx)
                    6'd0:font_char=7'h43; 6'd1:font_char=7'h6C; 6'd2:font_char=7'h61;
                    6'd3:font_char=7'h73; 6'd4:font_char=7'h73; 6'd5:font_char=7'h69;
                    6'd6:font_char=7'h63; 6'd7:font_char=7'h20; 6'd8:font_char=7'h46;
                    6'd9:font_char=7'h6C; 6'd10:font_char=7'h61;6'd11:font_char=7'h70;
                    6'd12:font_char=7'h70;6'd13:font_char=7'h79;default:font_char=7'h20;
                endcase
            end else if (active_mode && pix_x >= 11'd244 && pix_x < 11'd556 && pix_y >= 10'd110 && pix_y < 10'd134) begin
                in_text_box = 1'b1; rel_tx = pix_x - 11'd244; rel_ty = pix_y - 10'd110;
                ch_idx = rel_tx / 24; font_col = (rel_tx % 24) / 3; font_row = rel_ty / 3;
                text_color = 12'hF43; // Flappy Attack
                case (ch_idx)
                    6'd0:font_char=7'h46; 6'd1:font_char=7'h6C; 6'd2:font_char=7'h61;
                    6'd3:font_char=7'h70; 6'd4:font_char=7'h70; 6'd5:font_char=7'h79;
                    6'd6:font_char=7'h20; 6'd7:font_char=7'h41; 6'd8:font_char=7'h74;
                    6'd9:font_char=7'h74; 6'd10:font_char=7'h61;6'd11:font_char=7'h63;
                    6'd12:font_char=7'h6B; default:font_char=7'h20;
                endcase
            end else if (pix_x >= 11'd144 && pix_x < 11'd656 && pix_y >= 10'd164 && pix_y < 10'd180) begin
                in_text_box = 1'b1; rel_tx = pix_x - 11'd144; rel_ty = pix_y - 10'd164;
                ch_idx = rel_tx[8:4]; font_col = rel_tx[3:1]; font_row = rel_ty[3:1];
                text_color = 12'hFFF;
                if (!active_mode) begin
                    case (ch_idx)
                        6'd0:font_char=7'h54;6'd1:font_char=7'h68;6'd2:font_char=7'h65;6'd3:font_char=7'h20;
                        6'd4:font_char=7'h62;6'd5:font_char=7'h69;6'd6:font_char=7'h72;6'd7:font_char=7'h64;
                        6'd8:font_char=7'h20;6'd9:font_char=7'h66;6'd10:font_char=7'h6C;6'd11:font_char=7'h61;
                        6'd12:font_char=7'h70;6'd13:font_char=7'h73;6'd14:font_char=7'h20;6'd15:font_char=7'h61;
                        6'd16:font_char=7'h6E;6'd17:font_char=7'h64;6'd18:font_char=7'h20;6'd19:font_char=7'h64;
                        6'd20:font_char=7'h6F;6'd21:font_char=7'h64;6'd22:font_char=7'h67;6'd23:font_char=7'h65;
                        6'd24:font_char=7'h73;6'd25:font_char=7'h20;6'd26:font_char=7'h70;6'd27:font_char=7'h69;
                        6'd28:font_char=7'h70;6'd29:font_char=7'h65;6'd30:font_char=7'h73;default:font_char=7'h20;
                    endcase
                end else begin
                    case (ch_idx)
                        6'd0:font_char=7'h54;6'd1:font_char=7'h68;6'd2:font_char=7'h65;6'd3:font_char=7'h20;
                        6'd4:font_char=7'h62;6'd5:font_char=7'h69;6'd6:font_char=7'h72;6'd7:font_char=7'h64;
                        6'd8:font_char=7'h20;6'd9:font_char=7'h77;6'd10:font_char=7'h69;6'd11:font_char=7'h6C;
                        6'd12:font_char=7'h6C;6'd13:font_char=7'h20;6'd14:font_char=7'h73;6'd15:font_char=7'h68;
                        6'd16:font_char=7'h6F;6'd17:font_char=7'h6F;6'd18:font_char=7'h74;6'd19:font_char=7'h20;
                        6'd20:font_char=7'h61;6'd21:font_char=7'h74;6'd22:font_char=7'h20;6'd23:font_char=7'h61;
                        6'd24:font_char=7'h6E;6'd25:font_char=7'h64;6'd26:font_char=7'h20;6'd27:font_char=7'h62;
                        6'd28:font_char=7'h6C;6'd29:font_char=7'h61;6'd30:font_char=7'h73;6'd31:font_char=7'h74;
                    endcase
                end
            end else if (pix_x >= 11'd144 && pix_x < 11'd656 && pix_y >= 10'd192 && pix_y < 10'd208) begin
                in_text_box = 1'b1; rel_tx = pix_x - 11'd144; rel_ty = pix_y - 10'd192;
                ch_idx = rel_tx[8:4]; font_col = rel_tx[3:1]; font_row = rel_ty[3:1];
                text_color = 12'hFFF;
                if (!active_mode) begin
                    case (ch_idx)
                        6'd0:font_char=7'h6F;6'd1:font_char=7'h6E;6'd2:font_char=7'h6C;6'd3:font_char=7'h79;
                        6'd4:font_char=7'h20;6'd5:font_char=7'h77;6'd6:font_char=7'h68;6'd7:font_char=7'h65;
                        6'd8:font_char=7'h6E;6'd9:font_char=7'h20;6'd10:font_char=7'h79;6'd11:font_char=7'h6F;
                        6'd12:font_char=7'h75;6'd13:font_char=7'h72;6'd14:font_char=7'h20;6'd15:font_char=7'h76;
                        6'd16:font_char=7'h6F;6'd17:font_char=7'h69;6'd18:font_char=7'h63;6'd19:font_char=7'h65;
                        6'd20:font_char=7'h20;6'd21:font_char=7'h76;6'd22:font_char=7'h6F;6'd23:font_char=7'h6C;
                        6'd24:font_char=7'h75;6'd25:font_char=7'h6D;6'd26:font_char=7'h65;default:font_char=7'h20;
                    endcase
                end else begin
                    case (ch_idx)
                        6'd0:font_char=7'h61;6'd1:font_char=7'h77;6'd2:font_char=7'h61;6'd3:font_char=7'h79;
                        6'd4:font_char=7'h20;6'd5:font_char=7'h4E;6'd6:font_char=7'h4F;6'd7:font_char=7'h54;
                        6'd8:font_char=7'h20;6'd9:font_char=7'h67;6'd10:font_char=7'h61;6'd11:font_char=7'h74;
                        6'd12:font_char=7'h65;6'd13:font_char=7'h73;6'd14:font_char=7'h2C;6'd15:font_char=7'h20;
                        6'd16:font_char=7'h77;6'd17:font_char=7'h68;6'd18:font_char=7'h69;6'd19:font_char=7'h6C;
                        6'd20:font_char=7'h65;6'd21:font_char=7'h20;6'd22:font_char=7'h74;6'd23:font_char=7'h68;
                        6'd24:font_char=7'h65;default:font_char=7'h20;
                    endcase
                end
            end else if (pix_x >= 11'd144 && pix_x < 11'd656 && pix_y >= 10'd220 && pix_y < 10'd236) begin
                in_text_box = 1'b1; rel_tx = pix_x - 11'd144; rel_ty = pix_y - 10'd220;
                ch_idx = rel_tx[8:4]; font_col = rel_tx[3:1]; font_row = rel_ty[3:1];
                text_color = 12'hFFF;
                if (!active_mode) begin
                    case (ch_idx)
                        6'd0:font_char=7'h65;6'd1:font_char=7'h78;6'd2:font_char=7'h63;6'd3:font_char=7'h65;
                        6'd4:font_char=7'h65;6'd5:font_char=7'h64;6'd6:font_char=7'h73;6'd7:font_char=7'h20;
                        6'd8:font_char=7'h61;6'd9:font_char=7'h20;6'd10:font_char=7'h74;6'd11:font_char=7'h68;
                        6'd12:font_char=7'h72;6'd13:font_char=7'h65;6'd14:font_char=7'h73;6'd15:font_char=7'h68;
                        6'd16:font_char=7'h6F;6'd17:font_char=7'h6C;6'd18:font_char=7'h64;6'd19:font_char=7'h2E;
                        default:font_char=7'h20;
                    endcase
                end else begin
                    case (ch_idx)
                        6'd0:font_char=7'h76;6'd1:font_char=7'h6F;6'd2:font_char=7'h69;6'd3:font_char=7'h63;
                        6'd4:font_char=7'h65;6'd5:font_char=7'h20;6'd6:font_char=7'h63;6'd7:font_char=7'h6F;
                        6'd8:font_char=7'h6E;6'd9:font_char=7'h74;6'd10:font_char=7'h72;6'd11:font_char=7'h6F;
                        6'd12:font_char=7'h6C;6'd13:font_char=7'h73;6'd14:font_char=7'h20;6'd15:font_char=7'h69;
                        6'd16:font_char=7'h74;6'd17:font_char=7'h73;6'd18:font_char=7'h20;6'd19:font_char=7'h66;
                        6'd20:font_char=7'h6C;6'd21:font_char=7'h69;6'd22:font_char=7'h67;6'd23:font_char=7'h68;
                        6'd24:font_char=7'h74;6'd25:font_char=7'h2E;default:font_char=7'h20;
                    endcase
                end
            end else if (pix_x >= 11'd192 && pix_x < 11'd608 && pix_y >= 10'd284 && pix_y < 10'd300) begin
                in_text_box = 1'b1; rel_tx = pix_x - 11'd192; rel_ty = pix_y - 10'd284;
                ch_idx = rel_tx[8:4]; font_col = rel_tx[3:1]; font_row = rel_ty[3:1];
                text_color = 12'h6EF; // VOICE/BTNU:FLY  BTNR:SHOOT
                case (ch_idx)
                    6'd0:font_char=7'h56;6'd1:font_char=7'h4F;6'd2:font_char=7'h49;6'd3:font_char=7'h43;
                    6'd4:font_char=7'h45;6'd5:font_char=7'h2F;6'd6:font_char=7'h42;6'd7:font_char=7'h54;
                    6'd8:font_char=7'h4E;6'd9:font_char=7'h55;6'd10:font_char=7'h3A;6'd11:font_char=7'h46;
                    6'd12:font_char=7'h4C;6'd13:font_char=7'h59;6'd14:font_char=7'h20;6'd15:font_char=7'h20;
                    6'd16:font_char=7'h42;6'd17:font_char=7'h54;6'd18:font_char=7'h4E;6'd19:font_char=7'h52;
                    6'd20:font_char=7'h3A;6'd21:font_char=7'h53;6'd22:font_char=7'h48;6'd23:font_char=7'h4F;
                    6'd24:font_char=7'h4F;6'd25:font_char=7'h54;default:font_char=7'h20;
                endcase
            end else if (pix_x >= 11'd240 && pix_x < 11'd560 && pix_y >= 10'd316 && pix_y < 10'd332) begin
                in_text_box = 1'b1; rel_tx = pix_x - 11'd240; rel_ty = pix_y - 10'd316;
                ch_idx = rel_tx[8:4]; font_col = rel_tx[3:1]; font_row = rel_ty[3:1];
                text_color = 12'hFD2; // SW15:PAUSE  TILT:BONUS
                case (ch_idx)
                    6'd0:font_char=7'h53;6'd1:font_char=7'h57;6'd2:font_char=7'h31;6'd3:font_char=7'h35;
                    6'd4:font_char=7'h3A;6'd5:font_char=7'h50;6'd6:font_char=7'h41;6'd7:font_char=7'h55;
                    6'd8:font_char=7'h53;6'd9:font_char=7'h45;6'd10:font_char=7'h20;6'd11:font_char=7'h20;
                    6'd12:font_char=7'h54;6'd13:font_char=7'h49;6'd14:font_char=7'h4C;6'd15:font_char=7'h54;
                    6'd16:font_char=7'h3A;6'd17:font_char=7'h42;6'd18:font_char=7'h4F;6'd19:font_char=7'h4E;
                    6'd20:font_char=7'h55;6'd21:font_char=7'h53;default:font_char=7'h20;
                endcase
            end else if (pix_x >= 11'd304 && pix_x < 11'd496 && pix_y >= 10'd456 && pix_y < 10'd472) begin
                in_text_box = 1'b1; rel_tx = pix_x - 11'd304; rel_ty = pix_y - 10'd456;
                ch_idx = rel_tx[7:4]; font_col = rel_tx[3:1]; font_row = rel_ty[3:1];
                text_color = 12'hFFF; // Confirm BTNC
                case (ch_idx)
                    6'd0:font_char=7'h43;6'd1:font_char=7'h6F;6'd2:font_char=7'h6E;
                    6'd3:font_char=7'h66;6'd4:font_char=7'h69;6'd5:font_char=7'h72;
                    6'd6:font_char=7'h6D;6'd7:font_char=7'h20;6'd8:font_char=7'h42;
                    6'd9:font_char=7'h54;6'd10:font_char=7'h4E;6'd11:font_char=7'h43;
                    default:font_char=7'h20;
                endcase
            end
        end

        // ---- FEEDING-FRENZY TOP HUD BAR & IN-GAME TEXT (800x600) ----
        else if (state == ST_PLAY || state == ST_PAUSE) begin
            // 1. "MIC" label at bottom-left of HUD (X=12..60, Y=44..60)
            if (pix_x >= 11'd12 && pix_x < 11'd60 && pix_y >= 10'd44 && pix_y < 10'd60) begin
                in_text_box = 1'b1; rel_tx = pix_x - 11'd12; rel_ty = pix_y - 10'd44;
                ch_idx = rel_tx[5:4]; font_col = rel_tx[3:1]; font_row = rel_ty[3:1];
                text_color = 12'hFD2;
                case (ch_idx)
                    6'd0:font_char=7'h4D; 6'd1:font_char=7'h49; 6'd2:font_char=7'h43; default:font_char=7'h20;
                endcase
            end
            // 2. "FLAPZY" Progress Letters at Top-Center of HUD (X=300..444, Y=12..36 @ 3x)
            else if (active_mode && pix_x >= 11'd300 && pix_x < 11'd444 && pix_y >= 10'd12 && pix_y < 10'd36) begin
                in_text_box = 1'b1; rel_tx = pix_x - 11'd300; rel_ty = pix_y - 10'd12;
                ch_idx = rel_tx / 24; font_col = (rel_tx % 24) / 3; font_row = rel_ty / 3;
                text_color = flapzy_mask[ch_idx[2:0]] ? 12'h3F5 : 12'h456;
                case (ch_idx)
                    6'd0:font_char=7'h46; 6'd1:font_char=7'h4C; 6'd2:font_char=7'h41;
                    6'd3:font_char=7'h50; 6'd4:font_char=7'h5A; 6'd5:font_char=7'h59;
                    default:font_char=7'h20;
                endcase
            end
            // 3. "SCORE" + 4-digit Score in dark recessed HUD box (X=476..636, Y=14..30)
            else if (pix_x >= 11'd476 && pix_x < 11'd636 && pix_y >= 10'd14 && pix_y < 10'd30) begin
                in_text_box = 1'b1; rel_tx = pix_x - 11'd476; rel_ty = pix_y - 10'd14;
                ch_idx = rel_tx[7:4]; font_col = rel_tx[3:1]; font_row = rel_ty[3:1];
                text_color = (ch_idx < 6'd6) ? 12'hFD2 : 12'hFFF;
                case (ch_idx)
                    6'd0:font_char=7'h53; 6'd1:font_char=7'h43; 6'd2:font_char=7'h4F;
                    6'd3:font_char=7'h52; 6'd4:font_char=7'h45; 6'd5:font_char=7'h3A;
                    6'd6:font_char={3'b011, score_bcd[15:12]};
                    6'd7:font_char={3'b011, score_bcd[11:8]};
                    6'd8:font_char={3'b011, score_bcd[7:4]};
                    6'd9:font_char={3'b011, score_bcd[3:0]};
                    default:font_char=7'h20;
                endcase
            end
            // 4. Phase Badge "PH-X" at Top-Right (X=716..780, Y=14..30)
            else if (active_mode && pix_x >= 11'd716 && pix_x < 11'd780 && pix_y >= 10'd14 && pix_y < 10'd30) begin
                in_text_box = 1'b1; rel_tx = pix_x - 11'd716; rel_ty = pix_y - 10'd14;
                ch_idx = rel_tx[6:4]; font_col = rel_tx[3:1]; font_row = rel_ty[3:1];
                text_color = 12'hFFF;
                case (ch_idx)
                    6'd0:font_char=7'h50; 6'd1:font_char=7'h48; 6'd2:font_char=7'h2D;
                    6'd3:font_char=(current_phase >= 4'd10) ? 7'h39 : {3'b011, current_phase};
                    default:font_char=7'h20;
                endcase
            end
            // 5. "BUFF" label at bottom-right of HUD (X=476..540, Y=44..60)
            else if (active_mode && pix_x >= 11'd476 && pix_x < 11'd540 && pix_y >= 10'd44 && pix_y < 10'd60) begin
                in_text_box = 1'b1; rel_tx = pix_x - 11'd476; rel_ty = pix_y - 10'd44;
                ch_idx = rel_tx[5:4]; font_col = rel_tx[3:1]; font_row = rel_ty[3:1];
                text_color = 12'hFD2;
                case (ch_idx)
                    6'd0:font_char=7'h42; 6'd1:font_char=7'h55; 6'd2:font_char=7'h46; 6'd3:font_char=7'h46;
                    default:font_char=7'h20;
                endcase
            end
            // 5b. Active Buff Name inside Buff Timer Bar (X=598..694, Y=48..56 @ 1x)
            else if (active_mode && pix_x >= 11'd598 && pix_x < 11'd694 && pix_y >= 10'd48 && pix_y < 10'd56) begin
                in_text_box     = 1'b1;
                text_outline_en = (triple_on || rapid_on || shield_on);
                rel_tx          = pix_x - 11'd598;
                rel_ty          = pix_y - 10'd48;
                ch_idx          = rel_tx[6:3];
                font_col        = rel_tx[2:0];
                font_row        = rel_ty[2:0];
                text_color      = (triple_on || rapid_on || shield_on) ? 12'hFFF : 12'h789;
                if (triple_on && rapid_on) begin
                    case (ch_idx)
                        6'd0:font_char=7'h54; 6'd1:font_char=7'h52; 6'd2:font_char=7'h49; 6'd3:font_char=7'h50;
                        6'd4:font_char=7'h4C; 6'd5:font_char=7'h45; 6'd6:font_char=7'h2B; 6'd7:font_char=7'h52;
                        6'd8:font_char=7'h41; 6'd9:font_char=7'h50; 6'd10:font_char=7'h49; 6'd11:font_char=7'h44;
                        default:font_char=7'h20;
                    endcase // "TRIPLE+RAPID"
                end else if (triple_on) begin
                    case (ch_idx)
                        6'd0:font_char=7'h54; 6'd1:font_char=7'h52; 6'd2:font_char=7'h49; 6'd3:font_char=7'h50;
                        6'd4:font_char=7'h4C; 6'd5:font_char=7'h45; 6'd6:font_char=7'h20; 6'd7:font_char=7'h53;
                        6'd8:font_char=7'h48; 6'd9:font_char=7'h4F; 6'd10:font_char=7'h54; default:font_char=7'h20;
                    endcase // "TRIPLE SHOT "
                end else if (rapid_on) begin
                    case (ch_idx)
                        6'd0:font_char=7'h52; 6'd1:font_char=7'h41; 6'd2:font_char=7'h50; 6'd3:font_char=7'h49;
                        6'd4:font_char=7'h44; 6'd5:font_char=7'h20; 6'd6:font_char=7'h46; 6'd7:font_char=7'h49;
                        6'd8:font_char=7'h52; 6'd9:font_char=7'h45; default:font_char=7'h20;
                    endcase // "RAPID FIRE  "
                end else if (shield_on) begin
                    case (ch_idx)
                        6'd2:font_char=7'h53; 6'd3:font_char=7'h48; 6'd4:font_char=7'h49; 6'd5:font_char=7'h45;
                        6'd6:font_char=7'h4C; 6'd7:font_char=7'h44; 6'd8:font_char=7'h20; 6'd9:font_char=7'h4F;
                        6'd10:font_char=7'h4E; default:font_char=7'h20;
                    endcase // "  SHIELD ON "
                end else begin
                    case (ch_idx)
                        6'd4:font_char=7'h4E; 6'd5:font_char=7'h4F; 6'd6:font_char=7'h4E; 6'd7:font_char=7'h45;
                        default:font_char=7'h20;
                    endcase // "    NONE    "
                end
            end
            // 6. Outlined Boss HP Number (30*Phase -> 0) below Boss HP Bar (X=368..432, Y=104..120)
            else if (active_mode && boss_active && !boss_victory && !bonus_active && !bonus_intro &&
                     pix_x >= 11'd368 && pix_x < 11'd432 && pix_y >= 10'd104 && pix_y < 10'd120) begin
                in_text_box = 1'b1; rel_tx = pix_x - 11'd368; rel_ty = pix_y - 10'd104;
                ch_idx = rel_tx[5:4]; font_col = rel_tx[3:1]; font_row = rel_ty[3:1];
                text_color = 12'hFFF;
                case (ch_idx)
                    6'd0:font_char={3'b011, boss_hp_bcd[15:12]};
                    6'd1:font_char={3'b011, boss_hp_bcd[11:8]};
                    6'd2:font_char={3'b011, boss_hp_bcd[7:4]};
                    6'd3:font_char={3'b011, boss_hp_bcd[3:0]};
                    default:font_char=7'h20;
                endcase
            end
            // 7. Falling FLAPZY Letter inside Sky Capsule
            else if (active_mode && letter_act && !bonus_active &&
                     pix_x >= (letter_x + 10'd4) && pix_x < (letter_x + 10'd20) &&
                     pix_y >= (letter_y + 10'd4) && pix_y < (letter_y + 10'd20)) begin
                in_text_box = 1'b1; rel_tx = pix_x - (letter_x + 10'd4); rel_ty = pix_y - (letter_y + 10'd4);
                font_col = rel_tx[3:1]; font_row = rel_ty[3:1];
                text_color = 12'h111;
                case (letter_idx)
                    3'd0:font_char=7'h46; 3'd1:font_char=7'h4C; 3'd2:font_char=7'h41;
                    3'd3:font_char=7'h50; 3'd4:font_char=7'h5A; 3'd5:font_char=7'h59;
                    default:font_char=7'h46;
                endcase
            end
            // 8a. "FRENZY TIME!" Centered Intro Banner (4 seconds before Sky Bonus)
            else if (active_mode && bonus_intro && (state == ST_PLAY) &&
                     pix_x >= 11'd208 && pix_x < 11'd592 && pix_y >= 10'd264 && pix_y < 10'd296) begin
                in_text_box = 1'b1; text_outline_en = 1'b1;
                rel_tx = pix_x - 11'd208; rel_ty = pix_y - 10'd264;
                ch_idx = rel_tx / 32; font_col = (rel_tx % 32) / 4; font_row = rel_ty / 4;
                case ((ch_idx + cloud_scroll[2:0]) % 6)
                    6'd0: text_color = 12'hF33;
                    6'd1: text_color = 12'hF92;
                    6'd2: text_color = 12'hFF3;
                    6'd3: text_color = 12'h3F5;
                    6'd4: text_color = 12'h3DF;
                    default: text_color = 12'hF5D;
                endcase
                case (ch_idx)
                    6'd0:font_char=7'h46; 6'd1:font_char=7'h52; 6'd2:font_char=7'h45;
                    6'd3:font_char=7'h4E; 6'd4:font_char=7'h5A; 6'd5:font_char=7'h59;
                    6'd6:font_char=7'h20; 6'd7:font_char=7'h54; 6'd8:font_char=7'h49;
                    6'd9:font_char=7'h4D; 6'd10:font_char=7'h45; 6'd11:font_char=7'h21;
                    default:font_char=7'h20;
                endcase
            end
            // 8. "FRENZY TIME" Rainbow Wave Banner (+20px lower, dark border, extinguishes letter by letter)
            else if (active_mode && bonus_active &&
                     pix_x >= 11'd268 && pix_x < 11'd532 && pix_y >= 10'd100 && pix_y < 10'd148) begin : blk_flapzy_wave
                reg [3:0] w_phase;
                reg [9:0] w_y0;
                rel_tx = pix_x - 11'd268;
                ch_idx = rel_tx / 24;
                w_phase = ch_idx[2:0] + cloud_scroll[2:0];
                case (w_phase[2:0])
                    3'd0: w_y0 = 10'd112;
                    3'd1: w_y0 = 10'd106;
                    3'd2: w_y0 = 10'd102;
                    3'd3: w_y0 = 10'd106;
                    3'd4: w_y0 = 10'd112;
                    3'd5: w_y0 = 10'd118;
                    3'd6: w_y0 = 10'd122;
                    default: w_y0 = 10'd118;
                endcase
                if (pix_y >= w_y0 && pix_y < (w_y0 + 10'd24)) begin
                    in_text_box     = 1'b1;
                    text_outline_en = 1'b1;
                    rel_ty          = pix_y - w_y0;
                    font_col        = (rel_tx % 24) / 3;
                    font_row        = rel_ty / 3;
                    if (ch_idx[3:0] < frenzy_dim_cnt) begin
                        text_color = 12'h345; // Extinguished letter as time runs down
                    end else begin
                        case ((ch_idx + cloud_scroll[2:0]) % 6)
                            6'd0: text_color = 12'hF33; // Red
                            6'd1: text_color = 12'hF82; // Orange
                            6'd2: text_color = 12'hFF3; // Yellow
                            6'd3: text_color = 12'h3F5; // Green
                            6'd4: text_color = 12'h3DF; // Cyan
                            default: text_color = 12'hF5D; // Magenta
                        endcase
                    end
                    case (ch_idx)
                        6'd0:font_char=7'h46; 6'd1:font_char=7'h52; 6'd2:font_char=7'h45;
                        6'd3:font_char=7'h4E; 6'd4:font_char=7'h5A; 6'd5:font_char=7'h59;
                        6'd6:font_char=7'h20; 6'd7:font_char=7'h54; 6'd8:font_char=7'h49;
                        6'd9:font_char=7'h4D; 6'd10:font_char=7'h45; default:font_char=7'h20;
                    endcase
                end
            end
            // 8b. "WARNING!" + Line 2 "BOSS is coming!" Flashing Red Banner (4s before Boss)
            else if (state == ST_PLAY && show_boss_warning && !cloud_scroll[2] &&
                     pix_x >= 11'd272 && pix_x < 11'd528 && pix_y >= 10'd252 && pix_y < 10'd284) begin
                in_text_box = 1'b1; text_outline_en = 1'b1;
                rel_tx = pix_x - 11'd272; rel_ty = pix_y - 10'd252;
                ch_idx = rel_tx / 32; font_col = (rel_tx % 32) / 4; font_row = rel_ty / 4;
                text_color = 12'hF22;
                case (ch_idx)
                    6'd0:font_char=7'h57; 6'd1:font_char=7'h41; 6'd2:font_char=7'h52;
                    6'd3:font_char=7'h4E; 6'd4:font_char=7'h49; 6'd5:font_char=7'h4E;
                    6'd6:font_char=7'h47; 6'd7:font_char=7'h21; default:font_char=7'h20;
                endcase
            end else if (state == ST_PLAY && show_boss_warning &&
                         pix_x >= 11'd280 && pix_x < 11'd520 && pix_y >= 10'd302 && pix_y < 10'd318) begin
                in_text_box = 1'b1; text_outline_en = 1'b1;
                rel_tx = pix_x - 11'd280; rel_ty = pix_y - 10'd302;
                ch_idx = rel_tx[7:4]; font_col = rel_tx[3:1]; font_row = rel_ty[3:1];
                text_color = 12'hFFF; // "BOSS is coming!"
                case (ch_idx)
                    6'd0:font_char=7'h42; 6'd1:font_char=7'h4F; 6'd2:font_char=7'h53; 6'd3:font_char=7'h53;
                    6'd4:font_char=7'h20; 6'd5:font_char=7'h69; 6'd6:font_char=7'h73; 6'd7:font_char=7'h20;
                    6'd8:font_char=7'h63; 6'd9:font_char=7'h6F; 6'd10:font_char=7'h6D; 6'd11:font_char=7'h69;
                    6'd12:font_char=7'h6E; 6'd13:font_char=7'h67; 6'd14:font_char=7'h21; default:font_char=7'h20;
                endcase
            end
            // 8c. "Finish! PHASE X" Victory Knockdown Banner (6.5s centered upper-middle)
            else if (state == ST_PLAY && boss_victory &&
                     pix_x >= 11'd220 && pix_x < 11'd580 && pix_y >= 10'd180 && pix_y < 10'd204) begin
                in_text_box = 1'b1; text_outline_en = 1'b1;
                rel_tx = pix_x - 11'd220; rel_ty = pix_y - 10'd180;
                ch_idx = rel_tx / 24; font_col = (rel_tx % 24) / 3; font_row = rel_ty / 3;
                text_color = 12'hFD2; // "Finish! PHASE X"
                case (ch_idx)
                    6'd0:font_char=7'h46; 6'd1:font_char=7'h69; 6'd2:font_char=7'h6E; 6'd3:font_char=7'h69;
                    6'd4:font_char=7'h73; 6'd5:font_char=7'h68; 6'd6:font_char=7'h21; 6'd7:font_char=7'h20;
                    6'd8:font_char=7'h50; 6'd9:font_char=7'h48; 6'd10:font_char=7'h41; 6'd11:font_char=7'h53;
                    6'd12:font_char=7'h45; 6'd13:font_char=7'h20;
                    6'd14:font_char=(current_phase >= 4'd10) ? 7'h39 : {3'b011, current_phase};
                    default:font_char=7'h20;
                endcase
            end
            // 9. "PHASE X" Banner for 3s after killing Boss
            else if (state == ST_PLAY && show_phase_banner &&
                     pix_x >= 11'd316 && pix_x < 11'd484 && pix_y >= 10'd268 && pix_y < 10'd292) begin
                in_text_box = 1'b1; rel_tx = pix_x - 11'd316; rel_ty = pix_y - 10'd268;
                ch_idx = rel_tx / 24; font_col = (rel_tx % 24) / 3; font_row = rel_ty / 3;
                text_color = 12'hFD2; // "PHASE X"
                case (ch_idx)
                    6'd0:font_char=7'h50; 6'd1:font_char=7'h48; 6'd2:font_char=7'h41;
                    6'd3:font_char=7'h53; 6'd4:font_char=7'h45; 6'd5:font_char=7'h20;
                    6'd6:font_char=(current_phase >= 4'd10) ? 7'h39 : {3'b011, current_phase};
                    default:font_char=7'h20;
                endcase
            end
            // 10. "PAUSED"
            else if (state == ST_PAUSE && pix_x >= 11'd328 && pix_x < 11'd472 && pix_y >= 10'd268 && pix_y < 10'd292) begin
                in_text_box = 1'b1; rel_tx = pix_x - 11'd328; rel_ty = pix_y - 10'd268;
                ch_idx = rel_tx / 24; font_col = (rel_tx % 24) / 3; font_row = rel_ty / 3;
                text_color = 12'hFF4;
                case (ch_idx)
                    6'd0:font_char=7'h50; 6'd1:font_char=7'h41; 6'd2:font_char=7'h55;
                    6'd3:font_char=7'h53; 6'd4:font_char=7'h45; 6'd5:font_char=7'h44;
                    default:font_char=7'h20;
                endcase
            end
        end

        // ---- GAME OVER (800x600 centered) ----
        else if (state == ST_GAMEOVER) begin
            if (pix_x >= 11'd292 && pix_x < 11'd508 && pix_y >= 10'd200 && pix_y < 10'd224) begin
                in_text_box = 1'b1; rel_tx = pix_x - 11'd292; rel_ty = pix_y - 10'd200;
                ch_idx = rel_tx / 24; font_col = (rel_tx % 24) / 3; font_row = rel_ty / 3;
                text_color = 12'hF43;
                case (ch_idx)
                    6'd0:font_char=7'h47;6'd1:font_char=7'h41;6'd2:font_char=7'h4D;
                    6'd3:font_char=7'h45;6'd4:font_char=7'h20;6'd5:font_char=7'h4F;
                    6'd6:font_char=7'h56;6'd7:font_char=7'h45;6'd8:font_char=7'h52;
                    default:font_char=7'h20;
                endcase
            end else if (pix_x >= 11'd320 && pix_x < 11'd480 && pix_y >= 10'd246 && pix_y < 10'd262) begin
                in_text_box = 1'b1; rel_tx = pix_x - 11'd320; rel_ty = pix_y - 10'd246;
                ch_idx = rel_tx[7:4]; font_col = rel_tx[3:1]; font_row = rel_ty[3:1];
                text_color = 12'hFFF;
                case (ch_idx)
                    6'd0:font_char=7'h53;6'd1:font_char=7'h43;6'd2:font_char=7'h4F;
                    6'd3:font_char=7'h52;6'd4:font_char=7'h45;6'd5:font_char=7'h3A;
                    6'd6:font_char={3'b011, score_bcd[15:12]};
                    6'd7:font_char={3'b011, score_bcd[11:8]};
                    6'd8:font_char={3'b011, score_bcd[7:4]};
                    6'd9:font_char={3'b011, score_bcd[3:0]};
                    default:font_char=7'h20;
                endcase
            end else if (pix_x >= 11'd320 && pix_x < 11'd480 && pix_y >= 10'd274 && pix_y < 10'd290) begin
                in_text_box = 1'b1; rel_tx = pix_x - 11'd320; rel_ty = pix_y - 10'd274;
                ch_idx = rel_tx[7:4]; font_col = rel_tx[3:1]; font_row = rel_ty[3:1];
                text_color = 12'hFD2;
                case (ch_idx)
                    6'd0:font_char=7'h42;6'd1:font_char=7'h45;6'd2:font_char=7'h53;
                    6'd3:font_char=7'h54;6'd4:font_char=7'h20;6'd5:font_char=7'h3A;
                    6'd6:font_char={3'b011, high_score_bcd[15:12]};
                    6'd7:font_char={3'b011, high_score_bcd[11:8]};
                    6'd8:font_char={3'b011, high_score_bcd[7:4]};
                    6'd9:font_char={3'b011, high_score_bcd[3:0]};
                    default:font_char=7'h20;
                endcase
            end else if (pix_x >= 11'd304 && pix_x < 11'd496 && pix_y >= 10'd456 && pix_y < 10'd472) begin
                in_text_box = 1'b1; rel_tx = pix_x - 11'd304; rel_ty = pix_y - 10'd456;
                ch_idx = rel_tx[7:4]; font_col = rel_tx[3:1]; font_row = rel_ty[3:1];
                text_color = 12'hFFF; // Confirm BTNC
                case (ch_idx)
                    6'd0:font_char=7'h43;6'd1:font_char=7'h6F;6'd2:font_char=7'h6E;
                    6'd3:font_char=7'h66;6'd4:font_char=7'h69;6'd5:font_char=7'h72;
                    6'd6:font_char=7'h6D;6'd7:font_char=7'h20;6'd8:font_char=7'h42;
                    6'd9:font_char=7'h54;6'd10:font_char=7'h4E;6'd11:font_char=7'h43;
                    default:font_char=7'h20;
                endcase
            end
        end
    end

    // -------------------------------------------------------------------------
    // 3. Pipes, Round Bullets, Rockets, Buffs, FLAPZY Letters, Stars & Top HUD
    // -------------------------------------------------------------------------
    reg        in_pipe;
    reg [11:0] pipe_color;
    wire signed [11:0] p_x [0:2];
    wire        [9:0]  p_gy [0:2];
    assign p_x[0] = pipe0_x; assign p_x[1] = pipe1_x; assign p_x[2] = pipe2_x;
    assign p_gy[0] = pipe0_gap_y; assign p_gy[1] = pipe1_gap_y; assign p_gy[2] = pipe2_gap_y;

    integer p;
    reg signed [11:0] dx_body, dx_cap;
    reg        [9:0]  gap_bot;
    reg               in_top_cap, in_bot_cap, in_top_shaft, in_bot_shaft;

    always @(*) begin
        in_pipe = 1'b0; pipe_color = 12'h4C4;
        dx_body = 12'sd0; dx_cap = 12'sd0; gap_bot = 10'd0;
        in_top_cap = 1'b0; in_bot_cap = 1'b0; in_top_shaft = 1'b0; in_bot_shaft = 1'b0;

        if (!active_mode && (state == ST_PLAY || state == ST_PAUSE || state == ST_GAMEOVER) && pix_y >= TOP_Y) begin
            for (p = 0; p < 3; p = p + 1) begin
                gap_bot      = p_gy[p] + pipe_gap_h;
                dx_body      = sx - p_x[p];
                dx_cap       = sx - (p_x[p] - 12'sd4);
                in_top_cap   = (sx >= (p_x[p] - 12'sd4)) && (sx < (p_x[p] + PIPE_W + 4)) && (pix_y >= (p_gy[p] - CAP_H)) && (pix_y < p_gy[p]);
                in_bot_cap   = (sx >= (p_x[p] - 12'sd4)) && (sx < (p_x[p] + PIPE_W + 4)) && (pix_y >= gap_bot) && (pix_y < (gap_bot + CAP_H));
                in_top_shaft = (sx >= p_x[p]) && (sx < (p_x[p] + PIPE_W)) && (pix_y < (p_gy[p] - CAP_H)) && (pix_y >= TOP_Y);
                in_bot_shaft = (sx >= p_x[p]) && (sx < (p_x[p] + PIPE_W)) && (pix_y >= (gap_bot + CAP_H)) && (pix_y < GROUND_Y);

                if (in_top_cap || in_bot_cap) begin
                    in_pipe = 1'b1;
                    if ((dx_cap < 12'sd3) || (dx_cap >= (PIPE_W + 5)) ||
                        (in_top_cap && (pix_y < (p_gy[p] - CAP_H + 3) || pix_y >= (p_gy[p] - 3))) ||
                        (in_bot_cap && (pix_y < (gap_bot + 3) || pix_y >= (gap_bot + CAP_H - 3))))
                        pipe_color = 12'h141;
                    else if (dx_cap >= 12'sd6 && dx_cap < 12'sd14) pipe_color = 12'h8F6;
                    else if (dx_cap >= 12'sd54)                    pipe_color = 12'h282;
                    else                                           pipe_color = 12'h4C4;
                end else if (in_top_shaft || in_bot_shaft) begin
                    in_pipe = 1'b1;
                    if ((dx_body < 12'sd3) || (dx_body >= (PIPE_W - 3))) pipe_color = 12'h141;
                    else if (dx_body >= 12'sd6 && dx_body < 12'sd13)     pipe_color = 12'h8F6;
                    else if (dx_body >= 12'sd48)                         pipe_color = 12'h282;
                    else                                                 pipe_color = 12'h4C4;
                end
            end
        end
    end

    // Attack Mode Objects (Round Bullets, Rockets, Stars, Letter, Boss HP Bar)
    reg        in_attack_obj;
    reg [11:0] attack_color;
    integer idx;
    reg signed [11:0] rx;
    reg        [9:0]  ry, bx_rel, by_rel;
    reg signed [5:0]  cdx, cdy;
    reg        [11:0] cdist2;

    always @(*) begin
        in_attack_obj = 1'b0; attack_color = 12'h000;
        rx = 12'sd0; ry = 10'd0; bx_rel = 10'd0; by_rel = 10'd0;
        cdx = 6'sd0; cdy = 6'sd0; cdist2 = 12'd0;

        if (active_mode && (state == ST_PLAY || state == ST_PAUSE) && pix_y >= TOP_Y) begin
            // 1. Round Player Bullets (16 slots, 14x14 circle with 2-3px neon border)
            for (idx = 0; idx < 16; idx = idx + 1) begin
                if (pb_act[idx] && (pix_x >= pb_x[idx]) && (pix_x < pb_x[idx] + 11'd14) &&
                                   (pix_y >= pb_y[idx]) && (pix_y < pb_y[idx] + 10'd14)) begin
                    cdx = $signed({1'b0, pix_x - pb_x[idx]}) - 6'sd6;
                    cdy = $signed({1'b0, pix_y - pb_y[idx]}) - 6'sd6;
                    cdist2 = (cdx * cdx) + (cdy * cdy);
                    if (cdist2 <= 12'd45) begin
                        in_attack_obj = 1'b1;
                        attack_color  = (cdist2 >= 12'd20) ? (triple_on ? 12'hF4A : 12'h09F) : 12'hFF8;
                    end
                end
            end

            // 2. Round Enemy Fireballs (16x16 circle with 3px dark red border)
            for (idx = 0; idx < 12; idx = idx + 1) begin
                if (eb_act[idx] && (pix_x >= eb_x[idx]) && (pix_x < eb_x[idx] + 11'd16) &&
                                   (pix_y >= eb_y[idx]) && (pix_y < eb_y[idx] + 10'd16)) begin
                    cdx = $signed({1'b0, pix_x - eb_x[idx]}) - 6'sd7;
                    cdy = $signed({1'b0, pix_y - eb_y[idx]}) - 6'sd7;
                    cdist2 = (cdx * cdx) + (cdy * cdy);
                    if (cdist2 <= 12'd56) begin
                        in_attack_obj = 1'b1;
                        if (cdist2 >= 12'd28)      attack_color = 12'h911; // 3px dark red border
                        else if (cdist2 >= 12'd10) attack_color = 12'hF51; // orange ring
                        else                       attack_color = 12'hFF6; // yellow center
                    end
                end
            end

            // 3. 8 NOT-gate Rockets (48x30)
            if (!bonus_active && !bonus_intro) begin
                for (idx = 0; idx < 8; idx = idx + 1) begin
                    if (en_act[idx] && (sx >= en_x[idx]) && (sx < (en_x[idx] + 12'sd48)) &&
                                       (pix_y >= en_y[idx]) && (pix_y < (en_y[idx] + 10'd30))) begin
                        rx = sx - en_x[idx]; ry = pix_y - en_y[idx];
                        if (rx < 12'sd9 && ry >= 10'd10 && ry < 10'd20) begin
                            in_attack_obj = 1'b1;
                            attack_color  = (rx < 12'sd3 || rx >= 12'sd6 || ry < 10'd13 || ry >= 10'd17) ? 12'hFFF : 12'hF22;
                        end else if (rx >= 12'sd9 && rx < 12'sd36) begin
                            if ((ry >= (10'd15 - ((rx - 12'sd9) >> 1))) &&
                                (ry <= (10'd15 + ((rx - 12'sd9) >> 1)))) begin
                                in_attack_obj = 1'b1;
                                if ((rx >= 12'sd33) ||
                                    (ry < (10'd18 - ((rx - 12'sd9) >> 1))) ||
                                    (ry > (10'd12 + ((rx - 12'sd9) >> 1))))
                                    attack_color = 12'hFFF;
                                else
                                    attack_color = 12'hD12;
                            end
                        end else if (rx >= 12'sd36 && ry >= 10'd8 && ry < 10'd22) begin
                            if ((ry >= (10'd8 + ((rx - 12'sd36) >> 1))) &&
                                (ry <= (10'd21 - ((rx - 12'sd36) >> 1)))) begin
                                in_attack_obj = 1'b1;
                                attack_color  = (rx < 12'sd41) ? 12'hFF3 : 12'hF61;
                            end
                        end
                    end
                end
            end

            // 4. Falling FLAPZY Letter Capsule (24x24 gold box)
            if (letter_act && !bonus_active && !bonus_intro &&
                (pix_x >= letter_x) && (pix_x < letter_x + 11'd24) &&
                (pix_y >= letter_y) && (pix_y < letter_y + 10'd24)) begin
                bx_rel = pix_x - letter_x; by_rel = pix_y - letter_y;
                in_attack_obj = 1'b1;
                attack_color  = (bx_rel < 10'd3 || bx_rel >= 10'd21 || by_rel < 10'd3 || by_rel >= 10'd21) ? 12'hFFF : 12'hFD2;
            end

            // 5. Bonustime Multi-Pattern Flowers (10 flowers, 24x24, 4 petals + gold center)
            if (bonus_active) begin : blk_bonus_flowers
                reg signed [5:0] fdx, fdy;
                reg [11:0] d_c, d_n, d_s, d_w, d_e;
                reg [11:0] petal_col;
                for (idx = 0; idx < 10; idx = idx + 1) begin
                    if (star_act[idx] && (pix_x >= star_x[idx]) && (pix_x < star_x[idx] + 11'd24) &&
                                         (pix_y >= star_y[idx]) && (pix_y < star_y[idx] + 10'd24)) begin
                        fdx = $signed({1'b0, pix_x - star_x[idx]}) - 6'sd11;
                        fdy = $signed({1'b0, pix_y - star_y[idx]}) - 6'sd11;
                        d_c = (fdx * fdx) + (fdy * fdy);
                        d_n = (fdx * fdx) + ((fdy + 6'sd6) * (fdy + 6'sd6));
                        d_s = (fdx * fdx) + ((fdy - 6'sd6) * (fdy - 6'sd6));
                        d_w = ((fdx + 6'sd6) * (fdx + 6'sd6)) + (fdy * fdy);
                        d_e = ((fdx - 6'sd6) * (fdx - 6'sd6)) + (fdy * fdy);
                        case (idx[1:0])
                            2'd0: petal_col = 12'hF5A; // Pink flower
                            2'd1: petal_col = 12'hF8C; // Blossom
                            2'd2: petal_col = 12'h5DF; // Sky blue flower
                            default: petal_col = 12'hFA4; // Peach flower
                        endcase
                        if (d_c <= 12'd16) begin
                            in_attack_obj = 1'b1;
                            attack_color  = (d_c <= 12'd4) ? 12'hFFF : 12'hFD2; // Yellow stamen
                        end else if (d_n <= 12'd25 || d_s <= 12'd25 || d_w <= 12'd25 || d_e <= 12'd25) begin
                            in_attack_obj = 1'b1;
                            if (d_n >= 12'd17 && d_s >= 12'd17 && d_w >= 12'd17 && d_e >= 12'd17)
                                attack_color = 12'hFFF; // Crisp white petal outline
                            else
                                attack_color = petal_col;
                        end
                    end
                end
            end

            // 6. Boss HP Bar (X=260..540, Y=86..98) + Outlined HP Number Box (X=360..440, Y=100..124)
            if (boss_active && !boss_victory && !bonus_active && !bonus_intro) begin
                if (pix_x >= 11'd260 && pix_x < 11'd540 && pix_y >= 10'd86 && pix_y < 10'd98) begin
                    in_attack_obj = 1'b1;
                    if (pix_x < 11'd262 || pix_x >= 11'd538 || pix_y < 10'd88 || pix_y >= 10'd96)
                        attack_color = 12'hFFF;
                    else if (((pix_x - 11'd262) * boss_max_hp) < (boss_hp * 18'd276))
                        attack_color = 12'hF22;
                    else
                        attack_color = 12'h211;
                end else if (pix_x >= 11'd362 && pix_x < 11'd438 && pix_y >= 10'd100 && pix_y < 10'd124) begin
                    in_attack_obj = 1'b1;
                    if (pix_x < 11'd365 || pix_x >= 11'd435 || pix_y < 10'd103 || pix_y >= 10'd121)
                        attack_color = 12'hFD2; // Crisp gold border around Boss HP digits
                    else
                        attack_color = 12'h112;
                end
            end
        end
    end

    // Buff Visuals (0=Triple Pink, 1=Rapid Yellow, 2=Shield Green -> Circle; 3=Heart -> Pixel Heart)
    wire in_buff_box = active_mode && buff_act && !bonus_active && (state == ST_PLAY || state == ST_PAUSE) &&
                       (pix_x >= buff_x) && (pix_x < (buff_x + 11'd32)) &&
                       (pix_y >= buff_y) && (pix_y < (buff_y + 10'd32));
    wire signed [5:0] b_dx = $signed({1'b0, pix_x - buff_x}) - 6'sd15;
    wire signed [5:0] b_dy = $signed({1'b0, pix_y - buff_y}) - 6'sd15;
    wire [11:0] b_dist2 = (b_dx * b_dx) + (b_dy * b_dy);
    wire [3:0]  bhx = (pix_x - buff_x - 11'd2) / 3;
    wire [3:0]  bhy = (pix_y - buff_y - 10'd4) / 3;
    wire in_buff_heart_area = in_buff_box && (buff_type == 2'd3) &&
                              (pix_x >= buff_x + 11'd2) && (pix_x < buff_x + 11'd29) &&
                              (pix_y >= buff_y + 10'd4) && (pix_y < buff_y + 10'd28);
    wire buff_heart_bdr = in_buff_heart_area &&
                          ((bhy == 0 && (bhx == 1 || bhx == 2 || bhx == 6 || bhx == 7)) ||
                           (bhy == 1 && (bhx == 0 || bhx == 3 || bhx == 5 || bhx == 8)) ||
                           (bhy == 2 && (bhx == 0 || bhx == 4 || bhx == 8)) ||
                           (bhy == 3 && (bhx == 0 || bhx == 8)) ||
                           (bhy == 4 && (bhx == 1 || bhx == 7)) ||
                           (bhy == 5 && (bhx == 2 || bhx == 6)) ||
                           (bhy == 6 && (bhx == 3 || bhx == 5)) ||
                           (bhy == 7 && (bhx == 4)));
    wire buff_heart_fill = in_buff_heart_area &&
                           ((bhy == 1 && (bhx == 1 || bhx == 2 || bhx == 6 || bhx == 7)) ||
                            (bhy == 2 && (bhx >= 1 && bhx <= 3 || bhx >= 5 && bhx <= 7)) ||
                            (bhy == 3 && (bhx >= 1 && bhx <= 7)) ||
                            (bhy == 4 && (bhx >= 2 && bhx <= 6)) ||
                            (bhy == 5 && (bhx >= 3 && bhx <= 5)) ||
                            (bhy == 6 && (bhx == 4)));
    wire in_buff_circle = in_buff_box &&
                          ((buff_type == 2'd3) ?
                           (buff_heart_bdr || buff_heart_fill || (b_dist2 >= 12'd150 && b_dist2 <= 12'd225)) :
                           (b_dist2 <= 12'd225));
    wire [11:0] buff_outer_col = (buff_type == 2'd0) ? 12'hF39 :
                                 (buff_type == 2'd1) ? 12'hFD0 :
                                 (buff_type == 2'd2) ? 12'h1D3 : 12'hF47;
    wire [11:0] buff_inner_col = (buff_type == 2'd0) ? 12'hF9D :
                                 (buff_type == 2'd1) ? 12'hFF8 :
                                 (buff_type == 2'd2) ? 12'h8F9 : 12'hF9B;
    wire [11:0] buff_circle_col = (buff_type == 2'd3) ?
                                  (buff_heart_bdr  ? 12'hFFF :
                                   buff_heart_fill ? ((bhy == 2 && bhx == 2) ? 12'hFFF : 12'hF12) :
                                                     buff_outer_col) :
                                  ((b_dist2 <= 12'd36)  ? 12'hFFF :
                                   (b_dist2 <= 12'd90)  ? buff_outer_col :
                                   (b_dist2 <= 12'd150) ? buff_inner_col : buff_outer_col);

    // Feeding-Frenzy Top HUD Bar Elements (Y = 0..73)
    reg        in_hud_elem;
    reg [11:0] hud_elem_col;
    reg [9:0]  hx_rel, hy_rel;

    always @(*) begin
        in_hud_elem = 1'b0; hud_elem_col = 12'h000;
        hx_rel = 10'd0; hy_rel = 10'd0;

        if (in_hud_area) begin
            // 1. 5 Pixel Hearts at Top-Left (X=14..158, Y=10..34, 27x24 each)
            if (active_mode) begin
                for (idx = 0; idx < 5; idx = idx + 1) begin
                    if ((pix_x >= (11'd14 + idx * 11'd30)) && (pix_x < (11'd41 + idx * 11'd30)) &&
                        (pix_y >= 10'd10) && (pix_y < 10'd34)) begin
                        hx_rel = (pix_x - (11'd14 + idx * 11'd30)) / 3;
                        hy_rel = (pix_y - 10'd10) / 3;
                        if ((hy_rel == 0 && (hx_rel == 1 || hx_rel == 2 || hx_rel == 6 || hx_rel == 7)) ||
                            (hy_rel == 1 && (hx_rel == 0 || hx_rel == 3 || hx_rel == 5 || hx_rel == 8)) ||
                            (hy_rel == 2 && (hx_rel == 0 || hx_rel == 4 || hx_rel == 8)) ||
                            (hy_rel == 3 && (hx_rel == 0 || hx_rel == 8)) ||
                            (hy_rel == 4 && (hx_rel == 1 || hx_rel == 7)) ||
                            (hy_rel == 5 && (hx_rel == 2 || hx_rel == 6)) ||
                            (hy_rel == 6 && (hx_rel == 3 || hx_rel == 5)) ||
                            (hy_rel == 7 && (hx_rel == 4))) begin
                            in_hud_elem  = 1'b1; hud_elem_col = 12'h111;
                        end else if ((hy_rel == 1 && (hx_rel == 1 || hx_rel == 2 || hx_rel == 6 || hx_rel == 7)) ||
                                     (hy_rel == 2 && (hx_rel >= 1 && hx_rel <= 3 || hx_rel >= 5 && hx_rel <= 7)) ||
                                     (hy_rel == 3 && (hx_rel >= 1 && hx_rel <= 7)) ||
                                     (hy_rel == 4 && (hx_rel >= 2 && hx_rel <= 6)) ||
                                     (hy_rel == 5 && (hx_rel >= 3 && hx_rel <= 5)) ||
                                     (hy_rel == 6 && (hx_rel == 4))) begin
                            in_hud_elem  = 1'b1;
                            hud_elem_col = (idx < player_hp && hy_rel == 2 && hx_rel == 2) ? 12'hFFF :
                                           (idx < player_hp) ? 12'hF23 : 12'h345;
                        end
                    end
                end
            end
            // 2. Dark Recessed Score Box (X=568..644, Y=10..34)
            if (pix_x >= 11'd568 && pix_x < 11'd644 && pix_y >= 10'd10 && pix_y < 10'd34) begin
                in_hud_elem  = 1'b1;
                hud_elem_col = (pix_x < 11'd570 || pix_x >= 11'd642 || pix_y < 10'd12 || pix_y >= 10'd32) ? 12'h8AB : 12'h112;
            end
            // 3. Phase Badge Box (X=710..786, Y=10..34)
            else if (active_mode && pix_x >= 11'd710 && pix_x < 11'd786 && pix_y >= 10'd10 && pix_y < 10'd34) begin
                in_hud_elem  = 1'b1;
                hud_elem_col = (pix_x < 11'd712 || pix_x >= 11'd784 || pix_y < 10'd12 || pix_y >= 10'd32) ? 12'hFD2 : 12'h124;
            end
            // 4. Buff Timer Bar (X=546..746, Y=44..60)
            else if (active_mode && pix_x >= 11'd546 && pix_x < 11'd746 && pix_y >= 10'd44 && pix_y < 10'd60) begin
                in_hud_elem = 1'b1;
                if (pix_x < 11'd548 || pix_x >= 11'd744 || pix_y < 10'd46 || pix_y >= 10'd58)
                    hud_elem_col = shield_on ? 12'h3F5 : 12'h111;
                else if (triple_on || rapid_on) begin
                    if ((pix_x - 11'd548) < (buff_timer_bar[8:1]))
                        hud_elem_col = triple_on ? 12'hF4A : 12'hFD2;
                    else
                        hud_elem_col = 12'h123;
                end else if (shield_on)
                    hud_elem_col = 12'h1A3;
                else
                    hud_elem_col = 12'h123;
            end
        end
    end

    // Spiky Grass Floor Hazard (Y = 532..552)
    wire [3:0] spike_x = pix_x[3:0];
    wire [4:0] spike_h = (spike_x < 4'd8) ? {1'b0, spike_x, 1'b0} : {1'b0, (4'd15 - spike_x), 1'b0};
    wire in_spikes = active_mode && floor_hazard && !bonus_active && (state == ST_PLAY || state == ST_PAUSE) &&
                     (pix_y >= (10'd550 - spike_h)) && (pix_y < GROUND_Y);

    // Double-Border CTA + Bordered Wings (800x600 centered)
    wire has_cta = (state == ST_HOME || state == ST_MODE || state == ST_TUTORIAL || state == ST_GAMEOVER);
    wire [9:0] cta_y0 = (state == ST_HOME) ? 10'd486 : 10'd446;
    wire [9:0] cta_y1 = cta_y0 + 10'd36;
    wire in_cta_box   = has_cta && (pix_x >= 11'd284 && pix_x < 11'd516 && pix_y >= cta_y0 && pix_y < cta_y1);
    wire in_cta_outer = in_cta_box && (pix_x < 11'd287 || pix_x >= 11'd513 || pix_y < (cta_y0 + 3) || pix_y >= (cta_y1 - 3));
    wire in_cta_inner = in_cta_box && !in_cta_outer &&
                        (pix_x >= 11'd289 && pix_x < 11'd511 && pix_y >= (cta_y0 + 5) && pix_y < (cta_y1 - 5)) &&
                        (pix_x < 11'd291 || pix_x >= 11'd509 || pix_y < (cta_y0 + 7) || pix_y >= (cta_y1 - 7));

    wire in_wing_l_raw = has_cta && (pix_x >= 11'd248 && pix_x < 11'd282 && pix_y >= (cta_y0 + 3) && pix_y < (cta_y1 - 3)) &&
                         ((pix_y < (cta_y0 + 12) && pix_x >= 11'd248) ||
                          (pix_y >= (cta_y0 + 12) && pix_y < (cta_y0 + 21) && pix_x >= 11'd258) ||
                          (pix_y >= (cta_y0 + 21) && pix_x >= 11'd268));
    wire in_wing_l_bdr = in_wing_l_raw &&
                         (pix_y < (cta_y0 + 5) || pix_y >= (cta_y1 - 5) || pix_x >= 11'd280 ||
                          (pix_y < (cta_y0 + 12) && pix_x < 11'd250) ||
                          (pix_y >= (cta_y0 + 12) && pix_y < (cta_y0 + 21) && pix_x < 11'd260) ||
                          (pix_y >= (cta_y0 + 21) && pix_x < 11'd270));

    wire in_wing_r_raw = has_cta && (pix_x >= 11'd518 && pix_x < 11'd552 && pix_y >= (cta_y0 + 3) && pix_y < (cta_y1 - 3)) &&
                         ((pix_y < (cta_y0 + 12) && pix_x < 11'd552) ||
                          (pix_y >= (cta_y0 + 12) && pix_y < (cta_y0 + 21) && pix_x < 11'd542) ||
                          (pix_y >= (cta_y0 + 21) && pix_x < 11'd532));
    wire in_wing_r_bdr = in_wing_r_raw &&
                         (pix_y < (cta_y0 + 5) || pix_y >= (cta_y1 - 5) || pix_x < 11'd520 ||
                          (pix_y < (cta_y0 + 12) && pix_x >= 11'd550) ||
                          (pix_y >= (cta_y0 + 12) && pix_y < (cta_y0 + 21) && pix_x >= 11'd540) ||
                          (pix_y >= (cta_y0 + 21) && pix_x >= 11'd530));

    // Pop-up Panels (800x600)
    wire in_popup =
        ((state == ST_HOME)     && pix_x >= 11'd292 && pix_x < 11'd508 && pix_y >= 10'd436 && pix_y < 10'd468) ||
        ((state == ST_TUTORIAL) && pix_x >= 11'd120 && pix_x < 11'd680 && pix_y >= 10'd90  && pix_y < 10'd360) ||
        ((state == ST_PLAY)     && show_phase_banner && pix_x >= 11'd292 && pix_x < 11'd508 && pix_y >= 10'd252 && pix_y < 10'd308) ||
        ((state == ST_PLAY)     && show_boss_warning && pix_x >= 11'd220 && pix_x < 11'd580 && pix_y >= 10'd240 && pix_y < 10'd334) ||
        ((state == ST_PLAY)     && boss_victory      && pix_x >= 11'd196 && pix_x < 11'd604 && pix_y >= 10'd166 && pix_y < 10'd218) ||
        ((state == ST_PLAY)     && bonus_intro       && pix_x >= 11'd192 && pix_x < 11'd608 && pix_y >= 10'd250 && pix_y < 10'd310) ||
        ((state == ST_PAUSE)    && pix_x >= 11'd296 && pix_x < 11'd504 && pix_y >= 10'd252 && pix_y < 10'd308) ||
        ((state == ST_GAMEOVER) && pix_x >= 11'd264 && pix_x < 11'd536 && pix_y >= 10'd184 && pix_y < 10'd310);

    wire in_warn_popup = (state == ST_PLAY) && show_boss_warning &&
                         pix_x >= 11'd220 && pix_x < 11'd580 && pix_y >= 10'd240 && pix_y < 10'd334;
    wire in_warn_border = in_warn_popup && (pix_x < 11'd224 || pix_x >= 11'd576 || pix_y < 10'd244 || pix_y >= 10'd330);

    wire in_popup_border =
        ((state == ST_HOME)     && in_popup && (pix_x < 11'd295 || pix_x >= 11'd505 || pix_y < 10'd439 || pix_y >= 10'd465)) ||
        ((state == ST_TUTORIAL) && in_popup && (pix_x < 11'd123 || pix_x >= 11'd677 || pix_y < 10'd93  || pix_y >= 10'd357)) ||
        ((state == ST_PLAY)     && show_phase_banner && in_popup && (pix_x < 11'd295 || pix_x >= 11'd505 || pix_y < 10'd255 || pix_y >= 10'd305)) ||
        ((state == ST_PLAY)     && boss_victory      && in_popup && (pix_x < 11'd200 || pix_x >= 11'd600 || pix_y < 10'd170 || pix_y >= 10'd214)) ||
        ((state == ST_PLAY)     && bonus_intro       && in_popup && (pix_x < 11'd196 || pix_x >= 11'd604 || pix_y < 10'd254 || pix_y >= 10'd306)) ||
        ((state == ST_PAUSE)    && in_popup && (pix_x < 11'd299 || pix_x >= 11'd501 || pix_y < 10'd255 || pix_y >= 10'd305)) ||
        ((state == ST_GAMEOVER) && in_popup && (pix_x < 11'd267 || pix_x >= 11'd533 || pix_y < 10'd187 || pix_y >= 10'd307));

    // ModeSelect Cards (800x600)
    wire in_card_left  = (state == ST_MODE) && (pix_x >= 11'd92  && pix_x < 11'd324 && pix_y >= 10'd68 && pix_y < 10'd236);
    wire in_card_right = (state == ST_MODE) && (pix_x >= 11'd476 && pix_x < 11'd708 && pix_y >= 10'd68 && pix_y < 10'd236);
    wire in_set_panel  = (state == ST_MODE) && (pix_x >= 11'd200 && pix_x < 11'd600 && pix_y >= 10'd276 && pix_y < 10'd414);
    wire [4:0] fire_wave = pix_x[4] ? (5'd15 - pix_x[3:0]) : pix_x[3:0];
    wire [9:0] fire_top_y = 10'd138 + {4'd0, fire_wave, 1'b0};
    wire [9:0] fire_mid_y = 10'd170 + {5'd0, fire_wave};
    wire [9:0] fire_hot_y = 10'd202 + {6'd0, fire_wave[3:1]};
    wire in_ember_spark = in_card_right && (pix_y >= 10'd114 && pix_y < 10'd140) &&
                          ((pix_x[3:0] == 4'd5 && pix_y[3:0] == 4'd3) || (pix_x[3:0] == 4'd12 && pix_y[3:0] == 4'd11));
    wire in_pipe_bg    = in_card_left  && ((pix_x >= 11'd108 && pix_x < 11'd142 && pix_y >= 10'd140) ||
                                           (pix_x >= 11'd274 && pix_x < 11'd308 && pix_y >= 10'd124));

    // Space Background (Attack Gameplay) & Sky Background (Classic / Bonustime)
    wire [10:0] sx_sum = pix_x + {1'b0, cloud_scroll};
    wire [10:0] cx     = (sx_sum >= 11'd800) ? (sx_sum - 11'd800) : sx_sum;
    wire in_star_dot   = (cx[5:0] == 6'd13 && pix_y[5:0] == 6'd27) ||
                         (cx[6:0] == 7'd71 && pix_y[4:0] == 5'd9)  ||
                         (cx[4:0] == 5'd3  && pix_y[6:0] == 7'd89);
    wire signed [11:0] pl_dx = $signed({1'b0, pix_x}) - 12'sd660;
    wire signed [11:0] pl_dy = $signed({1'b0, pix_y}) - 12'sd170;
    wire        [23:0] pl_d2 = (pl_dx * pl_dx) + (pl_dy * pl_dy);
    wire in_planet     = (pl_d2 <= 24'd1296); // r = 36 (Moon in Space / Sun Core in Sky Bonus)
    wire in_sun_halo   = (pl_d2 > 24'd1296) && (pl_d2 <= 24'd2116); // Sun soft warm corona
    wire [11:0] abs_pdx = pl_dx[11] ? (-pl_dx) : pl_dx;
    wire [11:0] abs_pdy = pl_dy[11] ? (-pl_dy) : pl_dy;
    wire in_sun_rays   = (pl_d2 > 24'd1296) && (pl_d2 <= 24'd3136) &&
                         ((abs_pdx <= 12'd2) || (abs_pdy <= 12'd2) || ((abs_pdx >= abs_pdy - 12'd2) && (abs_pdx <= abs_pdy + 12'd2)));

    wire in_cloud =
        ((cx >= 11'd80  && cx < 11'd150 && pix_y >= 10'd112 && pix_y < 10'd140) ||
         (cx >= 11'd96  && cx < 11'd134 && pix_y >= 10'd96  && pix_y < 10'd112)) ||
        ((cx >= 11'd360 && cx < 11'd440 && pix_y >= 10'd148 && pix_y < 10'd176) ||
         (cx >= 11'd378 && cx < 11'd422 && pix_y >= 10'd130 && pix_y < 10'd148)) ||
        ((cx >= 11'd600 && cx < 11'd676 && pix_y >= 10'd108 && pix_y < 10'd136) ||
         (cx >= 11'd616 && cx < 11'd660 && pix_y >= 10'd92  && pix_y < 10'd108));

    wire [10:0] gx = pix_x + {1'b0, ground_scroll};
    wire [11:0] ground_color =
        (active_mode && !bonus_active) ?
        // Space metallic deck
        ((pix_y < 10'd556 && floor_warn) ? 12'hF81 :
         (pix_y < 10'd555) ? 12'h567 :
         (pix_y < 10'd570) ? (gx[4] ? 12'h234 : 12'h345) : 12'h112) :
        // Classic grass & dirt
        ((pix_y < 10'd555) ? 12'h251 :
         (pix_y < 10'd570) ? ((((gx + pix_y) & 11'd16) != 11'd0) ? 12'h6D3 : 12'h4A2) :
                             ((((gx[3] ^ pix_y[3])) == 1'b1) ? 12'hC95 : 12'hB84));

    wire [11:0] space_color =
        in_planet   ? ((pl_dy > 12'sd0) ? 12'h427 : 12'h74B) :
        in_star_dot ? 12'hFFF :
        (pix_y < 10'd240) ? 12'h002 : (pix_y < 10'd420) ? 12'h103 : 12'h204;

    wire [11:0] sky_color =
        bonus_active ? (in_planet   ? ((pl_d2 <= 24'd676) ? 12'hFF6 : 12'hFE2) :
                        (in_sun_halo || in_sun_rays) ? 12'hFF8 : 12'hBEF) : // #b8edff Sky + Sun at Moon pos
        ((pix_y < 10'd220) ? 12'h4BC : (pix_y < 10'd400) ? 12'h6DE : 12'h9EF);

    // Voice Meter Bar: inside Top HUD Bar during PLAY/PAUSE (X=64..320, Y=44..60) or top-left in MODE/TUTORIAL
    wire show_mic      = (state != ST_HOME);
    wire [10:0] mic_x0 = in_hud_area ? 11'd64 : 11'd16;
    wire [9:0]  mic_y0 = in_hud_area ? 10'd44 : 10'd14;
    wire in_mic_box    = show_mic && (pix_x >= mic_x0) && (pix_x < mic_x0 + 11'd260) &&
                                     (pix_y >= mic_y0) && (pix_y < mic_y0 + 10'd20);
    wire in_mic_border = in_mic_box &&
                         (pix_x < mic_x0 + 11'd2 || pix_x >= mic_x0 + 11'd258 ||
                          pix_y < mic_y0 + 10'd2 || pix_y >= mic_y0 + 10'd18);
    wire [8:0] mic_rel_x   = pix_x - (mic_x0 + 11'd2);
    wire       on_thresh   = (mic_rel_x >= threshold) && (mic_rel_x < (threshold + 8'd4));
    wire       in_mic_fill = (mic_rel_x < volume);

    reg [11:0] bg_rgb;
    always @(*) begin
        if (state == ST_HOME)        bg_rgb = home_rgb;
        else if (in_hud_area)        bg_rgb = (pix_y >= (TOP_Y - 3)) ? 12'h123 : (pix_y < 10'd37) ? 12'h378 : 12'h256;
        else if (pix_y >= GROUND_Y)  bg_rgb = bonus_active ? 12'hFFF : ground_color;
        else if (in_spikes)          bg_rgb = (pix_y < 10'd538) ? 12'hFFF : 12'hF22;
        else if (in_pipe)            bg_rgb = pipe_color;
        else if (in_attack_obj)      bg_rgb = attack_color;
        else if (in_buff_circle)     bg_rgb = buff_circle_col;
        else if (in_bonus_aura)      bg_rgb = bonus_aura_col;
        else if (in_shield_ring)     bg_rgb = 12'h3F5;
        else if (active_mode && !bonus_active && (state == ST_PLAY || state == ST_PAUSE || state == ST_GAMEOVER))
                                     bg_rgb = space_color;
        else if (in_cloud && !(in_planet || in_sun_halo)) bg_rgb = 12'hFFF;
        else                         bg_rgb = sky_color;

        if (in_hud_elem)             bg_rgb = hud_elem_col;

        if (in_card_left) begin
            if (pix_x < 11'd95 || pix_x >= 11'd321 || pix_y < 10'd71 || pix_y >= 10'd233)
                bg_rgb = (!active_mode) ? 12'hFD2 : 12'h555;
            else if (in_pipe_bg)
                bg_rgb = (!active_mode) ? 12'h4C4 : 12'h777;
            else
                bg_rgb = (!active_mode) ? 12'h269 : 12'h333;
        end else if (in_card_right) begin
            if (pix_x < 11'd479 || pix_x >= 11'd705 || pix_y < 10'd71 || pix_y >= 10'd233)
                bg_rgb = (active_mode) ? 12'hFD2 : 12'h555;
            else if (pix_y >= 10'd218)
                bg_rgb = (active_mode) ? 12'hFF9 : 12'hCCC;
            else if (pix_y >= fire_hot_y)
                bg_rgb = (active_mode) ? 12'hFD2 : 12'hAAA;
            else if (pix_y >= fire_mid_y)
                bg_rgb = (active_mode) ? 12'hF61 : 12'h888;
            else if (pix_y >= fire_top_y || in_ember_spark)
                bg_rgb = (active_mode) ? 12'hC11 : 12'h666;
            else
                bg_rgb = (active_mode) ? 12'h311 : 12'h222;
        end else if (in_set_panel) begin
            if (pix_x < 11'd203 || pix_x >= 11'd597 || pix_y < 10'd279 || pix_y >= 10'd411)
                bg_rgb = 12'h6EF;
            else
                bg_rgb = 12'h113;
        end

        if (in_warn_border)       bg_rgb = cloud_scroll[2] ? 12'hF22 : 12'h700;
        else if (in_warn_popup)   bg_rgb = 12'h300;
        else if (in_popup_border) bg_rgb = 12'hFD2;
        else if (in_popup)        bg_rgb = 12'h113;

        if (in_cta_outer)         bg_rgb = 12'hFD2;
        else if (in_cta_inner)    bg_rgb = 12'hFFF;
        else if (in_cta_box)      bg_rgb = 12'h125;
        else if (in_wing_l_bdr || in_wing_r_bdr) bg_rgb = 12'h223;
        else if (in_wing_l_raw || in_wing_r_raw) bg_rgb = 12'hFFF;

        if (in_mic_border) begin
            bg_rgb = 12'h111;
        end else if (in_mic_box) begin
            if (on_thresh)       bg_rgb = 12'hF11;
            else if (in_mic_fill)bg_rgb = voice_active ? 12'h3E5 : 12'hFD2;
            else                 bg_rgb = 12'h123;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            vga_r <= 4'h0; vga_g <= 4'h0; vga_b <= 4'h0;
        end else if (pix_en) begin
            if (!video_on) begin
                {vga_r, vga_g, vga_b} <= 12'h000;
            end else if (in_text_box && font_pix_on) begin
                {vga_r, vga_g, vga_b} <= text_color;
            end else if (in_text_box && text_outline_en && font_outline_on) begin
                {vga_r, vga_g, vga_b} <= 12'h112;
            end else if (card_pixel_on) begin
                {vga_r, vga_g, vga_b} <= card_rgb;
            end else if (boss_victory && bird_pixel_on) begin
                {vga_r, vga_g, vga_b} <= bird_rgb;
            end else if (boss_pixel_on) begin
                {vga_r, vga_g, vga_b} <= boss_rgb;
            end else if (bird_pixel_on) begin
                {vga_r, vga_g, vga_b} <= bird_rgb;
            end else begin
                {vga_r, vga_g, vga_b} <= bg_rgb;
            end
        end
    end

endmodule
