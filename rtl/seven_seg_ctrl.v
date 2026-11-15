`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: seven_seg_ctrl
// Description: 8-digit time-multiplexed 7-segment display driver (active-low
//              anodes & cathodes for Nexys A7-100T).
//              AN[7:4] = High Score (4 BCD digits), AN[3:0] = Current Score.
//////////////////////////////////////////////////////////////////////////////////
module seven_seg_ctrl (
    input  wire        clk,
    input  wire        rst,
    input  wire [15:0] high_score_bcd,
    input  wire [15:0] score_bcd,
    output reg  [7:0]  an,
    output reg  [6:0]  seg,  // {CA, CB, CC, CD, CE, CF, CG} active LOW
    output reg         dp    // active LOW
);
    reg [19:0] refresh_cnt;
    wire [2:0] digit_sel = refresh_cnt[19:17];

    reg [3:0] cur_nibble;

    always @(posedge clk) begin
        if (rst) begin
            refresh_cnt <= 20'd0;
        end else begin
            refresh_cnt <= refresh_cnt + 20'd1;
        end
    end

    always @(*) begin
        an = 8'hFF;
        an[digit_sel] = 1'b0; // Active LOW
        dp = (digit_sel == 3'd4) ? 1'b0 : 1'b1; // Separator dot between High & Current score

        case (digit_sel)
            3'd0: cur_nibble = score_bcd[3:0];
            3'd1: cur_nibble = score_bcd[7:4];
            3'd2: cur_nibble = score_bcd[11:8];
            3'd3: cur_nibble = score_bcd[15:12];
            3'd4: cur_nibble = high_score_bcd[3:0];
            3'd5: cur_nibble = high_score_bcd[7:4];
            3'd6: cur_nibble = high_score_bcd[11:8];
            3'd7: cur_nibble = high_score_bcd[15:12];
            default: cur_nibble = 4'd0;
        endcase

        // Active-LOW 7-segment decoder: {CA, CB, CC, CD, CE, CF, CG}
        case (cur_nibble)
            4'd0: seg = 7'b0000001;
            4'd1: seg = 7'b1001111;
            4'd2: seg = 7'b0010010;
            4'd3: seg = 7'b0000110;
            4'd4: seg = 7'b1001100;
            4'd5: seg = 7'b0100100;
            4'd6: seg = 7'b0100000;
            4'd7: seg = 7'b0001111;
            4'd8: seg = 7'b0000000;
            4'd9: seg = 7'b0000100;
            default: seg = 7'b1111111;
        endcase
    end

endmodule
