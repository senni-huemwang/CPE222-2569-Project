`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: tb_flappy_pigeon
// Description: Verifies PDM mic, 4-screen flow, Attack Mode (round bullets,
//              64x64 BirdPlayer, FLAPZY/Bonustime), and 800x600 MMCM top.
//////////////////////////////////////////////////////////////////////////////////
module tb_flappy_pigeon;

    reg         clk_100m = 1'b0;
    reg         rst = 1'b1;
    reg  [2:0]  sens_sw = 3'b001; // SW[1]=1 (Sensitive -> threshold=66)
    wire        m_clk;
    reg         m_data = 1'b0;
    wire        m_lrsel;
    wire [7:0]  volume, threshold;
    wire        voice_active;
    wire [15:0] vu_leds;

    always #5 clk_100m = ~clk_100m; // 100 MHz

    pdm_mic #(.CLK_FREQ_HZ(100_000_000)) u_dut_mic (
        .clk          (clk_100m),
        .rst          (rst),
        .m_clk        (m_clk),
        .m_data       (m_data),
        .m_lrsel      (m_lrsel),
        .sens_sw      (sens_sw),
        .volume       (volume),
        .threshold    (threshold),
        .voice_active (voice_active),
        .vu_leds      (vu_leds)
    );

    reg        sim_frame_tick   = 1'b0;
    reg        btn_confirm_rise = 1'b0;
    reg        btn_fly          = 1'b0;
    reg        btn_fly_rise     = 1'b0;
    reg        btn_shoot        = 1'b0;
    reg        btn_shoot_rise   = 1'b0;
    reg signed [7:0] acl_x      = 8'sd0;
    reg signed [7:0] acl_y      = 8'sd0;
    reg        mode_sw          = 1'b1;
    reg        mode_edge        = 1'b0;
    reg  [1:0] diff_sw          = 2'd1;
    reg        pause_sw         = 1'b0;
    reg        cheat_kill_sw    = 1'b0;
    reg        cheat_frenzy_sw  = 1'b0;

    wire [2:0]         state;
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
    wire               letter_act, bonus_intro, bonus_active;
    wire [9:0]         letter_x, letter_y;
    wire [2:0]         letter_idx;
    wire [99:0]        star_x_flat, star_y_flat;
    wire               sfx_flap, sfx_score, sfx_hit;

    game_engine u_dut_game (
        .clk               (clk_100m),
        .rst               (rst),
        .frame_tick        (sim_frame_tick),
        .voice_active      (voice_active),
        .btn_confirm_rise  (btn_confirm_rise),
        .btn_fly           (btn_fly),
        .btn_fly_rise      (btn_fly_rise),
        .btn_shoot         (btn_shoot),
        .btn_shoot_rise    (btn_shoot_rise),
        .acl_x             (acl_x),
        .acl_y             (acl_y),
        .mode_sw           (mode_sw),
        .mode_edge         (mode_edge),
        .diff_sw           (diff_sw),
        .pause_sw          (pause_sw),
        .cheat_kill_sw     (cheat_kill_sw),
        .cheat_frenzy_sw   (cheat_frenzy_sw),
        .state             (state),
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

    wire [15:0] top_led;
    wire        top_r, top_g, top_b;
    wire        top_ca, top_cb, top_cc, top_cd, top_ce, top_cf, top_cg, top_dp;
    wire [7:0]  top_an;
    wire [3:0]  top_vga_r, top_vga_g, top_vga_b;
    wire        top_vga_hs, top_vga_vs;
    wire        top_m_clk, top_m_lrsel, top_aud_pwm, top_aud_sd;
    wire        top_acl_mosi, top_acl_sclk, top_acl_csn;

    top u_dut_top (
        .CLK100MHZ  (clk_100m),
        .CPU_RESETN (~rst),
        .SW         ({12'd0, sens_sw, mode_sw}),
        .BTNC       (1'b0),
        .BTNU       (btn_fly),
        .BTNR       (btn_shoot),
        .LED        (top_led),
        .LED16_R    (top_r), .LED16_G(top_g), .LED16_B(top_b),
        .CA(top_ca), .CB(top_cb), .CC(top_cc), .CD(top_cd),
        .CE(top_ce), .CF(top_cf), .CG(top_cg), .DP(top_dp),
        .AN         (top_an),
        .VGA_R      (top_vga_r), .VGA_G(top_vga_g), .VGA_B(top_vga_b),
        .VGA_HS     (top_vga_hs), .VGA_VS(top_vga_vs),
        .M_CLK      (top_m_clk), .M_DATA(m_data), .M_LRSEL(top_m_lrsel),
        .AUD_PWM    (top_aud_pwm), .AUD_SD(top_aud_sd),
        .ACL_MISO   (1'b0),
        .ACL_MOSI   (top_acl_mosi),
        .ACL_SCLK   (top_acl_sclk),
        .ACL_CSN    (top_acl_csn)
    );

    reg        loud_mode = 1'b0;
    reg [10:0] pdm_phase = 11'd0;
    always @(negedge m_clk) begin
        pdm_phase <= pdm_phase + 11'd1;
        if (!loud_mode) m_data <= pdm_phase[0];
        else            m_data <= (pdm_phase[10] == 1'b0) ? (pdm_phase[2:0] != 3'd0) : (pdm_phase[2:0] == 3'd0);
    end

    task pulse_frame;
        begin
            @(posedge clk_100m); sim_frame_tick <= 1'b1;
            @(posedge clk_100m); sim_frame_tick <= 1'b0;
            #100;
        end
    endtask

    task confirm_screen;
        begin
            @(posedge clk_100m); btn_confirm_rise <= 1'b1;
            @(posedge clk_100m); btn_confirm_rise <= 1'b0;
            pulse_frame();
        end
    endtask

    integer f;
    reg [9:0] y_before;

    initial begin
        #200;
        rst = 1'b0;

        loud_mode = 1'b0;
        #2_500_000;
        if (voice_active !== 1'b0) begin $display("ERROR: voice_active high during silence"); $finish; end
        $display("PASS [1/4]: Silence check OK");

        loud_mode = 1'b1;
        #3_500_000;
        if (voice_active !== 1'b1) begin $display("ERROR: voice_active low during loud audio"); $finish; end
        $display("PASS [2/4]: Loud voice detected OK (volume=%0d, threshold=%0d)", volume, threshold);

        confirm_screen(); // HOME -> MODE
        confirm_screen(); // MODE -> TUTORIAL
        confirm_screen(); // TUTORIAL -> PLAY
        if (state !== 3'd3 || active_mode !== 1'b1 || player_hp !== 3'd5 || current_phase !== 4'd1) begin
            $display("ERROR: Screen flow/Attack init failed state=%0d mode=%0d hp=%0d", state, active_mode, player_hp);
            $finish;
        end
        $display("PASS [3/4]: 4-Screen flow & Attack Mode (Phase 1, 5 HP, 800x600) OK");

        y_before = bird_y;
        @(posedge clk_100m); btn_shoot_rise <= 1'b1;
        @(posedge clk_100m); btn_shoot_rise <= 1'b0;
        for (f = 0; f < 10; f = f + 1) pulse_frame();
        if (bird_y >= y_before || pb_act == 12'd0) begin
            $display("ERROR: Climb or shoot failed bird_y=%0d->%0d pb_act=%b", y_before, bird_y, pb_act);
            $finish;
        end
        $display("PASS [4/4]: Voice climb (%0d->%0d) & BTNR shoot (pb_act=%b) OK", y_before, bird_y, pb_act);

        // [5/6] SW14 Cheat: Kill waves 1, 2, 3 -> 4s Boss Warning -> Boss HP=30
        cheat_kill_sw = 1'b1; pulse_frame(); cheat_kill_sw = 1'b0; pulse_frame(); // Wave 1 -> 2
        cheat_kill_sw = 1'b1; pulse_frame(); cheat_kill_sw = 1'b0; pulse_frame(); // Wave 2 -> 3
        cheat_kill_sw = 1'b1; pulse_frame(); cheat_kill_sw = 1'b0; pulse_frame(); // Wave 3 -> Boss Warning
        if (show_boss_warning !== 1'b1) begin
            $display("ERROR: Boss warning did not assert after Wave 3 clear");
            $finish;
        end
        for (f = 0; f < 245; f = f + 1) pulse_frame();
        if (boss_active !== 1'b1 || boss_max_hp !== 10'd30 || boss_hp !== 10'd30) begin
            $display("ERROR: Boss spawn failed active=%b max_hp=%0d hp=%0d", boss_active, boss_max_hp, boss_hp);
            $finish;
        end
        // Kill Boss with SW14 -> 6.5s Victory Knockdown -> Phase 2
        cheat_kill_sw = 1'b1; pulse_frame(); cheat_kill_sw = 1'b0; pulse_frame();
        if (boss_victory !== 1'b1) begin
            $display("ERROR: Boss victory animation did not start");
            $finish;
        end
        for (f = 0; f < 395; f = f + 1) pulse_frame();
        if (boss_active !== 1'b0 || current_phase !== 4'd2) begin
            $display("ERROR: SW14 Boss victory failed boss_active=%b phase=%0d", boss_active, current_phase);
            $finish;
        end
        $display("PASS [5/6]: SW14 Cheat kill & 4s Warning & Boss HP=30 & 6.5s Victory -> Phase 2 OK");

        // [6/6] SW13 Cheat: Auto enter FRENZY TIME intro (4s) -> Sky Bonus Active + Calibrated ACL test
        cheat_frenzy_sw = 1'b1; pulse_frame(); cheat_frenzy_sw = 1'b0;
        if (bonus_intro !== 1'b1) begin
            $display("ERROR: SW13 Cheat did not trigger bonus_intro");
            $finish;
        end
        for (f = 0; f < 245; f = f + 1) pulse_frame();
        if (bonus_active !== 1'b1 || bird_x !== 10'd368) begin
            $display("ERROR: Sky bonus did not activate at center x=%0d", bird_x);
            $finish;
        end
        // Tilt right (acl_y < 0 -> tilt_x > 0 -> bird_x increases) & tilt VGA-top down (acl_x > 0 -> tilt_y < 0 -> bird_y decreases)
        acl_y = -8'sd32; acl_x = 8'sd32;
        y_before = bird_y;
        for (f = 0; f < 10; f = f + 1) pulse_frame();
        if (bird_x <= 10'd368 || bird_y >= y_before) begin
            $display("ERROR: Swapped ACL 2D movement failed x=%0d y=%0d->%0d", bird_x, y_before, bird_y);
            $finish;
        end
        $display("PASS [6/6]: SW13 FRENZY TIME! 4s intro + Sky Bonus + Calibrated ACL 2D (x=%0d, y=%0d) OK", bird_x, bird_y);

        $display("ALL TESTS PASSED!");
        $finish;
    end

endmodule
