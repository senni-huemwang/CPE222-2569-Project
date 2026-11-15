`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: game_engine
// Description: Flappy Pigeon physics, 3-pipe generator, collision detection,
//              score/high-score tracking, and audio event triggers.
//////////////////////////////////////////////////////////////////////////////////
module game_engine (
    input  wire        clk,
    input  wire        rst,
    input  wire        frame_tick,   // 60 Hz pulse from vga_sync
    // Controls
    input  wire        voice_active, // From pdm_mic
    input  wire        btn_flap,     // Debounced BTNC level
    input  wire        btn_flap_rise,// Debounced BTNC rising pulse
    input  wire        btn_pause_rise,// Debounced BTNU rising pulse
    input  wire        mode_edge,    // SW[4]: 0 = continuous hold-to-rise, 1 = edge flap
    input  wire [1:0]  diff_sw,      // SW[6:5]: 00=Easy, 01=Normal, 10/11=Hard
    // Game state & graphics outputs
    output reg  [1:0]  state,        // 0=IDLE, 1=PLAY, 2=PAUSE, 3=GAMEOVER
    output wire [9:0]  bird_y,
    output wire        bird_pose,    // 0=dive/wings-down, 1=flap/wings-up
    output wire signed [10:0] pipe0_x,
    output wire signed [10:0] pipe1_x,
    output wire signed [10:0] pipe2_x,
    output wire [9:0]  pipe0_gap_y,
    output wire [9:0]  pipe1_gap_y,
    output wire [9:0]  pipe2_gap_y,
    output wire [9:0]  pipe_gap_h,
    output reg  [9:0]  ground_scroll,
    output reg  [9:0]  cloud_scroll,
    output reg  [13:0] score,
    output reg  [13:0] high_score,
    // Audio SFX single-cycle triggers
    output reg         sfx_flap,
    output reg         sfx_score,
    output reg         sfx_hit
);
    localparam [1:0] ST_IDLE     = 2'd0,
                     ST_PLAY     = 2'd1,
                     ST_PAUSE    = 2'd2,
                     ST_GAMEOVER = 2'd3;

    localparam integer BIRD_X       = 120;
    localparam integer BIRD_SIZE    = 48;
    localparam integer GROUND_Y     = 440;
    localparam integer PIPE_W       = 56;
    localparam integer PIPE_SPACING = 240;

    // Forgiving hitbox inside 48x48 sprite
    localparam integer HIT_X_L = BIRD_X + 8;
    localparam integer HIT_X_R = BIRD_X + 40;

    // Difficulty parameters
    wire [9:0] cfg_gap_h = (diff_sw == 2'd0) ? 10'd156 :
                           (diff_sw == 2'd1) ? 10'd140 : 10'd124;
    wire signed [10:0] cfg_speed = (diff_sw == 2'd0) ? 11'sd2 :
                                   (diff_sw == 2'd1) ? 11'sd3 : 11'sd4;
    assign pipe_gap_h = cfg_gap_h;

    // Fixed-point bird Y (Q10.4 signed: integer Y = bird_y_fp[14:4])
    reg signed [14:0] bird_y_fp;
    reg signed [9:0]  vel_y;
    assign bird_y = bird_y_fp[14:4];

    // Pipes
    reg signed [10:0] px [0:2];
    reg        [9:0]  pgap [0:2];
    reg               pscored [0:2];

    assign pipe0_x     = px[0];
    assign pipe1_x     = px[1];
    assign pipe2_x     = px[2];
    assign pipe0_gap_y = pgap[0];
    assign pipe1_gap_y = pgap[1];
    assign pipe2_gap_y = pgap[2];

    // LFSR for pipe gap randomization (always free-running for entropy)
    reg [15:0] lfsr;
    wire [9:0] range_w = 10'd328 - cfg_gap_h; // 440 - 56 - 56 - gap_h
    wire [9:0] rand_raw = {2'b00, lfsr[7:0]};
    wire [9:0] rand_mod = (rand_raw >= range_w) ? (rand_raw - range_w) : rand_raw;
    wire [9:0] next_gap_y = 10'd56 + rand_mod;

    // Edge capture latches between 60 Hz frame ticks
    reg prev_voice;
    reg flap_rise_latched;
    reg pause_rise_latched;
    wire ctrl_hold = voice_active | btn_flap;
    wire voice_rise = voice_active & ~prev_voice;

    reg [5:0] anim_cnt;
    reg [5:0] go_cooldown; // ~0.6s lockout after Game Over before restart
    reg [4:0] flap_sfx_cd; // Rate-limit flap SFX during continuous hold

    // Bird pose: beat wings while rising/holding, dive pose while falling
    assign bird_pose = (state == ST_IDLE)     ? anim_cnt[4] :
                       (state == ST_GAMEOVER) ? 1'b0 :
                       (ctrl_hold || (vel_y < 10'sd0)) ? anim_cnt[3] : 1'b0;

    // Combinational collision check for current frame
    wire [9:0] hit_y_t = bird_y + 10'd8;
    wire [9:0] hit_y_b = bird_y + 10'd42;

    reg hit_pipe;
    integer k;
    always @(*) begin
        hit_pipe = 1'b0;
        for (k = 0; k < 3; k = k + 1) begin
            if ((px[k] < HIT_X_R) && ((px[k] + PIPE_W) > HIT_X_L)) begin
                if ((hit_y_t < pgap[k]) || (hit_y_b > (pgap[k] + cfg_gap_h))) begin
                    hit_pipe = 1'b1;
                end
            end
        end
    end

    wire hit_ground = (bird_y >= (GROUND_Y - 44));

    // Next-frame candidate values
    reg signed [9:0]  next_vel;
    reg signed [14:0] next_y_fp;
    reg [9:0]         idle_offset;

    always @(posedge clk) begin
        if (rst) begin
            state              <= ST_IDLE;
            bird_y_fp          <= 15'sd200 <<< 4;
            vel_y              <= 10'sd0;
            px[0]              <= 11'sd500;
            px[1]              <= 11'sd740;
            px[2]              <= 11'sd980;
            pgap[0]            <= 10'd150;
            pgap[1]            <= 10'd110;
            pgap[2]            <= 10'd185;
            pscored[0]         <= 1'b0;
            pscored[1]         <= 1'b0;
            pscored[2]         <= 1'b0;
            ground_scroll      <= 10'd0;
            cloud_scroll       <= 10'd0;
            score              <= 14'd0;
            high_score         <= 14'd0;
            lfsr               <= 16'hACE1;
            prev_voice         <= 1'b0;
            flap_rise_latched  <= 1'b0;
            pause_rise_latched <= 1'b0;
            anim_cnt           <= 6'd0;
            go_cooldown        <= 6'd0;
            flap_sfx_cd        <= 5'd0;
            sfx_flap           <= 1'b0;
            sfx_score          <= 1'b0;
            sfx_hit            <= 1'b0;
        end else begin
            // Clear 1-cycle SFX pulses
            sfx_flap  <= 1'b0;
            sfx_score <= 1'b0;
            sfx_hit   <= 1'b0;

            // Advance LFSR every 100 MHz clock for strong randomness
            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};

            // Latch rising edges between 60 Hz frame ticks
            prev_voice <= voice_active;
            if (btn_flap_rise || voice_rise) begin
                flap_rise_latched <= 1'b1;
            end
            if (btn_pause_rise) begin
                pause_rise_latched <= 1'b1;
            end

            if (frame_tick) begin
                anim_cnt <= anim_cnt + 6'd1;
                if (flap_sfx_cd != 5'd0) begin
                    flap_sfx_cd <= flap_sfx_cd - 5'd1;
                end

                case (state)
                    ST_IDLE: begin
                        // Gentle hover bobbing
                        idle_offset = anim_cnt[5] ? (10'd16 - {4'd0, anim_cnt[4:1]}) :
                                                    ({4'd0, anim_cnt[4:1]});
                        bird_y_fp <= $signed({1'b0, (10'd192 + idle_offset), 4'b0000});
                        vel_y     <= 10'sd0;
                        ground_scroll <= (ground_scroll + 10'd2 >= 10'd32) ?
                                         (ground_scroll + 10'd2 - 10'd32) : (ground_scroll + 10'd2);
                        if (anim_cnt[1:0] == 2'b00) begin
                            cloud_scroll <= (cloud_scroll + 10'd1 >= 10'd640) ? 10'd0 : (cloud_scroll + 10'd1);
                        end

                        if (flap_rise_latched) begin
                            state     <= ST_PLAY;
                            score     <= 14'd0;
                            vel_y     <= -10'sd56;
                            px[0]     <= 11'sd520;
                            px[1]     <= 11'sd760;
                            px[2]     <= 11'sd1000;
                            pgap[0]   <= next_gap_y;
                            pgap[1]   <= 10'd120;
                            pgap[2]   <= 10'd190;
                            pscored[0]<= 1'b0;
                            pscored[1]<= 1'b0;
                            pscored[2]<= 1'b0;
                            sfx_flap  <= 1'b1;
                            flap_sfx_cd <= 5'd12;
                        end
                    end

                    ST_PLAY: begin
                        if (pause_rise_latched) begin
                            state <= ST_PAUSE;
                        end else begin
                            // Scroll background & ground
                            ground_scroll <= (ground_scroll + cfg_speed[9:0] >= 10'd32) ?
                                             (ground_scroll + cfg_speed[9:0] - 10'd32) :
                                             (ground_scroll + cfg_speed[9:0]);
                            if (anim_cnt[1:0] == 2'b00) begin
                                cloud_scroll <= (cloud_scroll + 10'd1 >= 10'd640) ? 10'd0 : (cloud_scroll + 10'd1);
                            end

                            // Bird vertical velocity update
                            if (mode_edge) begin
                                if (flap_rise_latched) begin
                                    next_vel = -10'sd76;
                                    sfx_flap <= 1'b1;
                                end else begin
                                    next_vel = vel_y + 10'sd3;
                                end
                            end else begin
                                // Continuous voice / button hold mode:
                                // Quiet -> falls nose-down; Voice -> climbs nose-up
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

                            // Clamp velocity
                            if (next_vel < -10'sd64) next_vel = -10'sd64;
                            if (next_vel >  10'sd84) next_vel =  10'sd84;
                            vel_y <= next_vel;

                            // Update bird Y with ceiling clamp at y = 2
                            next_y_fp = bird_y_fp + {{5{next_vel[9]}}, next_vel};
                            if (next_y_fp < (15'sd2 <<< 4)) begin
                                bird_y_fp <= (15'sd2 <<< 4);
                                vel_y     <= 10'sd0;
                            end else begin
                                bird_y_fp <= next_y_fp;
                            end

                            // Update 3 pipes & score
                            for (k = 0; k < 3; k = k + 1) begin
                                if (px[k] < -11'sd64) begin
                                    px[k]      <= px[k] + (PIPE_SPACING * 3) - cfg_speed;
                                    pgap[k]    <= next_gap_y;
                                    pscored[k] <= 1'b0;
                                end else begin
                                    px[k] <= px[k] - cfg_speed;
                                    if (!pscored[k] && ((px[k] + (PIPE_W / 2)) < BIRD_X)) begin
                                        pscored[k] <= 1'b1;
                                        score      <= score + 14'd1;
                                        if ((score + 14'd1) > high_score) begin
                                            high_score <= score + 14'd1;
                                        end
                                        sfx_score <= 1'b1;
                                    end
                                end
                            end

                            // Collision check
                            if (hit_pipe || hit_ground) begin
                                state       <= ST_GAMEOVER;
                                go_cooldown <= 6'd40; // ~0.67s lockout
                                sfx_hit     <= 1'b1;
                            end
                        end
                    end

                    ST_PAUSE: begin
                        if (pause_rise_latched || flap_rise_latched) begin
                            state <= ST_PLAY;
                        end
                    end

                    ST_GAMEOVER: begin
                        // Let bird drop to ground if hit in midair
                        if (bird_y < (GROUND_Y - 44)) begin
                            next_vel  = (vel_y < 10'sd80) ? (vel_y + 10'sd4) : 10'sd80;
                            vel_y     <= next_vel;
                            next_y_fp = bird_y_fp + {{5{next_vel[9]}}, next_vel};
                            if (next_y_fp > 15'sd6336) begin // (440 - 44) << 4
                                bird_y_fp <= 15'sd6336;
                            end else begin
                                bird_y_fp <= next_y_fp;
                            end
                        end

                        if (go_cooldown != 6'd0) begin
                            go_cooldown <= go_cooldown - 6'd1;
                        end else if (flap_rise_latched) begin
                            state     <= ST_IDLE;
                            bird_y_fp <= 15'sd200 <<< 4;
                            vel_y     <= 10'sd0;
                        end
                    end
                endcase

                // Consume latched edges
                flap_rise_latched  <= 1'b0;
                pause_rise_latched <= 1'b0;
            end
        end
    end

endmodule
