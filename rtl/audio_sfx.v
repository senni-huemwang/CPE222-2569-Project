`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: audio_sfx
// Description: Retro PWM mono audio synthesizer for Nexys A7-100T (AUD_PWM/AUD_SD).
//              Plays Flap chirp, Score 2-tone coin chime, and Game Over buzz.
//////////////////////////////////////////////////////////////////////////////////
module audio_sfx (
    input  wire clk,
    input  wire rst,
    input  wire mute,       // SW[15]
    input  wire sfx_flap,
    input  wire sfx_score,
    input  wire sfx_hit,
    output wire aud_pwm,
    output wire aud_sd
);
    localparam [1:0] SND_NONE  = 2'd0,
                     SND_FLAP  = 2'd1,
                     SND_SCORE = 2'd2,
                     SND_HIT   = 2'd3;

    reg [1:0]  snd_type;
    reg [24:0] dur_cnt;
    reg [19:0] tone_cnt;
    reg        tone_sq;
    reg [7:0]  pwm_cnt;

    reg [19:0] half_period;
    always @(*) begin
        case (snd_type)
            SND_FLAP:  half_period = (dur_cnt > 25'd2_500_000) ? 20'd105_000 : 20'd65_000;
            SND_SCORE: half_period = (dur_cnt > 25'd8_000_000) ? 20'd50_607  : 20'd37_908;
            SND_HIT:   half_period = (dur_cnt > 25'd12_000_000)? 20'd250_000 : 20'd410_000;
            default:   half_period = 20'd50_000;
        endcase
    end

    always @(posedge clk) begin
        if (rst) begin
            snd_type <= SND_NONE;
            dur_cnt  <= 25'd0;
            tone_cnt <= 20'd0;
            tone_sq  <= 1'b0;
            pwm_cnt  <= 8'd0;
        end else begin
            pwm_cnt <= pwm_cnt + 8'd1;

            // Priority trigger
            if (sfx_hit) begin
                snd_type <= SND_HIT;
                dur_cnt  <= 25'd24_000_000; // 240 ms
                tone_cnt <= 20'd0;
            end else if (sfx_score && (snd_type != SND_HIT)) begin
                snd_type <= SND_SCORE;
                dur_cnt  <= 25'd16_000_000; // 160 ms
                tone_cnt <= 20'd0;
            end else if (sfx_flap && (snd_type == SND_NONE)) begin
                snd_type <= SND_FLAP;
                dur_cnt  <= 25'd5_000_000;  // 50 ms
                tone_cnt <= 20'd0;
            end else if (dur_cnt != 25'd0) begin
                dur_cnt <= dur_cnt - 25'd1;
                if (dur_cnt == 25'd1) begin
                    snd_type <= SND_NONE;
                end
            end

            // Square wave tone generator
            if (snd_type == SND_NONE) begin
                tone_cnt <= 20'd0;
                tone_sq  <= 1'b0;
            end else if (tone_cnt >= half_period) begin
                tone_cnt <= 20'd0;
                tone_sq  <= ~tone_sq;
            end else begin
                tone_cnt <= tone_cnt + 20'd1;
            end
        end
    end

    // Comfortable headphone/speaker amplitude (~35% modulation around mid-rail)
    wire [7:0] pwm_duty = (snd_type == SND_NONE) ? 8'd128 :
                          (tone_sq ? 8'd176 : 8'd80);

    assign aud_sd  = (~mute) && (snd_type != SND_NONE);
    assign aud_pwm = (pwm_cnt < pwm_duty);

endmodule
