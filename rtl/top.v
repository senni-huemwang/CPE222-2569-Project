`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: top
// Target Board: Digilent Nexys A7-100T (XC7A100T-1CSG324C)
// Resolution: 800x600 @ 60Hz (40 MHz pixel clock from 80 MHz MMCM clock)
//////////////////////////////////////////////////////////////////////////////////
module top (
    input  wire        CLK100MHZ,
    input  wire        CPU_RESETN,
    input  wire [15:0] SW,
    input  wire        BTNC,
    input  wire        BTNU,
    input  wire        BTNR,
    output wire [15:0] LED,
    output wire        LED16_R,
    output wire        LED16_G,
    output wire        LED16_B,
    output wire        CA, CB, CC, CD, CE, CF, CG,
    output wire        DP,
    output wire [7:0]  AN,
    output wire [3:0]  VGA_R,
    output wire [3:0]  VGA_G,
    output wire [3:0]  VGA_B,
    output wire        VGA_HS,
    output wire        VGA_VS,
    output wire        M_CLK,
    input  wire        M_DATA,
    output wire        M_LRSEL,
    output wire        AUD_PWM,
    output wire        AUD_SD,
    input  wire        ACL_MISO,
    output wire        ACL_MOSI,
    output wire        ACL_SCLK,
    output wire        ACL_CSN
);
    // -------------------------------------------------------------------------
    // MMCM: 100 MHz -> 80.0 MHz (for 40 MHz 800x600@60Hz VGA pixel enable)
    // -------------------------------------------------------------------------
    wire clk_fb, clk_80m_unbuf, clk_80m, mmcm_locked;

    MMCME2_BASE #(
        .BANDWIDTH("OPTIMIZED"),
        .CLKFBOUT_MULT_F(8.0),   // 100 MHz * 8 = 800 MHz VCO
        .CLKIN1_PERIOD(10.0),
        .CLKOUT0_DIVIDE_F(10.0), // 800 MHz / 10 = 80 MHz
        .DIVCLK_DIVIDE(1),
        .STARTUP_WAIT("FALSE")
    ) u_mmcm (
        .CLKOUT0(clk_80m_unbuf),
        .CLKFBOUT(clk_fb),
        .LOCKED(mmcm_locked),
        .CLKIN1(CLK100MHZ),
        .PWRDWN(1'b0),
        .RST(1'b0),
        .CLKFBIN(clk_fb)
    );

    BUFG u_bufg_80m (.I(clk_80m_unbuf), .O(clk_80m));

    // Reset Synchronizer
    reg rst_s0, rst_s1;
    always @(posedge clk_80m) begin
        rst_s0 <= (~CPU_RESETN) | (~mmcm_locked);
        rst_s1 <= rst_s0;
    end
    wire rst = rst_s1;

    // Debounced Pushbuttons
    wire btnc_lvl, btnc_rise;
    wire btnu_lvl, btnu_rise;
    wire btnr_lvl, btnr_rise;

    debounce #(.CLK_FREQ_HZ(80_000_000)) u_db_btnc (.clk(clk_80m), .rst(rst), .btn_in(BTNC), .btn_out(btnc_lvl), .btn_rise(btnc_rise));
    debounce #(.CLK_FREQ_HZ(80_000_000)) u_db_btnu (.clk(clk_80m), .rst(rst), .btn_in(BTNU), .btn_out(btnu_lvl), .btn_rise(btnu_rise));
    debounce #(.CLK_FREQ_HZ(80_000_000)) u_db_btnr (.clk(clk_80m), .rst(rst), .btn_in(BTNR), .btn_out(btnr_lvl), .btn_rise(btnr_rise));

    // PDM Microphone
    wire [7:0] mic_volume, mic_threshold;
    wire       mic_voice_raw;

    pdm_mic #(.CLK_FREQ_HZ(80_000_000)) u_pdm_mic (
        .clk          (clk_80m),
        .rst          (rst),
        .m_clk        (M_CLK),
        .m_data       (M_DATA),
        .m_lrsel      (M_LRSEL),
        .sens_sw      (SW[3:1]),
        .volume       (mic_volume),
        .threshold    (mic_threshold),
        .voice_active (mic_voice_raw),
        .vu_leds      (LED)
    );
    wire               bonus_intro, bonus_active;
    wire               voice_cmd = mic_voice_raw & ~SW[7] & ~(bonus_intro | bonus_active);

    // ADXL362 Accelerometer (for Bonustime)
    wire signed [7:0] acl_x, acl_y;
    acl_driver #(.CLK_FREQ_HZ(80_000_000)) u_acl (
        .clk      (clk_80m),
        .rst      (rst),
        .acl_miso (ACL_MISO),
        .acl_mosi (ACL_MOSI),
        .acl_sclk (ACL_SCLK),
        .acl_csn  (ACL_CSN),
        .acl_x    (acl_x),
        .acl_y    (acl_y)
    );

    // VGA 800x600 @ 60Hz Timing
    wire        pix_en, video_on, frame_tick;
    wire [10:0] pix_x;
    wire [9:0]  pix_y;

    vga_sync u_vga_sync (
        .clk        (clk_80m),
        .rst        (rst),
        .pix_en     (pix_en),
        .pix_x      (pix_x),
        .pix_y      (pix_y),
        .video_on   (video_on),
        .hsync      (VGA_HS),
        .vsync      (VGA_VS),
        .frame_tick (frame_tick)
    );

    // Game Engine
    wire [2:0]         game_state;
    wire               active_mode;
    wire [9:0]         bird_x, bird_y;
    wire               bird_pose;
    wire [9:0]         ground_scroll, cloud_scroll;
    wire [13:0]        score, high_score;
    wire signed [11:0] pipe0_x, pipe1_x, pipe2_x;
    wire [9:0]         pipe0_gap_y, pipe1_gap_y, pipe2_gap_y, pipe_gap_h;
    wire [2:0]         player_hp;
    wire               player_invuln, shield_on, triple_on, rapid_on;
    wire [8:0]         buff_timer_bar;
    wire               floor_warn, floor_hazard;
    wire [7:0]         en_act;
    wire [95:0]        en_x_flat;
    wire [79:0]        en_y_flat;
    wire [15:0]        pb_act;
    wire [11:0]        eb_act;
    wire [159:0]       pb_x_flat, pb_y_flat;
    wire [119:0]       eb_x_flat, eb_y_flat;
    wire               boss_active;
    wire [9:0]         boss_x, boss_y, boss_hp, boss_max_hp;
    wire               boss_blink, boss_victory, boss_knocked_down;
    wire               show_phase_banner, show_boss_warning;
    wire [3:0]         current_phase, frenzy_dim_cnt;
    wire               buff_act;
    wire [9:0]         buff_x, buff_y;
    wire [1:0]         buff_type;
    wire [5:0]         flapzy_mask;
    wire [9:0]         star_act;
    wire               letter_act;
    wire [9:0]         letter_x, letter_y;
    wire [2:0]         letter_idx;
    wire [99:0]        star_x_flat, star_y_flat;
    wire               sfx_flap, sfx_score, sfx_hit;

    game_engine u_game (
        .clk               (clk_80m),
        .rst               (rst),
        .frame_tick        (frame_tick),
        .voice_active      (voice_cmd),
        .btn_confirm_rise  (btnc_rise),
        .btn_fly           (btnu_lvl),
        .btn_fly_rise      (btnu_rise),
        .btn_shoot         (btnr_lvl),
        .btn_shoot_rise    (btnr_rise),
        .acl_x             (acl_x),
        .acl_y             (acl_y),
        .mode_sw           (SW[0]),
        .mode_edge         (SW[4]),
        .diff_sw           (SW[6:5]),
        .pause_sw          (SW[15]),
        .cheat_kill_sw     (SW[14]),
        .cheat_frenzy_sw   (SW[13]),
        .state             (game_state),
        .active_mode       (active_mode),
        .bird_x            (bird_x),
        .bird_y            (bird_y),
        .bird_pose         (bird_pose),
        .ground_scroll     (ground_scroll),
        .cloud_scroll      (cloud_scroll),
        .score             (score),
        .high_score        (high_score),
        .pipe0_x           (pipe0_x),
        .pipe1_x           (pipe1_x),
        .pipe2_x           (pipe2_x),
        .pipe0_gap_y       (pipe0_gap_y),
        .pipe1_gap_y       (pipe1_gap_y),
        .pipe2_gap_y       (pipe2_gap_y),
        .pipe_gap_h        (pipe_gap_h),
        .player_hp         (player_hp),
        .player_invuln     (player_invuln),
        .shield_on         (shield_on),
        .triple_on         (triple_on),
        .rapid_on          (rapid_on),
        .buff_timer_bar    (buff_timer_bar),
        .floor_warn        (floor_warn),
        .floor_hazard      (floor_hazard),
        .en_act            (en_act),
        .en_x_flat         (en_x_flat),
        .en_y_flat         (en_y_flat),
        .pb_act            (pb_act),
        .pb_x_flat         (pb_x_flat),
        .pb_y_flat         (pb_y_flat),
        .eb_act            (eb_act),
        .eb_x_flat         (eb_x_flat),
        .eb_y_flat         (eb_y_flat),
        .boss_active       (boss_active),
        .boss_x            (boss_x),
        .boss_y            (boss_y),
        .boss_hp           (boss_hp),
        .boss_max_hp       (boss_max_hp),
        .boss_blink        (boss_blink),
        .boss_victory      (boss_victory),
        .boss_knocked_down (boss_knocked_down),
        .show_phase_banner (show_phase_banner),
        .show_boss_warning (show_boss_warning),
        .current_phase     (current_phase),
        .buff_act          (buff_act),
        .buff_x            (buff_x),
        .buff_y            (buff_y),
        .buff_type         (buff_type),
        .flapzy_mask       (flapzy_mask),
        .letter_act        (letter_act),
        .letter_x          (letter_x),
        .letter_y          (letter_y),
        .letter_idx        (letter_idx),
        .bonus_intro       (bonus_intro),
        .bonus_active      (bonus_active),
        .frenzy_dim_cnt    (frenzy_dim_cnt),
        .star_act          (star_act),
        .star_x_flat       (star_x_flat),
        .star_y_flat       (star_y_flat),
        .sfx_flap          (sfx_flap),
        .sfx_score         (sfx_score),
        .sfx_hit           (sfx_hit)
    );

    // BCD Conversion
    wire [15:0] score_bcd, high_score_bcd, boss_hp_bcd;
    bin2bcd u_bcd_score (.bin(score),             .bcd(score_bcd));
    bin2bcd u_bcd_high  (.bin(high_score),        .bcd(high_score_bcd));
    bin2bcd u_bcd_boss  (.bin({4'd0, boss_hp}),   .bcd(boss_hp_bcd));

    // VGA Renderer
    vga_renderer u_vga_renderer (
        .clk               (clk_80m),
        .rst               (rst),
        .pix_en            (pix_en),
        .video_on          (video_on),
        .pix_x             (pix_x),
        .pix_y             (pix_y),
        .state             (game_state),
        .active_mode       (active_mode),
        .sens_sw           (SW[3:1]),
        .bird_x            (bird_x),
        .bird_y            (bird_y),
        .bird_pose         (bird_pose),
        .ground_scroll     (ground_scroll),
        .cloud_scroll      (cloud_scroll),
        .score_bcd         (score_bcd),
        .high_score_bcd    (high_score_bcd),
        .boss_hp_bcd       (boss_hp_bcd),
        .volume            (mic_volume),
        .threshold         (mic_threshold),
        .voice_active      (voice_cmd),
        .pipe0_x           (pipe0_x),
        .pipe1_x           (pipe1_x),
        .pipe2_x           (pipe2_x),
        .pipe0_gap_y       (pipe0_gap_y),
        .pipe1_gap_y       (pipe1_gap_y),
        .pipe2_gap_y       (pipe2_gap_y),
        .pipe_gap_h        (pipe_gap_h),
        .player_hp         (player_hp),
        .player_invuln     (player_invuln),
        .shield_on         (shield_on),
        .triple_on         (triple_on),
        .rapid_on          (rapid_on),
        .buff_timer_bar    (buff_timer_bar),
        .floor_warn        (floor_warn),
        .floor_hazard      (floor_hazard),
        .en_act            (en_act),
        .en_x_flat         (en_x_flat),
        .en_y_flat         (en_y_flat),
        .pb_act            (pb_act),
        .pb_x_flat         (pb_x_flat),
        .pb_y_flat         (pb_y_flat),
        .eb_act            (eb_act),
        .eb_x_flat         (eb_x_flat),
        .eb_y_flat         (eb_y_flat),
        .boss_active       (boss_active),
        .boss_x            (boss_x),
        .boss_y            (boss_y),
        .boss_hp           (boss_hp),
        .boss_max_hp       (boss_max_hp),
        .boss_blink        (boss_blink),
        .boss_victory      (boss_victory),
        .boss_knocked_down (boss_knocked_down),
        .show_phase_banner (show_phase_banner),
        .show_boss_warning (show_boss_warning),
        .current_phase     (current_phase),
        .buff_act          (buff_act),
        .buff_x            (buff_x),
        .buff_y            (buff_y),
        .buff_type         (buff_type),
        .flapzy_mask       (flapzy_mask),
        .letter_act        (letter_act),
        .letter_x          (letter_x),
        .letter_y          (letter_y),
        .letter_idx        (letter_idx),
        .bonus_intro       (bonus_intro),
        .bonus_active      (bonus_active),
        .frenzy_dim_cnt    (frenzy_dim_cnt),
        .star_act          (star_act),
        .star_x_flat       (star_x_flat),
        .star_y_flat       (star_y_flat),
        .vga_r             (VGA_R),
        .vga_g             (VGA_G),
        .vga_b             (VGA_B)
    );

    // 7-Segment: Left 4 = Score, Right 4 = Ph-X (Attack mode)
    seven_seg_ctrl u_7seg (
        .clk           (clk_80m),
        .rst           (rst),
        .active_mode   (active_mode),
        .current_phase (current_phase),
        .score_bcd     (score_bcd),
        .an            (AN),
        .seg           ({CA, CB, CC, CD, CE, CF, CG}),
        .dp            (DP)
    );

    // Mono Audio SFX
    audio_sfx u_audio (
        .clk       (clk_80m),
        .rst       (rst),
        .mute      (SW[14]),
        .sfx_flap  (sfx_flap),
        .sfx_score (sfx_score),
        .sfx_hit   (sfx_hit),
        .aud_pwm   (AUD_PWM),
        .aud_sd    (AUD_SD)
    );

    // Dimmed RGB Status LED (LED16)
    reg [3:0] led_pwm;
    always @(posedge clk_80m) led_pwm <= led_pwm + 4'd1;
    wire led_dim_en = (led_pwm < 4'd3);

    assign LED16_R = led_dim_en && ((game_state == 3'd5) || (game_state == 3'd4));
    assign LED16_G = led_dim_en && ((game_state == 3'd4) || ((game_state != 3'd5) && (voice_cmd || btnu_lvl)));
    assign LED16_B = led_dim_en && ((game_state != 3'd5) && (game_state != 3'd4) && ~(voice_cmd || btnu_lvl));

endmodule
