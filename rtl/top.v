`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: top
// Target Board: Digilent Nexys A7-100T (XC7A100T-1CSG324C)
// Project: Voice-Controlled Pixel Flappy Pigeon
//
// Controls:
//   SW[3:0]  : Microphone sensitivity threshold (0 = most sensitive, 15 = loudest)
//   SW[4]    : Flight mode (0 = Continuous hold voice to fly up, 1 = Edge flap)
//   SW[6:5]  : Difficulty (00 = Easy, 01 = Normal, 10/11 = Hard)
//   SW[7]    : Button-only mode (1 = Mute mic trigger, use BTNC only)
//   SW[15]   : Mute audio SFX (1 = Muted)
//   BTNC     : Manual flap / Start / Restart (works alongside mic)
//   BTNU     : Pause / Resume
//   CPU_RESETN: Active-LOW system reset
//////////////////////////////////////////////////////////////////////////////////
module top (
    input  wire        CLK100MHZ,
    input  wire        CPU_RESETN,
    input  wire [15:0] SW,
    input  wire        BTNC,
    input  wire        BTNU,
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
    output wire        AUD_SD
);
    // -------------------------------------------------------------------------
    // Reset Synchronizer (active-LOW CPU_RESETN -> active-HIGH rst)
    // -------------------------------------------------------------------------
    reg rst_s0, rst_s1;
    always @(posedge CLK100MHZ) begin
        rst_s0 <= ~CPU_RESETN;
        rst_s1 <= rst_s0;
    end
    wire rst = rst_s1;

    // -------------------------------------------------------------------------
    // Debounced Pushbuttons
    // -------------------------------------------------------------------------
    wire btnc_lvl, btnc_rise;
    wire btnu_lvl, btnu_rise;

    debounce u_db_btnc (
        .clk      (CLK100MHZ),
        .rst      (rst),
        .btn_in   (BTNC),
        .btn_out  (btnc_lvl),
        .btn_rise (btnc_rise)
    );

    debounce u_db_btnu (
        .clk      (CLK100MHZ),
        .rst      (rst),
        .btn_in   (BTNU),
        .btn_out  (btnu_lvl),
        .btn_rise (btnu_rise)
    );

    // -------------------------------------------------------------------------
    // PDM Microphone & Voice Envelope / Threshold
    // -------------------------------------------------------------------------
    wire [7:0] mic_volume;
    wire [7:0] mic_threshold;
    wire       mic_voice_raw;

    pdm_mic u_pdm_mic (
        .clk          (CLK100MHZ),
        .rst          (rst),
        .m_clk        (M_CLK),
        .m_data       (M_DATA),
        .m_lrsel      (M_LRSEL),
        .sens_sw      (SW[3:0]),
        .volume       (mic_volume),
        .threshold    (mic_threshold),
        .voice_active (mic_voice_raw),
        .vu_leds      (LED)
    );

    wire voice_cmd = mic_voice_raw & ~SW[7];

    // -------------------------------------------------------------------------
    // VGA 640x480 @ 60Hz Timing
    // -------------------------------------------------------------------------
    wire       pix_en, video_on, frame_tick;
    wire [9:0] pix_x, pix_y;

    vga_sync u_vga_sync (
        .clk        (CLK100MHZ),
        .rst        (rst),
        .pix_en     (pix_en),
        .pix_x      (pix_x),
        .pix_y      (pix_y),
        .video_on   (video_on),
        .hsync      (VGA_HS),
        .vsync      (VGA_VS),
        .frame_tick (frame_tick)
    );

    // -------------------------------------------------------------------------
    // Game Engine
    // -------------------------------------------------------------------------
    wire [1:0]         game_state;
    wire [9:0]         bird_y;
    wire               bird_pose;
    wire signed [10:0] pipe0_x, pipe1_x, pipe2_x;
    wire [9:0]         pipe0_gap_y, pipe1_gap_y, pipe2_gap_y, pipe_gap_h;
    wire [9:0]         ground_scroll, cloud_scroll;
    wire [13:0]        score, high_score;
    wire               sfx_flap, sfx_score, sfx_hit;

    game_engine u_game (
        .clk            (CLK100MHZ),
        .rst            (rst),
        .frame_tick     (frame_tick),
        .voice_active   (voice_cmd),
        .btn_flap       (btnc_lvl),
        .btn_flap_rise  (btnc_rise),
        .btn_pause_rise (btnu_rise),
        .mode_edge      (SW[4]),
        .diff_sw        (SW[6:5]),
        .state          (game_state),
        .bird_y         (bird_y),
        .bird_pose      (bird_pose),
        .pipe0_x        (pipe0_x),
        .pipe1_x        (pipe1_x),
        .pipe2_x        (pipe2_x),
        .pipe0_gap_y    (pipe0_gap_y),
        .pipe1_gap_y    (pipe1_gap_y),
        .pipe2_gap_y    (pipe2_gap_y),
        .pipe_gap_h     (pipe_gap_h),
        .ground_scroll  (ground_scroll),
        .cloud_scroll   (cloud_scroll),
        .score          (score),
        .high_score     (high_score),
        .sfx_flap       (sfx_flap),
        .sfx_score      (sfx_score),
        .sfx_hit        (sfx_hit)
    );

    // -------------------------------------------------------------------------
    // BCD Conversion (shared by VGA HUD & 7-Segment Display)
    // -------------------------------------------------------------------------
    wire [15:0] score_bcd, high_score_bcd;

    bin2bcd u_bcd_score (
        .bin (score),
        .bcd (score_bcd)
    );

    bin2bcd u_bcd_high (
        .bin (high_score),
        .bcd (high_score_bcd)
    );

    // -------------------------------------------------------------------------
    // VGA Pixel Art Renderer
    // -------------------------------------------------------------------------
    vga_renderer u_vga_renderer (
        .clk            (CLK100MHZ),
        .rst            (rst),
        .pix_en         (pix_en),
        .video_on       (video_on),
        .pix_x          (pix_x),
        .pix_y          (pix_y),
        .state          (game_state),
        .bird_y         (bird_y),
        .bird_pose      (bird_pose),
        .pipe0_x        (pipe0_x),
        .pipe1_x        (pipe1_x),
        .pipe2_x        (pipe2_x),
        .pipe0_gap_y    (pipe0_gap_y),
        .pipe1_gap_y    (pipe1_gap_y),
        .pipe2_gap_y    (pipe2_gap_y),
        .pipe_gap_h     (pipe_gap_h),
        .ground_scroll  (ground_scroll),
        .cloud_scroll   (cloud_scroll),
        .score_bcd      (score_bcd),
        .high_score_bcd (high_score_bcd),
        .volume         (mic_volume),
        .threshold      (mic_threshold),
        .voice_active   (voice_cmd),
        .vga_r          (VGA_R),
        .vga_g          (VGA_G),
        .vga_b          (VGA_B)
    );

    // -------------------------------------------------------------------------
    // 7-Segment 8-Digit Display (Left 4 = High Score, Right 4 = Score)
    // -------------------------------------------------------------------------
    seven_seg_ctrl u_7seg (
        .clk            (CLK100MHZ),
        .rst            (rst),
        .high_score_bcd (high_score_bcd),
        .score_bcd      (score_bcd),
        .an             (AN),
        .seg            ({CA, CB, CC, CD, CE, CF, CG}),
        .dp             (DP)
    );

    // -------------------------------------------------------------------------
    // Mono Audio SFX
    // -------------------------------------------------------------------------
    audio_sfx u_audio (
        .clk       (CLK100MHZ),
        .rst       (rst),
        .mute      (SW[15]),
        .sfx_flap  (sfx_flap),
        .sfx_score (sfx_score),
        .sfx_hit   (sfx_hit),
        .aud_pwm   (AUD_PWM),
        .aud_sd    (AUD_SD)
    );

    // -------------------------------------------------------------------------
    // Dimmed RGB Status LED (LED16):
    //   Red = Game Over, Yellow = Paused, Green = Voice/Flap Active, Blue = Ready
    // -------------------------------------------------------------------------
    reg [3:0] led_pwm;
    always @(posedge CLK100MHZ) begin
        led_pwm <= led_pwm + 4'd1;
    end
    wire led_dim_en = (led_pwm < 4'd3);

    assign LED16_R = led_dim_en && ((game_state == 2'd3) || (game_state == 2'd2));
    assign LED16_G = led_dim_en && ((game_state == 2'd2) || ((game_state != 2'd3) && (voice_cmd || btnc_lvl)));
    assign LED16_B = led_dim_en && ((game_state != 2'd3) && (game_state != 2'd2) && ~(voice_cmd || btnc_lvl));

endmodule
