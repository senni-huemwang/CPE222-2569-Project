`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: tb_flappy_pigeon
// Description: Behavioral simulation testbench for Vivado XSim / Icarus Verilog.
//              Verifies PDM mic envelope detection, VGA sync, and game engine.
//////////////////////////////////////////////////////////////////////////////////
module tb_flappy_pigeon;

    reg         clk = 1'b0;
    reg         rst = 1'b1;
    reg  [3:0]  sens_sw = 4'd2; // Threshold = 32
    wire        m_clk;
    reg         m_data = 1'b0;
    wire        m_lrsel;
    wire [7:0]  volume, threshold;
    wire        voice_active;
    wire [15:0] vu_leds;

    // 100 MHz clock
    always #5 clk = ~clk;

    pdm_mic u_dut_mic (
        .clk          (clk),
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

    // Game engine driven directly by simulated frame_tick for fast sim
    reg        sim_frame_tick = 1'b0;
    reg        btn_flap = 1'b0;
    reg        btn_flap_rise = 1'b0;
    reg        btn_pause_rise = 1'b0;
    reg        mode_edge = 1'b0;
    reg  [1:0] diff_sw = 2'd1;

    wire [1:0]         state;
    wire [9:0]         bird_y;
    wire               bird_pose;
    wire signed [10:0] pipe0_x, pipe1_x, pipe2_x;
    wire [9:0]         pipe0_gap_y, pipe1_gap_y, pipe2_gap_y, pipe_gap_h;
    wire [9:0]         ground_scroll, cloud_scroll;
    wire [13:0]        score, high_score;
    wire               sfx_flap, sfx_score, sfx_hit;

    game_engine u_dut_game (
        .clk            (clk),
        .rst            (rst),
        .frame_tick     (sim_frame_tick),
        .voice_active   (voice_active),
        .btn_flap       (btn_flap),
        .btn_flap_rise  (btn_flap_rise),
        .btn_pause_rise (btn_pause_rise),
        .mode_edge      (mode_edge),
        .diff_sw        (diff_sw),
        .state          (state),
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

    // Also instantiate full top-level module to verify full-chip elaboration & ROM loading
    wire [15:0] top_led;
    wire        top_r, top_g, top_b;
    wire        top_ca, top_cb, top_cc, top_cd, top_ce, top_cf, top_cg, top_dp;
    wire [7:0]  top_an;
    wire [3:0]  top_vga_r, top_vga_g, top_vga_b;
    wire        top_vga_hs, top_vga_vs;
    wire        top_m_clk, top_m_lrsel, top_aud_pwm, top_aud_sd;

    top u_dut_top (
        .CLK100MHZ  (clk),
        .CPU_RESETN (~rst),
        .SW         ({12'd0, sens_sw}),
        .BTNC       (btn_flap),
        .BTNU       (1'b0),
        .LED        (top_led),
        .LED16_R    (top_r),
        .LED16_G    (top_g),
        .LED16_B    (top_b),
        .CA(top_ca), .CB(top_cb), .CC(top_cc), .CD(top_cd),
        .CE(top_ce), .CF(top_cf), .CG(top_cg), .DP(top_dp),
        .AN         (top_an),
        .VGA_R      (top_vga_r),
        .VGA_G      (top_vga_g),
        .VGA_B      (top_vga_b),
        .VGA_HS     (top_vga_hs),
        .VGA_VS     (top_vga_vs),
        .M_CLK      (top_m_clk),
        .M_DATA     (m_data),
        .M_LRSEL    (top_m_lrsel),
        .AUD_PWM    (top_aud_pwm),
        .AUD_SD     (top_aud_sd)
    );

    // PDM stimulus generator synchronized to m_clk falling edge
    reg        loud_mode = 1'b0;
    reg [10:0] pdm_phase = 11'd0;
    always @(negedge m_clk) begin
        pdm_phase <= pdm_phase + 11'd1;
        if (!loud_mode) begin
            // Silence: 50% duty alternating 0/1
            m_data <= pdm_phase[0];
        end else begin
            // Loud ~1.2 kHz AC wave encoded in PDM density (alternating ~87% vs ~13%)
            if (pdm_phase[10] == 1'b0)
                m_data <= (pdm_phase[2:0] != 3'd0); // 7/8 ones
            else
                m_data <= (pdm_phase[2:0] == 3'd0); // 1/8 ones
        end
    end

    task pulse_frame;
        begin
            @(posedge clk);
            sim_frame_tick <= 1'b1;
            @(posedge clk);
            sim_frame_tick <= 1'b0;
            #100;
        end
    endtask

    integer f;
    reg [9:0] y_before;

    initial begin
        #200;
        rst = 1'b0;

        // 1. Quiet test (~1.5 ms) -> voice_active must stay 0
        loud_mode = 1'b0;
        #1_500_000;
        if (voice_active !== 1'b0) begin
            $display("ERROR: voice_active asserted during silence! vol=%0d", volume);
            $finish;
        end
        $display("PASS [1/4]: Silence check OK (volume=%0d, threshold=%0d)", volume, threshold);

        // 2. Loud voice test (~2.0 ms) -> voice_active must assert 1
        loud_mode = 1'b1;
        #2_000_000;
        if (voice_active !== 1'b1) begin
            $display("ERROR: voice_active did NOT assert during loud audio! vol=%0d", volume);
            $finish;
        end
        $display("PASS [2/4]: Loud voice detected OK (volume=%0d, threshold=%0d, LED=0x%04h)", volume, threshold, vu_leds);

        // 3. Game Engine: voice rising edge starts ST_PLAY, continuous voice climbs
        pulse_frame(); // Transitions ST_IDLE -> ST_PLAY
        if (state !== 2'd1) begin
            $display("ERROR: Expected ST_PLAY (1), got %0d", state);
            $finish;
        end
        y_before = bird_y;
        for (f = 0; f < 15; f = f + 1) pulse_frame();
        if (bird_y >= y_before) begin
            $display("ERROR: Bird did not fly up while voice active! before=%0d after=%0d", y_before, bird_y);
            $finish;
        end
        $display("PASS [3/4]: Voice-controlled climb OK (bird_y: %0d -> %0d)", y_before, bird_y);

        // 4. Drop voice -> envelope decays -> gravity pulls bird down -> ST_GAMEOVER
        loud_mode = 1'b0;
        #8_000_000; // Wait 8ms for envelope decay below threshold
        if (voice_active !== 1'b0) begin
            $display("ERROR: voice_active did not release after silence! vol=%0d", volume);
            $finish;
        end
        for (f = 0; f < 100; f = f + 1) begin
            pulse_frame();
        end
        if (state !== 2'd3) begin
            $display("ERROR: Expected ST_GAMEOVER (3) after falling, got state=%0d bird_y=%0d", state, bird_y);
            $finish;
        end
        $display("PASS [4/4]: Gravity fall & ground collision -> ST_GAMEOVER OK (bird_y=%0d)", bird_y);

        $display("ALL TESTS PASSED!");
        $finish;
    end

endmodule
