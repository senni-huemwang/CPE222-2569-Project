`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: game_engine
// Description: Dual-mode 800x600 game engine for Nexys A7-100T:
//              - 64x64 BirdPlayer sprite
//              - Phase +1 multi-bullet upgrade (+ Triple Shot = 3 dirs x Phase)
//              - Boss hit blink & 150->0 HP countdown + PHASE X banner
//              - FLAPZY letter drops -> BONUSTIME sky coin rush (Accelerometer)
//////////////////////////////////////////////////////////////////////////////////
module game_engine (
    input  wire        clk,
    input  wire        rst,
    input  wire        frame_tick,      // 60 Hz pulse
    // Controls
    input  wire        voice_active,
    input  wire        btn_confirm_rise,
    input  wire        btn_fly,
    input  wire        btn_fly_rise,
    input  wire        btn_shoot,
    input  wire        btn_shoot_rise,
    input  wire signed [7:0] acl_x,     // Accelerometer X for Bonustime
    input  wire signed [7:0] acl_y,     // Accelerometer Y for Bonustime
    input  wire        mode_sw,         // SW[0]: 0=Classic, 1=Attack
    input  wire        mode_edge,       // SW[4]
    input  wire [1:0]  diff_sw,         // SW[6:5]
    input  wire        pause_sw,        // SW[15]
    input  wire        cheat_kill_sw,   // SW[14]: Kill all enemies & Boss in scene
    input  wire        cheat_frenzy_sw, // SW[13]: Enter FRENZY Time automatically
    // Shared State
    output reg  [2:0]  state,           // 0=HOME,1=MODE,2=TUTORIAL,3=PLAY,4=PAUSE,5=GAMEOVER
    output reg         active_mode,
    output reg  [9:0]  bird_x,
    output wire [9:0]  bird_y,
    output wire        bird_pose,
    output reg  [9:0]  ground_scroll,
    output reg  [9:0]  cloud_scroll,
    output reg  [13:0] score,
    output reg  [13:0] high_score,
    // Classic Pipes
    output wire signed [11:0] pipe0_x, pipe1_x, pipe2_x,
    output wire [9:0]  pipe0_gap_y, pipe1_gap_y, pipe2_gap_y,
    output wire [9:0]  pipe_gap_h,
    // Attack Mode State
    output reg  [2:0]  player_hp,
    output wire        player_invuln,
    output reg         shield_on,
    output wire        triple_on,
    output wire        rapid_on,
    output wire [8:0]  buff_timer_bar,  // Remaining buff ticks for HUD bar
    output reg         floor_warn,
    output reg         floor_hazard,
    output reg  [7:0]  en_act,
    output wire [95:0] en_x_flat,       // 8 x 12-bit signed
    output wire [79:0] en_y_flat,       // 8 x 10-bit
    output reg  [15:0] pb_act,          // 16 player bullets
    output wire [159:0] pb_x_flat,      // 16 x 10-bit
    output wire [159:0] pb_y_flat,      // 16 x 10-bit
    output reg  [11:0] eb_act,          // 12 enemy bullets
    output wire [119:0] eb_x_flat,
    output wire [119:0] eb_y_flat,
    output reg         boss_active,
    output reg  [9:0]  boss_x,
    output reg  [9:0]  boss_y,
    output reg  [9:0]  boss_hp,
    output reg  [9:0]  boss_max_hp,
    output wire        boss_blink,
    output wire        boss_victory,
    output reg         boss_knocked_down,
    output wire        show_phase_banner,
    output wire        show_boss_warning,
    output wire [3:0]  current_phase,
    output reg         buff_act,
    output reg  [9:0]  buff_x,
    output reg  [9:0]  buff_y,
    output reg  [1:0]  buff_type,       // 0=Triple(Pink), 1=Rapid(Yellow), 2=Shield(Green), 3=Heart
    // FLAPZY & BONUSTIME
    output reg  [5:0]  flapzy_mask,     // Bits 0..5 = F,L,A,P,Z,Y
    output reg         letter_act,
    output reg  [9:0]  letter_x,
    output reg  [9:0]  letter_y,
    output reg  [2:0]  letter_idx,      // 0..5
    output wire        bonus_intro,
    output wire        bonus_active,
    output wire [3:0]  frenzy_dim_cnt,  // 0..11 letters extinguished
    output reg  [9:0]  star_act,        // 10 bonus flowers
    output wire [99:0] star_x_flat,
    output wire [99:0] star_y_flat,
    // Audio SFX
    output reg         sfx_flap,
    output reg         sfx_score,
    output reg         sfx_hit
);
    localparam [2:0] ST_HOME     = 3'd0,
                     ST_MODE     = 3'd1,
                     ST_TUTORIAL = 3'd2,
                     ST_PLAY     = 3'd3,
                     ST_PAUSE    = 3'd4,
                     ST_GAMEOVER = 3'd5;

    localparam integer TOP_Y        = 74;  // Below Feeding-Frenzy top HUD bar
    localparam integer GROUND_Y     = 552;
    localparam integer PIPE_W       = 64;
    localparam integer PIPE_SPACING = 280;

    // Classic Difficulty
    wire [9:0] cfg_gap_h = (diff_sw == 2'd0) ? 10'd176 :
                           (diff_sw == 2'd1) ? 10'd156 : 10'd138;
    wire signed [11:0] cfg_speed = (diff_sw == 2'd0) ? 12'sd2 :
                                   (diff_sw == 2'd1) ? 12'sd3 : 12'sd4;
    assign pipe_gap_h = cfg_gap_h;

    // Fixed-point Bird Y (Q10.4 signed)
    reg signed [14:0] bird_y_fp;
    reg signed [9:0]  vel_y;
    assign bird_y = bird_y_fp[14:4];

    // Forgiving hitbox inside 64x64 BirdPlayer
    wire [9:0] hit_x_l = bird_x + 10'd12;
    wire [9:0] hit_x_r = bird_x + 10'd52;
    wire [9:0] hit_y_t = bird_y + 10'd12;
    wire [9:0] hit_y_b = bird_y + 10'd54;

    // Calibrated Nexys A7 ADXL362 axes (VGA at TOP edge -> X/Y swapped & sign inverted)
    wire signed [7:0] tilt_x = -acl_y;
    wire signed [7:0] tilt_y = -acl_x;

    // Classic Pipes
    reg signed [11:0] px [0:2];
    reg        [9:0]  pgap [0:2];
    reg               pscored [0:2];
    assign pipe0_x = px[0]; assign pipe1_x = px[1]; assign pipe2_x = px[2];
    assign pipe0_gap_y = pgap[0]; assign pipe1_gap_y = pgap[1]; assign pipe2_gap_y = pgap[2];

    // Attack Mode Arrays
    reg signed [11:0] en_x [0:7];
    reg        [9:0]  en_y [0:7];
    reg        [2:0]  en_hp [0:7];
    reg               en_dir [0:7];
    reg        [9:0]  pb_x [0:15];
    reg        [9:0]  pb_y [0:15];
    reg signed [3:0]  pb_vy [0:15];
    reg        [9:0]  eb_x [0:11];
    reg        [9:0]  eb_y [0:11];
    reg signed [3:0]  eb_vy [0:11];
    reg        [9:0]  star_x [0:9];
    reg        [9:0]  star_y [0:9];

    genvar g;
    generate
        for (g = 0; g < 8; g = g + 1) begin : gen_en_pack
            assign en_x_flat[g*12 +: 12] = en_x[g];
            assign en_y_flat[g*10 +: 10] = en_y[g];
        end
        for (g = 0; g < 16; g = g + 1) begin : gen_pb_pack
            assign pb_x_flat[g*10 +: 10] = pb_x[g];
            assign pb_y_flat[g*10 +: 10] = pb_y[g];
        end
        for (g = 0; g < 12; g = g + 1) begin : gen_eb_pack
            assign eb_x_flat[g*10 +: 10] = eb_x[g];
            assign eb_y_flat[g*10 +: 10] = eb_y[g];
        end
        for (g = 0; g < 10; g = g + 1) begin : gen_s_pack
            assign star_x_flat[g*10 +: 10] = star_x[g];
            assign star_y_flat[g*10 +: 10] = star_y[g];
        end
    endgenerate

    // Timers & Wave State
    reg [8:0] invuln_cnt;
    reg [8:0] triple_timer;
    reg [8:0] rapid_timer;
    reg [3:0] rapid_cd;
    reg [9:0] hazard_timer;
    reg [1:0] wave_in_cycle;
    reg [3:0] cycle_num;
    reg       boss_dir;
    reg [2:0] boss_pat;
    reg [4:0] boss_hit_cnt;
    reg [8:0] boss_victory_cnt;
    reg [7:0] phase_banner_cnt;
    reg [7:0] boss_warning_cnt;
    reg [7:0] boss_buff_cd;
    reg [6:0] enemy_fire_cd;
    reg [6:0] boss_fire_cd;
    reg [8:0] letter_cd;
    reg       bonus_pending;
    reg [7:0] bonus_intro_cnt;
    reg [9:0] bonus_timer;
    reg [9:0] star_base_y [0:9];
    reg       cheat_kill_d, cheat_frenzy_d;
    reg       cheat_kill_latched, cheat_frenzy_latched;

    assign player_invuln     = (invuln_cnt != 9'd0) && invuln_cnt[2];
    assign triple_on         = (triple_timer != 9'd0);
    assign rapid_on          = (rapid_timer  != 9'd0);
    assign buff_timer_bar    = (triple_timer > rapid_timer) ? triple_timer : rapid_timer;
    assign boss_blink        = (boss_hit_cnt != 5'd0) && boss_hit_cnt[1];
    assign boss_victory      = (boss_victory_cnt != 9'd0);
    assign show_phase_banner = (phase_banner_cnt != 8'd0);
    assign show_boss_warning = (boss_warning_cnt != 8'd0);
    assign current_phase     = cycle_num + 4'd1;
    assign bonus_intro       = (bonus_intro_cnt != 8'd0);
    assign bonus_active      = (bonus_timer != 10'd0);
    wire [9:0] bonus_elapsed = bonus_active ? (10'd600 - bonus_timer) : 10'd0;
    assign frenzy_dim_cnt    = (bonus_elapsed >= 10'd594) ? 4'd11 : (bonus_elapsed / 10'd54);

    function signed [9:0] wave_sin;
        input [3:0] p;
        begin
            case (p)
                4'd0:  wave_sin =  10'sd0;
                4'd1:  wave_sin =  10'sd22;
                4'd2:  wave_sin =  10'sd40;
                4'd3:  wave_sin =  10'sd52;
                4'd4:  wave_sin =  10'sd56;
                4'd5:  wave_sin =  10'sd52;
                4'd6:  wave_sin =  10'sd40;
                4'd7:  wave_sin =  10'sd22;
                4'd8:  wave_sin =  10'sd0;
                4'd9:  wave_sin = -10'sd22;
                4'd10: wave_sin = -10'sd40;
                4'd11: wave_sin = -10'sd52;
                4'd12: wave_sin = -10'sd56;
                4'd13: wave_sin = -10'sd52;
                4'd14: wave_sin = -10'sd40;
                default: wave_sin = -10'sd22;
            endcase
        end
    endfunction

    // LFSR
    reg [15:0] lfsr;
    wire [9:0] range_w    = 10'd360 - cfg_gap_h;
    wire [9:0] rand_raw   = {2'b00, lfsr[7:0]};
    wire [9:0] rand_mod   = (rand_raw >= range_w) ? (rand_raw - range_w) : rand_raw;
    wire [9:0] next_gap_y = 10'd120 + rand_mod;

    // Edge latches (Mic disabled during FRENZY mode)
    reg prev_voice, confirm_latched, fly_rise_latched, shoot_rise_latched;
    wire in_frenzy_mode = bonus_intro | bonus_active;
    wire ctrl_hold      = (~in_frenzy_mode) & (voice_active | btn_fly);
    wire voice_rise     = (~in_frenzy_mode) & voice_active & ~prev_voice;

    reg [5:0] anim_cnt, go_cooldown;
    reg [4:0] flap_sfx_cd;

    assign bird_pose = (state == ST_HOME || state == ST_MODE || state == ST_TUTORIAL) ? anim_cnt[4] :
                       (state == ST_GAMEOVER) ? 1'b0 :
                       (ctrl_hold || (vel_y < 10'sd0) || bonus_active || bonus_intro) ? anim_cnt[3] : 1'b0;

    // Classic Pipe Collision
    reg hit_pipe;
    integer k;
    always @(*) begin
        hit_pipe = 1'b0;
        for (k = 0; k < 3; k = k + 1) begin
            if ((px[k] < $signed({1'b0, hit_x_r})) && ((px[k] + PIPE_W) > $signed({1'b0, hit_x_l}))) begin
                if ((hit_y_t < pgap[k]) || (hit_y_b > (pgap[k] + cfg_gap_h))) begin
                    hit_pipe = 1'b1;
                end
            end
        end
    end
    wire hit_ground = (bird_y >= (GROUND_Y - 58)); // 552 - 58 = 494

    task spawn_wave;
        input [3:0] cyc;
        input [1:0] w_idx;
        integer idx;
        integer cnt;
        begin
            cnt = 2 + cyc + (w_idx * 2);
            if (cnt > 8) cnt = 8;
            for (idx = 0; idx < 8; idx = idx + 1) begin
                en_act[idx] <= (idx < cnt) ? 1'b1 : 1'b0;
                en_x[idx]   <= 12'sd800 + (idx * 12'sd26);
                en_y[idx]   <= 10'd92 + (idx * 10'd52) + {6'd0, lfsr[2:0]};
                en_hp[idx]  <= (cyc == 0) ? 3'd2 : (cyc == 1) ? 3'd3 : 3'd4;
                en_dir[idx] <= idx[0];
            end
        end
    endtask

    task start_frenzy_intro;
        begin
            bonus_intro_cnt <= 8'd240; // 4-second FRENZY TIME! intro animation
            bonus_pending   <= 1'b0;
            eb_act          <= 12'd0;
            pb_act          <= 12'd0;
            letter_act      <= 1'b0;
            buff_act        <= 1'b0;
            sfx_score       <= 1'b1;
        end
    endtask

    function [9:0] pattern_flower_y;
        input [3:0] idx;
        input [1:0] pat;
        input [6:0] rnd;
        reg [9:0] val;
        begin
            case (pat)
                2'd3: val = idx[0] ? 10'd185 : 10'd385; // Wide opposing waves
                2'd2: val = 10'd145 + ((idx < 4'd5) ? (idx * 10'd64) : ((4'd9 - idx) * 10'd64)); // V-sweep
                2'd1: val = 10'd138 + (idx * 10'd34); // Full-map staircase (138..444)
                default: val = idx[0] ? (10'd140 + {3'b000, rnd}) : (10'd330 + {3'b000, rnd}); // Dual high/low lanes
            endcase
            pattern_flower_y = val;
        end
    endfunction

    task fire_player_bullet;
        input [9:0] by;
        input signed [3:0] bvy;
        integer idx;
        reg done;
        begin
            done = 1'b0;
            for (idx = 0; idx < 16; idx = idx + 1) begin
                if (!done && !pb_act[idx]) begin
                    pb_act[idx] = 1'b1;
                    pb_x[idx]   = bird_x + 10'd58;
                    pb_y[idx]   = by;
                    pb_vy[idx]  = bvy;
                    done        = 1'b1;
                end
            end
        end
    endtask

    // Phase 1 = 1 dir (0), Phase 2 = 2 dirs (-1, +1), Phase 3+ = 3 dirs (-2, 0, +2)
    // Triple Shot Buff upgrades spread to 3-way (Phase 1) or 5-way Fan (Phase 2+)!
    task fire_phase_shot;
        input [9:0] cy;
        begin
            if (!triple_on) begin
                if (cycle_num == 4'd0) begin
                    fire_player_bullet(cy, 4'sd0);
                end else if (cycle_num == 4'd1) begin
                    fire_player_bullet(cy - 10'd6, -4'sd1);
                    fire_player_bullet(cy + 10'd6,  4'sd1);
                end else begin
                    fire_player_bullet(cy - 10'd8, -4'sd2);
                    fire_player_bullet(cy,          4'sd0);
                    fire_player_bullet(cy + 10'd8,  4'sd2);
                end
            end else begin
                if (cycle_num == 4'd0) begin
                    fire_player_bullet(cy - 10'd6, -4'sd2);
                    fire_player_bullet(cy,          4'sd0);
                    fire_player_bullet(cy + 10'd6,  4'sd2);
                end else if (cycle_num == 4'd1) begin
                    fire_player_bullet(cy - 10'd12, -4'sd3);
                    fire_player_bullet(cy - 10'd6,  -4'sd1);
                    fire_player_bullet(cy,           4'sd0);
                    fire_player_bullet(cy + 10'd6,   4'sd1);
                    fire_player_bullet(cy + 10'd12,  4'sd3);
                end else begin
                    fire_player_bullet(cy - 10'd12, -4'sd4);
                    fire_player_bullet(cy - 10'd6,  -4'sd2);
                    fire_player_bullet(cy,           4'sd0);
                    fire_player_bullet(cy + 10'd6,   4'sd2);
                    fire_player_bullet(cy + 10'd12,  4'sd4);
                end
            end
        end
    endtask

    task fire_enemy_bullet;
        input [9:0] ex;
        input [9:0] ey;
        input signed [3:0] evy;
        integer idx;
        reg done;
        begin
            done = 1'b0;
            for (idx = 0; idx < 12; idx = idx + 1) begin
                if (!done && !eb_act[idx]) begin
                    eb_act[idx] = 1'b1;
                    eb_x[idx]   = ex;
                    eb_y[idx]   = ey;
                    eb_vy[idx]  = evy;
                    done        = 1'b1;
                end
            end
        end
    endtask

    reg signed [9:0]  next_vel;
    reg signed [14:0] next_y_fp;
    reg [9:0]         idle_offset;
    reg               player_got_hit;
    reg signed [3:0]  aim_vy;
    reg [5:0]         next_flapzy;
    reg               letter_just_spawned;
    integer           i, j;

    always @(posedge clk) begin
        if (rst) begin
            state              <= ST_HOME;
            active_mode        <= 1'b0;
            bird_x             <= 10'd110;
            bird_y_fp          <= 15'sd260 <<< 4;
            vel_y              <= 10'sd0;
            px[0] <= 12'sd620; px[1] <= 12'sd900; px[2] <= 12'sd1180;
            pgap[0] <= 10'd220; pgap[1] <= 10'd170; pgap[2] <= 10'd260;
            pscored[0] <= 1'b0; pscored[1] <= 1'b0; pscored[2] <= 1'b0;
            ground_scroll      <= 10'd0;
            cloud_scroll       <= 10'd0;
            score              <= 14'd0;
            high_score         <= 14'd0;
            player_hp          <= 3'd5;
            invuln_cnt         <= 9'd0;
            shield_on          <= 1'b0;
            triple_timer       <= 9'd0;
            rapid_timer        <= 9'd0;
            rapid_cd           <= 4'd0;
            hazard_timer       <= 10'd0;
            floor_warn         <= 1'b0;
            floor_hazard       <= 1'b0;
            wave_in_cycle      <= 2'd0;
            cycle_num          <= 4'd0;
            en_act             <= 8'd0;
            pb_act             <= 16'd0;
            eb_act             <= 12'd0;
            boss_active        <= 1'b0;
            boss_x             <= 10'd620;
            boss_y             <= 10'd200;
            boss_hp            <= 10'd30;
            boss_max_hp        <= 10'd30;
            boss_dir           <= 1'b0;
            boss_pat           <= 3'd0;
            boss_hit_cnt       <= 5'd0;
            boss_victory_cnt   <= 9'd0;
            boss_knocked_down  <= 1'b0;
            phase_banner_cnt   <= 8'd0;
            boss_warning_cnt   <= 8'd0;
            boss_buff_cd       <= 8'd90;
            enemy_fire_cd      <= 7'd35;
            boss_fire_cd       <= 7'd65;
            buff_act           <= 1'b0;
            buff_x             <= 10'd0;
            buff_y             <= 10'd0;
            buff_type          <= 2'd0;
            flapzy_mask        <= 6'd0;
            letter_act         <= 1'b0;
            letter_x           <= 10'd0;
            letter_y           <= 10'd0;
            letter_idx         <= 3'd0;
            letter_cd          <= 9'd60;
            bonus_pending      <= 1'b0;
            bonus_intro_cnt    <= 8'd0;
            bonus_timer        <= 10'd0;
            star_act           <= 10'd0;
            lfsr               <= 16'hACE1;
            prev_voice         <= 1'b0;
            cheat_kill_d       <= 1'b0;
            cheat_frenzy_d     <= 1'b0;
            cheat_kill_latched <= 1'b0;
            cheat_frenzy_latched <= 1'b0;
            confirm_latched    <= 1'b0;
            fly_rise_latched   <= 1'b0;
            shoot_rise_latched <= 1'b0;
            anim_cnt           <= 6'd0;
            go_cooldown        <= 6'd0;
            flap_sfx_cd        <= 5'd0;
            sfx_flap           <= 1'b0;
            sfx_score          <= 1'b0;
            sfx_hit            <= 1'b0;
        end else begin
            sfx_flap  <= 1'b0;
            sfx_score <= 1'b0;
            sfx_hit   <= 1'b0;

            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};

            prev_voice     <= voice_active;
            cheat_kill_d   <= cheat_kill_sw;
            cheat_frenzy_d <= cheat_frenzy_sw;
            if (btn_confirm_rise)              confirm_latched      <= 1'b1;
            if (btn_fly_rise || voice_rise)    fly_rise_latched     <= 1'b1;
            if (btn_shoot_rise)                shoot_rise_latched   <= 1'b1;
            if (cheat_kill_sw && !cheat_kill_d)     cheat_kill_latched   <= 1'b1;
            if (cheat_frenzy_sw && !cheat_frenzy_d) cheat_frenzy_latched <= 1'b1;

            if (frame_tick) begin
                anim_cnt <= anim_cnt + 6'd1;
                if (flap_sfx_cd != 5'd0) flap_sfx_cd <= flap_sfx_cd - 5'd1;

                case (state)
                    ST_HOME: begin
                        bird_x <= 10'd110;
                        idle_offset = anim_cnt[5] ? (10'd16 - {4'd0, anim_cnt[4:1]}) : ({4'd0, anim_cnt[4:1]});
                        bird_y_fp   <= $signed({1'b0, (10'd240 + idle_offset), 4'b0000});
                        if (confirm_latched) begin
                            state     <= ST_MODE;
                            sfx_score <= 1'b1;
                        end
                    end

                    ST_MODE: begin
                        active_mode <= mode_sw;
                        if (confirm_latched) begin
                            state     <= ST_TUTORIAL;
                            sfx_score <= 1'b1;
                        end
                    end

                    ST_TUTORIAL: begin
                        if (confirm_latched) begin
                            state            <= ST_PLAY;
                            score            <= 14'd0;
                            bird_x           <= 10'd110;
                            bird_y_fp        <= 15'sd260 <<< 4;
                            vel_y            <= -10'sd40;
                            sfx_flap         <= 1'b1;
                            px[0] <= 12'sd620; px[1] <= 12'sd900; px[2] <= 12'sd1180;
                            pgap[0] <= next_gap_y; pgap[1] <= 10'd180; pgap[2] <= 10'd250;
                            pscored[0] <= 1'b0; pscored[1] <= 1'b0; pscored[2] <= 1'b0;
                            player_hp        <= 3'd5;
                            invuln_cnt       <= 9'd0;
                            shield_on        <= 1'b0;
                            triple_timer     <= 9'd0;
                            rapid_timer      <= 9'd0;
                            rapid_cd         <= 4'd0;
                            hazard_timer     <= 10'd0;
                            floor_warn       <= 1'b0;
                            floor_hazard     <= 1'b0;
                            wave_in_cycle    <= 2'd0;
                            cycle_num        <= 4'd0;
                            boss_active        <= 1'b0;
                            pb_act             <= 16'd0;
                            eb_act             <= 12'd0;
                            buff_act           <= 1'b0;
                            boss_pat           <= 3'd0;
                            boss_hit_cnt       <= 5'd0;
                            boss_victory_cnt   <= 9'd0;
                            boss_knocked_down  <= 1'b0;
                            phase_banner_cnt   <= 8'd0;
                            boss_warning_cnt   <= 8'd0;
                            boss_buff_cd       <= 8'd90;
                            flapzy_mask        <= 6'd0;
                            letter_act         <= 1'b0;
                            letter_cd          <= 9'd60;
                            bonus_pending      <= 1'b0;
                            bonus_intro_cnt    <= 8'd0;
                            bonus_timer        <= 10'd0;
                            star_act           <= 10'd0;
                            if (active_mode) spawn_wave(4'd0, 2'd0);
                            else             en_act <= 8'd0;
                        end
                    end

                    ST_PLAY: begin
                        if (pause_sw) begin
                            state <= ST_PAUSE;
                        end else begin
                            ground_scroll <= (ground_scroll + cfg_speed[9:0] >= 10'd32) ?
                                             (ground_scroll + cfg_speed[9:0] - 10'd32) :
                                             (ground_scroll + cfg_speed[9:0]);
                            if (anim_cnt[1:0] == 2'b00)
                                cloud_scroll <= (cloud_scroll + 10'd1 >= 10'd800) ? 10'd0 : (cloud_scroll + 10'd1);

                            // =================================================
                            // BOSS VICTORY KNOCKDOWN ANIMATION (6.5s: 390 frames)
                            // =================================================
                            if (boss_victory) begin
                                boss_victory_cnt <= boss_victory_cnt - 9'd1;
                                if (boss_hit_cnt != 5'd0) boss_hit_cnt <= boss_hit_cnt - 5'd1;

                                // Stage 1 (390->285): Bird dashes forward & attacks Boss in current Phase skin!
                                if (boss_victory_cnt > 9'd285) begin
                                    if (bird_x + 10'd6 < (boss_x - 10'd20))
                                        bird_x <= bird_x + 10'd8;
                                    else begin
                                        bird_x            <= boss_x - 10'd20;
                                        boss_hit_cnt      <= 5'd12;
                                        boss_knocked_down <= 1'b1;
                                        sfx_hit           <= 1'b1;
                                    end
                                    if (bird_y + 10'd4 < (boss_y + 10'd32))      bird_y_fp <= bird_y_fp + 15'sd64;
                                    else if (bird_y > (boss_y + 10'd36))         bird_y_fp <= bird_y_fp - 15'sd64;
                                end else begin
                                    // Stage 2 (284->1): Boss topples sideways & falls onto floor, Bird steps back cleanly!
                                    boss_knocked_down <= 1'b1;
                                    if (boss_y < (GROUND_Y - 10'd120)) boss_y <= boss_y + 10'd5;
                                    if (bird_x > 10'd200)              bird_x <= bird_x - 10'd6;
                                    if (bird_y > 10'd264)              bird_y_fp <= bird_y_fp - 15'sd48;
                                    else if (bird_y < 10'd256)         bird_y_fp <= bird_y_fp + 15'sd48;
                                end

                                if (boss_victory_cnt == 9'd1) begin
                                    boss_active       <= 1'b0;
                                    boss_knocked_down <= 1'b0;
                                    bird_x            <= 10'd110;
                                    bird_y_fp         <= 15'sd260 <<< 4;
                                    cycle_num         <= cycle_num + 4'd1;
                                    wave_in_cycle     <= 2'd0;
                                    phase_banner_cnt  <= 8'd120;
                                    spawn_wave(cycle_num + 4'd1, 2'd0);
                                    if (bonus_pending) start_frenzy_intro();
                                end
                            end
                            // =================================================
                            // FRENZY INTRO ANIMATION (4s: "FRENZY TIME!" + Bird Aura Ascent)
                            // =================================================
                            else if (bonus_intro) begin
                                bonus_intro_cnt <= bonus_intro_cnt - 8'd1;
                                if (bird_x < 10'd364)      bird_x <= bird_x + 10'd4;
                                else if (bird_x > 10'd372) bird_x <= bird_x - 10'd4;
                                else                       bird_x <= 10'd368;

                                if (bonus_intro_cnt > 8'd90) begin
                                    if (bird_y > 10'd264)      bird_y_fp <= bird_y_fp - 15'sd48;
                                    else if (bird_y < 10'd256) bird_y_fp <= bird_y_fp + 15'sd48;
                                end else begin
                                    if (bird_y > 10'd86)       bird_y_fp <= bird_y_fp - 15'sd64;
                                end

                                if (bonus_intro_cnt == 8'd1) begin
                                    bonus_timer <= 10'd600; // 10 seconds sky bonus
                                    bird_x      <= 10'd368; // Centered on map
                                    bird_y_fp   <= 15'sd260 <<< 4;
                                    for (i = 0; i < 10; i = i + 1) begin
                                        star_act[i]    <= 1'b1;
                                        star_x[i]      <= 10'd740 + (i * 10'd76);
                                        star_base_y[i] <= pattern_flower_y(i[3:0], 2'd3, lfsr[6:0]);
                                        star_y[i]      <= pattern_flower_y(i[3:0], 2'd3, lfsr[6:0]);
                                    end
                                end
                            end
                            // =================================================
                            // FRENZY TIME (Light Sky #b8edff + Sun + 10 Multi-Pattern Flowers + Calibrated Gyro/ACL)
                            // =================================================
                            else if (bonus_active) begin
                                bonus_timer <= bonus_timer - 10'd1;
                                if (bonus_timer == 10'd1) begin
                                    flapzy_mask <= 6'd0;
                                    star_act    <= 10'd0;
                                    bird_x      <= 10'd110;
                                end

                                // Full-map 2D movement from calibrated Accelerometer (VGA at TOP: swapped X/Y)
                                if (tilt_x > 8'sd6) begin
                                    if (bird_x < 10'd720)
                                        bird_x <= bird_x + ((tilt_x > 8'sd24) ? 10'd6 : 10'd3);
                                end else if (tilt_x < -8'sd6) begin
                                    if (bird_x > 10'd16)
                                        bird_x <= bird_x - ((tilt_x < -8'sd24) ? 10'd6 : 10'd3);
                                end

                                if (tilt_y < -8'sd6) begin
                                    if (bird_y > (TOP_Y + 4))
                                        bird_y_fp <= bird_y_fp - ((tilt_y < -8'sd24) ? 15'sd96 : 15'sd48);
                                end else if (tilt_y > 8'sd6) begin
                                    if (bird_y < (GROUND_Y - 68))
                                        bird_y_fp <= bird_y_fp + ((tilt_y > 8'sd24) ? 15'sd96 : 15'sd48);
                                end

                                // Move 10 Multi-Pattern Bonus Flowers & Collect
                                for (i = 0; i < 10; i = i + 1) begin
                                    if (star_act[i]) begin
                                        if (star_x[i] <= 10'd8) begin
                                            star_x[i]      <= 10'd790;
                                            star_base_y[i] <= pattern_flower_y(i[3:0], bonus_timer[7:6], (lfsr[6:0] ^ {i[3:0], 3'd2}));
                                        end else begin
                                            star_x[i] <= star_x[i] - 10'd4;
                                            star_y[i] <= $signed({1'b0, star_base_y[i]}) + wave_sin(star_x[i][6:3] + anim_cnt[5:2] + i[3:0]);
                                            if (((star_x[i] + 10'd24) >= hit_x_l) && (star_x[i] < hit_x_r) &&
                                                ((star_y[i] + 10'd24) >= hit_y_t) && (star_y[i] < hit_y_b)) begin
                                                score     <= score + 14'd15;
                                                if ((score + 14'd15) > high_score) high_score <= score + 14'd15;
                                                sfx_score <= 1'b1;
                                                star_x[i]      <= 10'd790;
                                                star_base_y[i] <= pattern_flower_y(i[3:0], bonus_timer[7:6], (lfsr[6:0] ^ {i[3:0], 3'd5}));
                                            end
                                        end
                                    end
                                end
                            end
                            // =================================================
                            // NORMAL GAMEPLAY (Classic or Attack)
                            // =================================================
                            else begin
                                if (bird_x > 10'd110) bird_x <= bird_x - 10'd4;
                                else                  bird_x <= 10'd110;

                                if (mode_edge) begin
                                    if (fly_rise_latched) begin
                                        next_vel = -10'sd76;
                                        sfx_flap <= 1'b1;
                                    end else begin
                                        next_vel = vel_y + 10'sd3;
                                    end
                                end else begin
                                    if (ctrl_hold) begin
                                        next_vel = vel_y - 10'sd5;
                                        if (flap_sfx_cd == 5'd0) begin
                                            sfx_flap    <= 1'b1;
                                            flap_sfx_cd <= 5'd10;
                                        end
                                    end else begin
                                        next_vel = vel_y + 10'sd3;
                                    end
                                end
                                if (next_vel < -10'sd64) next_vel = -10'sd64;
                                if (next_vel >  10'sd84) next_vel =  10'sd84;
                                vel_y <= next_vel;

                                next_y_fp = bird_y_fp + {{5{next_vel[9]}}, next_vel};
                                if (next_y_fp < $signed({1'b0, (10'd76), 4'b0000})) begin
                                    bird_y_fp <= $signed({1'b0, (10'd76), 4'b0000});
                                    vel_y     <= 10'sd0;
                                end else if (active_mode && (next_y_fp > 15'sd7904)) begin // (552-58)<<4
                                    bird_y_fp <= 15'sd7904;
                                    vel_y     <= 10'sd0;
                                end else begin
                                    bird_y_fp <= next_y_fp;
                                end

                                // MODE 0: CLASSIC
                                if (!active_mode) begin
                                    for (k = 0; k < 3; k = k + 1) begin
                                        if (px[k] < -12'sd70) begin
                                            px[k]      <= px[k] + (PIPE_SPACING * 3) - cfg_speed;
                                            pgap[k]    <= next_gap_y;
                                            pscored[k] <= 1'b0;
                                        end else begin
                                            px[k] <= px[k] - cfg_speed;
                                            if (!pscored[k] && ((px[k] + (PIPE_W / 2)) < $signed({1'b0, bird_x}))) begin
                                                pscored[k] <= 1'b1;
                                                score      <= score + 14'd1;
                                                if ((score + 14'd1) > high_score) high_score <= score + 14'd1;
                                                sfx_score  <= 1'b1;
                                            end
                                        end
                                    end
                                    if (hit_pipe || hit_ground) begin
                                        state       <= ST_GAMEOVER;
                                        go_cooldown <= 6'd35;
                                        sfx_hit     <= 1'b1;
                                    end
                                end
                                // MODE 1: FLAPPY ATTACK
                                else begin
                                    if (invuln_cnt       != 9'd0) invuln_cnt       <= invuln_cnt - 9'd1;
                                    if (triple_timer     != 9'd0) triple_timer     <= triple_timer - 9'd1;
                                    if (rapid_timer      != 9'd0) rapid_timer      <= rapid_timer - 9'd1;
                                    if (rapid_cd         != 4'd0) rapid_cd         <= rapid_cd - 4'd1;
                                    if (boss_hit_cnt     != 5'd0) boss_hit_cnt     <= boss_hit_cnt - 5'd1;
                                    if (phase_banner_cnt != 8'd0) phase_banner_cnt <= phase_banner_cnt - 8'd1;

                                    // Floor Hazard removed (keep outputs low)
                                    floor_warn          <= 1'b0;
                                    floor_hazard        <= 1'b0;
                                    letter_just_spawned  = 1'b0;

                                    // Cheat Switches (SW13 = Auto FRENZY TIME, SW14 = Kill All Enemies & Boss)
                                    if (cheat_frenzy_latched) begin
                                        flapzy_mask <= 6'b111111;
                                        start_frenzy_intro();
                                    end else if (cheat_kill_latched) begin
                                        eb_act <= 12'd0;
                                        if (en_act != 8'd0) begin
                                            en_act    <= 8'd0;
                                            score     <= score + 14'd20;
                                            if ((score + 14'd20) > high_score) high_score <= score + 14'd20;
                                            sfx_score <= 1'b1;
                                        end
                                        if (boss_active) begin
                                            score             <= score + 14'd50;
                                            if ((score + 14'd50) > high_score) high_score <= score + 14'd50;
                                            sfx_score         <= 1'b1;
                                            boss_hp           <= 10'd0;
                                            pb_act            <= 16'd0;
                                            buff_act          <= 1'b0;
                                            letter_act        <= 1'b0;
                                            boss_knocked_down <= 1'b0;
                                            boss_victory_cnt  <= 9'd390; // 6.5s Boss Victory Knockdown!
                                        end
                                    end

                                    // 1. Player Shooting (Phase 1=1 dir, Phase 2=2 dir, Phase 3+=3 dir; Triple Buff=3/5-way Fan)
                                    if (shoot_rise_latched || (rapid_on && btn_shoot && rapid_cd == 4'd0)) begin
                                        rapid_cd <= rapid_on ? 4'd5 : 4'd9;
                                        fire_phase_shot(bird_y + 10'd26);
                                        sfx_flap <= 1'b1;
                                    end

                                    // 2. Move Player Bullets (16 slots, 14x14 round)
                                    for (i = 0; i < 16; i = i + 1) begin
                                        if (pb_act[i]) begin
                                            if (pb_x[i] >= 10'd784 || pb_y[i] < 10'd76 || pb_y[i] >= 10'd538) begin
                                                pb_act[i] <= 1'b0;
                                            end else begin
                                                pb_x[i] <= pb_x[i] + 10'd9;
                                                pb_y[i] <= $signed({1'b0, pb_y[i]}) + {{7{pb_vy[i][3]}}, pb_vy[i]};

                                                for (j = 0; j < 8; j = j + 1) begin
                                                    if (en_act[j] && pb_act[i] &&
                                                        ($signed({1'b0, pb_x[i] + 10'd14}) >= en_x[j]) &&
                                                        ($signed({1'b0, pb_x[i]}) < (en_x[j] + 12'sd48)) &&
                                                        ((pb_y[i] + 10'd14) >= en_y[j]) && (pb_y[i] < (en_y[j] + 10'd30))) begin
                                                        pb_act[i] <= 1'b0;
                                                        if (en_hp[j] <= 3'd1) begin
                                                            en_act[j] <= 1'b0;
                                                            score     <= score + 14'd5;
                                                            if ((score + 14'd5) > high_score) high_score <= score + 14'd5;
                                                            sfx_score <= 1'b1;
                                                            if (!buff_act && (lfsr[5:0] < 6'd29)) begin // ~45% Wave Buff drop
                                                                buff_act  <= 1'b1;
                                                                buff_x    <= (en_x[j] > 12'sd740) ? 10'd740 : en_x[j][9:0];
                                                                buff_y    <= en_y[j];
                                                                buff_type <= (lfsr[5:0] < 6'd9)  ? 2'd0 :
                                                                             (lfsr[5:0] < 6'd18) ? 2'd1 :
                                                                             (lfsr[5:0] < 6'd27) ? 2'd2 : 2'd3;
                                                            end
                                                            if (!letter_act && !letter_just_spawned && !boss_active && (boss_warning_cnt == 8'd0) &&
                                                                (flapzy_mask != 6'b111111) && (lfsr[11:6] < 6'd19)) begin // ~30% Wave FRENZY drop
                                                                letter_act          <= 1'b1;
                                                                letter_just_spawned  = 1'b1;
                                                                letter_x   <= (en_x[j] > 12'sd740) ? 10'd740 : en_x[j][9:0];
                                                                letter_y   <= en_y[j];
                                                                letter_cd  <= 9'd120;
                                                                if      (!flapzy_mask[0]) letter_idx <= 3'd0;
                                                                else if (!flapzy_mask[1]) letter_idx <= 3'd1;
                                                                else if (!flapzy_mask[2]) letter_idx <= 3'd2;
                                                                else if (!flapzy_mask[3]) letter_idx <= 3'd3;
                                                                else if (!flapzy_mask[4]) letter_idx <= 3'd4;
                                                                else                      letter_idx <= 3'd5;
                                                            end
                                                        end else begin
                                                            en_hp[j] <= en_hp[j] - 3'd1;
                                                        end
                                                    end
                                                end

                                                if (boss_active && pb_act[i] &&
                                                    ((pb_x[i] + 10'd14) >= boss_x) && (pb_x[i] < (boss_x + 10'd144)) &&
                                                    ((pb_y[i] + 10'd14) >= boss_y) && (pb_y[i] < (boss_y + 10'd144))) begin
                                                    pb_act[i]    <= 1'b0;
                                                    boss_hit_cnt <= 5'd8; // Blink on hit!
                                                    if (boss_hp <= 10'd1) begin
                                                        score             <= score + 14'd50;
                                                        if ((score + 14'd50) > high_score) high_score <= score + 14'd50;
                                                        sfx_score         <= 1'b1;
                                                        boss_hp           <= 10'd0;
                                                        pb_act            <= 16'd0;
                                                        eb_act            <= 12'd0;
                                                        buff_act          <= 1'b0;
                                                        letter_act        <= 1'b0;
                                                        boss_knocked_down <= 1'b0;
                                                        boss_victory_cnt  <= 9'd390; // 6.5s Boss Victory Knockdown!
                                                    end else begin
                                                        boss_hp <= boss_hp - 10'd1;
                                                        score   <= score + 14'd2;
                                                        if ((score + 14'd2) > high_score) high_score <= score + 14'd2;
                                                    end
                                                end
                                            end
                                        end
                                    end

                                    // 3. Wave Rockets & 4s Boss Warning (Fire rate & dodge speed scale per Phase)
                                    if (!boss_active) begin
                                        if (boss_warning_cnt != 8'd0) begin
                                            boss_warning_cnt <= boss_warning_cnt - 8'd1;
                                            if (boss_warning_cnt == 8'd1) begin
                                                boss_active  <= 1'b1;
                                                boss_x       <= 10'd624;
                                                boss_y       <= 10'd200;
                                                boss_max_hp  <= ({6'd0, cycle_num} + 10'd1) * 10'd30;
                                                boss_hp      <= ({6'd0, cycle_num} + 10'd1) * 10'd30;
                                                boss_pat     <= 3'd0;
                                                boss_fire_cd <= 7'd55;
                                                boss_buff_cd <= 8'd20;
                                            end
                                        end else if (en_act == 8'd0 && !cheat_kill_latched) begin
                                            if (wave_in_cycle == 2'd2) begin
                                                boss_warning_cnt <= 8'd240; // 4-second red flashing WARNING!
                                            end else begin
                                                wave_in_cycle <= wave_in_cycle + 2'd1;
                                                spawn_wave(cycle_num, wave_in_cycle + 2'd1);
                                            end
                                        end else begin
                                            for (j = 0; j < 8; j = j + 1) begin
                                                if (en_act[j]) begin
                                                    if (en_x[j] > (12'sd670 + (j[0] * 12'sd42)))
                                                        en_x[j] <= en_x[j] - 12'sd3;
                                                    // Active dodge direction flip in Phase 2+ when shot at
                                                    if (cycle_num >= 4'd1 && shoot_rise_latched && (lfsr[2:0] == j[2:0]))
                                                        en_dir[j] <= ~en_dir[j];
                                                    else if (en_dir[j]) begin
                                                        if (en_y[j] <= 10'd88) en_dir[j] <= 1'b0;
                                                        else en_y[j] <= en_y[j] - ((cycle_num == 0) ? 10'd2 : (cycle_num == 1) ? 10'd3 : (cycle_num == 2) ? 10'd4 : 10'd5);
                                                    end else begin
                                                        if (en_y[j] >= 10'd490) en_dir[j] <= 1'b1;
                                                        else en_y[j] <= en_y[j] + ((cycle_num == 0) ? 10'd2 : (cycle_num == 1) ? 10'd3 : (cycle_num == 2) ? 10'd4 : 10'd5);
                                                    end
                                                end
                                            end

                                            if (enemy_fire_cd == 7'd0) begin
                                                enemy_fire_cd <= (cycle_num == 4'd0) ? 7'd64 :
                                                                 (cycle_num == 4'd1) ? 7'd48 :
                                                                 (cycle_num == 4'd2) ? 7'd34 : 7'd24;
                                                if (en_act[lfsr[2:0]]) begin
                                                    aim_vy = (en_y[lfsr[2:0]] < bird_y + 10'd20) ? 4'sd1 :
                                                             (en_y[lfsr[2:0]] > bird_y + 10'd44) ? -4'sd1 : 4'sd0;
                                                    fire_enemy_bullet(en_x[lfsr[2:0]][9:0], en_y[lfsr[2:0]] + 10'd10, aim_vy);
                                                end else if (en_act[0]) begin
                                                    aim_vy = (en_y[0] < bird_y + 10'd20) ? 4'sd1 : 4'sd0;
                                                    fire_enemy_bullet(en_x[0][9:0], en_y[0] + 10'd10, aim_vy);
                                                end
                                            end else begin
                                                enemy_fire_cd <= enemy_fire_cd - 7'd1;
                                            end
                                        end
                                    end
                                    // 4. Boss Patrol, Easier Early Phases & 55% 3-Color Buff Drop
                                    else begin
                                        if (boss_dir) begin
                                            if (boss_y <= 10'd84) boss_dir <= 1'b0;
                                            else                  boss_y   <= boss_y - ((cycle_num == 0) ? 10'd1 : (cycle_num == 1) ? 10'd2 : 10'd3);
                                        end else begin
                                            if (boss_y >= 10'd390) boss_dir <= 1'b1;
                                            else                   boss_y   <= boss_y + ((cycle_num == 0) ? 10'd1 : (cycle_num == 1) ? 10'd2 : 10'd3);
                                        end

                                        // Boss Buff Drop (~65% chance every ~2s for 3 colored buffs)
                                        if (boss_buff_cd == 8'd0) begin
                                            boss_buff_cd <= 8'd120;
                                            if (!buff_act && (lfsr[5:0] < 6'd42)) begin // 42/64 = 65.6%
                                                buff_act  <= 1'b1;
                                                buff_x    <= 10'd740;
                                                buff_y    <= 10'd120 + {2'b00, lfsr[7:0]};
                                                buff_type <= (lfsr[11:10] == 2'd3) ? 2'd0 : lfsr[11:10];
                                            end
                                        end else begin
                                            boss_buff_cd <= boss_buff_cd - 8'd1;
                                        end

                                        if (boss_fire_cd == 7'd0) begin
                                            boss_pat <= boss_pat + 3'd1;
                                            if (cycle_num == 4'd0) begin
                                                boss_fire_cd <= 7'd65; // Phase 1: Easy & slow
                                                if (boss_pat[0] == 1'b0) begin
                                                    aim_vy = (boss_y + 10'd70 < bird_y + 10'd32) ? 4'sd1 :
                                                             (boss_y + 10'd70 > bird_y + 10'd32) ? -4'sd1 : 4'sd0;
                                                    fire_enemy_bullet(boss_x, boss_y + 10'd70, aim_vy);
                                                end else begin
                                                    fire_enemy_bullet(boss_x, boss_y + 10'd48, -4'sd1);
                                                    fire_enemy_bullet(boss_x, boss_y + 10'd92,  4'sd1);
                                                end
                                            end else if (cycle_num == 4'd1) begin
                                                boss_fire_cd <= 7'd48; // Phase 2: Moderate
                                                if (boss_pat[0] == 1'b0) begin
                                                    fire_enemy_bullet(boss_x, boss_y + 10'd44, -4'sd1);
                                                    fire_enemy_bullet(boss_x, boss_y + 10'd70,  4'sd0);
                                                    fire_enemy_bullet(boss_x, boss_y + 10'd96,  4'sd1);
                                                end else begin
                                                    aim_vy = (boss_y + 10'd70 < bird_y + 10'd32) ? 4'sd2 : -4'sd2;
                                                    fire_enemy_bullet(boss_x, boss_y + 10'd56, aim_vy);
                                                    fire_enemy_bullet(boss_x, boss_y + 10'd84, aim_vy);
                                                end
                                            end else begin
                                                boss_fire_cd <= 7'd28; // Phase 3+: Intense
                                                if (boss_pat[0] == 1'b0) begin
                                                    fire_enemy_bullet(boss_x, boss_y + 10'd30, -4'sd2);
                                                    fire_enemy_bullet(boss_x, boss_y + 10'd50, -4'sd1);
                                                    fire_enemy_bullet(boss_x, boss_y + 10'd70,  4'sd0);
                                                    fire_enemy_bullet(boss_x, boss_y + 10'd90,  4'sd1);
                                                    fire_enemy_bullet(boss_x, boss_y + 10'd110, 4'sd2);
                                                end else begin
                                                    aim_vy = (boss_y + 10'd70 < bird_y + 10'd32) ? 4'sd2 : -4'sd2;
                                                    fire_enemy_bullet(boss_x, boss_y + 10'd40, aim_vy);
                                                    fire_enemy_bullet(boss_x, boss_y + 10'd70, 4'sd0);
                                                    fire_enemy_bullet(boss_x, boss_y + 10'd100, aim_vy);
                                                end
                                            end
                                        end else begin
                                            boss_fire_cd <= boss_fire_cd - 7'd1;
                                        end
                                    end

                                    // 5. Enemy Bullets (16x16 round, 2 px/frame in Phase 1 Boss, else 3)
                                    player_got_hit = 1'b0;
                                    for (i = 0; i < 12; i = i + 1) begin
                                        if (eb_act[i]) begin
                                            if (eb_x[i] <= 10'd8 || eb_y[i] < 10'd76 || eb_y[i] >= 10'd536) begin
                                                eb_act[i] <= 1'b0;
                                            end else begin
                                                eb_x[i] <= eb_x[i] - ((boss_active && cycle_num == 4'd0) ? 10'd2 : 10'd3);
                                                eb_y[i] <= $signed({1'b0, eb_y[i]}) + {{7{eb_vy[i][3]}}, eb_vy[i]};
                                                if (((eb_x[i] + 10'd16) >= hit_x_l) && (eb_x[i] < hit_x_r) &&
                                                    ((eb_y[i] + 10'd16) >= hit_y_t) && (eb_y[i] < hit_y_b)) begin
                                                    eb_act[i]      <= 1'b0;
                                                    player_got_hit  = 1'b1;
                                                end
                                            end
                                        end
                                    end

                                    if (player_got_hit && (invuln_cnt == 9'd0)) begin
                                        if (shield_on) begin
                                            shield_on  <= 1'b0;
                                            invuln_cnt <= 9'd300;
                                            sfx_flap   <= 1'b1;
                                        end else if (player_hp <= 3'd1) begin
                                            player_hp   <= 3'd0;
                                            state       <= ST_GAMEOVER;
                                            go_cooldown <= 6'd35;
                                            sfx_hit     <= 1'b1;
                                        end else begin
                                            player_hp  <= player_hp - 3'd1;
                                            invuln_cnt <= 9'd300;
                                            sfx_hit    <= 1'b1;
                                        end
                                    end

                                    // 6. Buff Pickup (Slower speed = 1 px/frame for easy pickup)
                                    if (buff_act) begin
                                        if (buff_x <= 10'd8) begin
                                            buff_act <= 1'b0;
                                        end else begin
                                            buff_x <= buff_x - 10'd1;
                                            if (((buff_x + 10'd32) >= hit_x_l) && (buff_x < hit_x_r) &&
                                                ((buff_y + 10'd32) >= hit_y_t) && (buff_y < hit_y_b)) begin
                                                buff_act  <= 1'b0;
                                                sfx_score <= 1'b1;
                                                if (buff_type == 2'd0)      triple_timer <= 9'd480;
                                                else if (buff_type == 2'd1) rapid_timer  <= 9'd480;
                                                else if (buff_type == 2'd2) shield_on    <= 1'b1;
                                                else if (player_hp < 3'd5)  player_hp    <= player_hp + 3'd1;
                                            end
                                        end
                                    end

                                    // 7. FRENZY (FLAPZY) Letter Drop (30% during Wave, 0% during Boss, smooth left glide)
                                    if (!letter_act && !letter_just_spawned) begin
                                        if (letter_cd != 9'd0) begin
                                            letter_cd <= letter_cd - 9'd1;
                                        end else if (!boss_active && (boss_warning_cnt == 8'd0) && (flapzy_mask != 6'b111111)) begin
                                            letter_cd <= 9'd90; // Periodic check every 1.5s if enemy kill didn't drop one
                                            if (lfsr[5:0] < 6'd19) begin // 19/64 = 29.7%
                                                letter_act <= 1'b1;
                                                letter_x   <= 10'd740;
                                                letter_y   <= 10'd120 + {2'b00, lfsr[7:0]};
                                                letter_cd  <= 9'd150;
                                                if      (!flapzy_mask[0]) letter_idx <= 3'd0;
                                                else if (!flapzy_mask[1]) letter_idx <= 3'd1;
                                                else if (!flapzy_mask[2]) letter_idx <= 3'd2;
                                                else if (!flapzy_mask[3]) letter_idx <= 3'd3;
                                                else if (!flapzy_mask[4]) letter_idx <= 3'd4;
                                                else                      letter_idx <= 3'd5;
                                            end
                                        end
                                    end else begin
                                        if (letter_x <= 10'd8) begin
                                            letter_act <= 1'b0;
                                        end else begin
                                            letter_x <= letter_x - 10'd2; // Smooth steady left glide
                                            if (((letter_x + 10'd24) >= hit_x_l) && (letter_x < hit_x_r) &&
                                                ((letter_y + 10'd24) >= hit_y_t) && (letter_y < hit_y_b)) begin
                                                letter_act  <= 1'b0;
                                                score       <= score + 14'd10;
                                                if ((score + 14'd10) > high_score) high_score <= score + 14'd10;
                                                sfx_score   <= 1'b1;
                                                next_flapzy = flapzy_mask | (6'b000001 << letter_idx);
                                                flapzy_mask <= next_flapzy;
                                                if (next_flapzy == 6'b111111) begin
                                                    if (boss_active) bonus_pending <= 1'b1;
                                                    else             start_frenzy_intro();
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end

                    ST_PAUSE: begin
                        if (!pause_sw) state <= ST_PLAY;
                    end

                    ST_GAMEOVER: begin
                        if (bird_y < (GROUND_Y - 58)) begin
                            next_vel  = (vel_y < 10'sd80) ? (vel_y + 10'sd4) : 10'sd80;
                            vel_y     <= next_vel;
                            next_y_fp = bird_y_fp + {{5{next_vel[9]}}, next_vel};
                            if (next_y_fp > 15'sd7904) bird_y_fp <= 15'sd7904;
                            else                       bird_y_fp <= next_y_fp;
                        end
                        if (go_cooldown != 6'd0) begin
                            go_cooldown <= go_cooldown - 6'd1;
                        end else if (confirm_latched) begin
                            state     <= ST_HOME;
                            bird_x    <= 10'd110;
                            bird_y_fp <= 15'sd260 <<< 4;
                            vel_y     <= 10'sd0;
                        end
                    end

                    default: state <= ST_HOME;
                endcase

                confirm_latched      <= 1'b0;
                fly_rise_latched     <= 1'b0;
                shoot_rise_latched   <= 1'b0;
                cheat_kill_latched   <= 1'b0;
                cheat_frenzy_latched <= 1'b0;
            end
        end
    end

endmodule
