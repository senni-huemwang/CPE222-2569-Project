`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: pdm_mic
// Description: Nexys A7-100T onboard PDM Microphone (MP34DT01) driver +
//              1024-tap decimation, EMA DC offset removal, 12x gain,
//              smooth peak-decay envelope, and 16-LED VU meter.
//////////////////////////////////////////////////////////////////////////////////
module pdm_mic #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer PDM_FREQ_HZ = 2_500_000
)(
    input  wire        clk,
    input  wire        rst,
    output reg         m_clk,
    input  wire        m_data,
    output wire        m_lrsel,
    // Sensitivity switches SW[3:1]: SW[3]=Chaos, SW[2]=Normal, SW[1]=Sensitive
    input  wire [2:0]  sens_sw,
    output wire [7:0]  volume,
    output wire [7:0]  threshold,
    output reg         voice_active,
    output reg  [15:0] vu_leds
);
    assign m_lrsel = 1'b0;

    localparam integer HALF_DIV = CLK_FREQ_HZ / (2 * PDM_FREQ_HZ); // 20

    reg [4:0]  clk_div;
    reg        m_data_s0, m_data_s1;
    reg [9:0]  pdm_idx;
    reg [10:0] ones_cnt;

    // 1024-sample EMA DC tracker: dc_avg = 1024 * mean(ones_cnt)
    reg [20:0] dc_avg;
    reg [15:0] env;

    wire signed [11:0] ac_diff  = $signed({1'b0, ones_cnt}) - $signed({1'b0, dc_avg[20:10]});
    wire        [11:0] abs_ac   = ac_diff[11] ? (~ac_diff + 12'd1) : ac_diff;
    // 16x digital gain so 30cm speech spans 26%..100% of the Voice Meter bar
    wire        [15:0] gained_ac = {abs_ac, 4'b0000};
    wire        [7:0]  scaled_ac = (gained_ac >= 16'd255) ? 8'd255 : gained_ac[7:0];
    wire        [15:0] target_env = {scaled_ac, 8'd0};

    assign volume    = env[15:8];
    // Thresholds as % of 255: Chaos=70% (178), Normal=45% (115), Sensitive=26% (66)
    assign threshold = sens_sw[2] ? 8'd178 :
                       sens_sw[1] ? 8'd115 : 8'd66;

    always @(posedge clk) begin
        if (rst) begin
            clk_div      <= 5'd0;
            m_clk        <= 1'b0;
            m_data_s0    <= 1'b0;
            m_data_s1    <= 1'b0;
            pdm_idx      <= 10'd0;
            ones_cnt     <= 11'd0;
            dc_avg       <= 21'd524288; // Midpoint 512 * 1024
            env          <= 16'd0;
            voice_active <= 1'b0;
        end else begin
            m_data_s0 <= m_data;
            m_data_s1 <= m_data_s0;

            if (clk_div >= HALF_DIV - 1) begin
                clk_div <= 5'd0;
                m_clk   <= ~m_clk;
            end else begin
                clk_div <= clk_div + 5'd1;
            end

            if (m_clk == 1'b1 && clk_div == (HALF_DIV - 4)) begin
                if (pdm_idx == 10'd1023) begin
                    // ~2.44 kHz PCM rate
                    dc_avg <= dc_avg - {10'd0, dc_avg[20:10]} + {10'd0, ones_cnt};

                    // Fast attack, smooth exponential decay (~52ms)
                    if (target_env > env) begin
                        env <= env + ((target_env - env) >> 1);
                    end else begin
                        env <= env - (env >> 7);
                    end

                    if (env[15:8] >= threshold) begin
                        voice_active <= 1'b1;
                    end else if (env[15:8] + 8'd3 < threshold) begin
                        voice_active <= 1'b0;
                    end

                    pdm_idx  <= 10'd0;
                    ones_cnt <= m_data_s1 ? 11'd1 : 11'd0;
                end else begin
                    pdm_idx  <= pdm_idx + 10'd1;
                    ones_cnt <= ones_cnt + (m_data_s1 ? 11'd1 : 11'd0);
                end
            end
        end
    end

    integer i;
    always @(*) begin
        for (i = 0; i < 16; i = i + 1) begin
            vu_leds[i] = (volume >= (i * 16 + 6));
        end
    end

endmodule
