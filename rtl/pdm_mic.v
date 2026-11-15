`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: pdm_mic
// Description: Nexys A7-100T onboard PDM Microphone (MP34DT01) driver +
//              256-tap decimation, EMA DC offset removal, peak-decay envelope,
//              hysteresis threshold voice detector, and 16-LED VU meter.
//////////////////////////////////////////////////////////////////////////////////
module pdm_mic #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer PDM_FREQ_HZ = 2_500_000
)(
    input  wire        clk,
    input  wire        rst,
    // Physical PDM Mic pins
    output reg         m_clk,
    input  wire        m_data,
    output wire        m_lrsel,
    // Sensitivity switches SW[3:0] (0 = most sensitive, 15 = least sensitive)
    input  wire [3:0]  sens_sw,
    // Processed outputs
    output wire [7:0]  volume,
    output wire [7:0]  threshold,
    output reg         voice_active,
    output reg  [15:0] vu_leds
);
    // M_LRSEL = 0 -> MP34DT01 drives data for rising-edge sampling
    assign m_lrsel = 1'b0;

    localparam integer HALF_DIV = CLK_FREQ_HZ / (2 * PDM_FREQ_HZ); // 20 @ 100MHz/2.5MHz

    reg [4:0] clk_div;
    reg       m_data_s0, m_data_s1;
    reg [7:0] pdm_idx;
    reg [8:0] ones_cnt;

    // 256-sample EMA DC tracker: dc_avg = 256 * mean(ones_cnt)
    reg [16:0] dc_avg;
    reg [15:0] env;

    wire signed [9:0] ac_diff = $signed({1'b0, ones_cnt}) - $signed({1'b0, dc_avg[16:8]});
    wire        [9:0] abs_ac  = ac_diff[9] ? (~ac_diff + 10'd1) : ac_diff;
    wire        [7:0] scaled_ac = (abs_ac >= 10'd128) ? 8'd255 : {abs_ac[6:0], 1'b0};
    wire        [15:0] target_env = {scaled_ac, 8'd0};

    assign volume    = env[15:8];
    assign threshold = 8'd12 + ({4'd0, sens_sw} * 8'd10); // Range: 12 .. 162

    always @(posedge clk) begin
        if (rst) begin
            clk_div      <= 5'd0;
            m_clk        <= 1'b0;
            m_data_s0    <= 1'b0;
            m_data_s1    <= 1'b0;
            pdm_idx      <= 8'd0;
            ones_cnt     <= 9'd0;
            dc_avg       <= 17'd32768; // Init to midpoint (128 * 256)
            env          <= 16'd0;
            voice_active <= 1'b0;
        end else begin
            // 2-FF input synchronizer for external PDM data
            m_data_s0 <= m_data;
            m_data_s1 <= m_data_s0;

            // Generate 2.5 MHz m_clk
            if (clk_div >= HALF_DIV - 1) begin
                clk_div <= 5'd0;
                m_clk   <= ~m_clk;
            end else begin
                clk_div <= clk_div + 5'd1;
            end

            // Sample settled PDM bit near end of m_clk high half-cycle
            if (m_clk == 1'b1 && clk_div == (HALF_DIV - 4)) begin
                if (pdm_idx == 8'd255) begin
                    // End of 256-bit window (~9.77 kHz PCM rate)
                    // Update DC offset tracker
                    dc_avg <= dc_avg - {8'd0, dc_avg[16:8]} + {8'd0, ones_cnt};

                    // Envelope detector (fast attack, crisp ~3.3ms release for low-latency flight)
                    if (target_env > env) begin
                        env <= env + ((target_env - env) >> 1);
                    end else if (env > 16'd32) begin
                        env <= env - (env >> 5) - 16'd32;
                    end else begin
                        env <= 16'd0;
                    end

                    // Hysteresis threshold detector
                    if (env[15:8] >= threshold) begin
                        voice_active <= 1'b1;
                    end else if (env[15:8] + 8'd4 < threshold) begin
                        voice_active <= 1'b0;
                    end

                    pdm_idx  <= 8'd0;
                    ones_cnt <= m_data_s1 ? 9'd1 : 9'd0;
                end else begin
                    pdm_idx  <= pdm_idx + 8'd1;
                    ones_cnt <= ones_cnt + (m_data_s1 ? 9'd1 : 9'd0);
                end
            end
        end
    end

    // 16-LED Thermometer VU meter
    integer i;
    always @(*) begin
        for (i = 0; i < 16; i = i + 1) begin
            vu_leds[i] = (volume >= (i * 16 + 8));
        end
    end

endmodule
