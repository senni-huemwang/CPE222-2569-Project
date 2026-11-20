`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: seven_seg_ctrl
// Description: 8-digit multiplexed 7-segment display driver:
//              AN[7:4] = Real-time Current Score (4 BCD digits)
//              AN[3:0] = "Ph-X" in Flappy Attack mode, OFF in Classic mode.
//////////////////////////////////////////////////////////////////////////////////
module seven_seg_ctrl (
    input  wire        clk,
    input  wire        rst,
    input  wire        active_mode,
    input  wire [3:0]  current_phase,
    input  wire [15:0] score_bcd,
    output reg  [7:0]  an,
    output reg  [6:0]  seg,  // {CA, CB, CC, CD, CE, CF, CG} active LOW
    output reg         dp    // active LOW
);
    reg [19:0] refresh_cnt;
    wire [2:0] digit_sel = refresh_cnt[19:17];

    reg [4:0] cur_char; // 0..9=digits, 10='P', 11='h', 12='-', 15=blank

    always @(posedge clk) begin
        if (rst) refresh_cnt <= 20'd0;
        else     refresh_cnt <= refresh_cnt + 20'd1;
    end

    always @(*) begin
        an = 8'hFF;
        dp = 1'b1;
        if (digit_sel >= 3'd4 || active_mode) begin
            an[digit_sel] = 1'b0; // Active LOW
        end

        case (digit_sel)
            3'd0: cur_char = (current_phase >= 4'd10) ? 5'd9 : {1'b0, current_phase};
            3'd1: cur_char = 5'd12; // '-'
            3'd2: cur_char = 5'd11; // 'h'
            3'd3: cur_char = 5'd10; // 'P'
            3'd4: cur_char = {1'b0, score_bcd[3:0]};
            3'd5: cur_char = {1'b0, score_bcd[7:4]};
            3'd6: cur_char = {1'b0, score_bcd[11:8]};
            3'd7: cur_char = {1'b0, score_bcd[15:12]};
            default: cur_char = 5'd15;
        endcase

        case (cur_char)
            5'd0:  seg = 7'b0000001;
            5'd1:  seg = 7'b1001111;
            5'd2:  seg = 7'b0010010;
            5'd3:  seg = 7'b0000110;
            5'd4:  seg = 7'b1001100;
            5'd5:  seg = 7'b0100100;
            5'd6:  seg = 7'b0100000;
            5'd7:  seg = 7'b0001111;
            5'd8:  seg = 7'b0000000;
            5'd9:  seg = 7'b0000100;
            5'd10: seg = 7'b0011000; // 'P'
            5'd11: seg = 7'b1101000; // 'h'
            5'd12: seg = 7'b1111110; // '-'
            default: seg = 7'b1111111;
        endcase
    end

endmodule
