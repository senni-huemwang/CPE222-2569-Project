`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: bin2bcd
// Description: Combinational 14-bit binary (0..9999) to 4-digit BCD converter
//              using the Double-Dabble (shift-and-add-3) algorithm.
//////////////////////////////////////////////////////////////////////////////////
module bin2bcd (
    input  wire [13:0] bin,
    output reg  [15:0] bcd
);
    wire [13:0] bin_clamped = (bin > 14'd9999) ? 14'd9999 : bin;
    reg  [29:0] shift_reg;
    integer i;

    always @(*) begin
        shift_reg = {16'd0, bin_clamped};
        for (i = 0; i < 14; i = i + 1) begin
            if (shift_reg[17:14] >= 4'd5) shift_reg[17:14] = shift_reg[17:14] + 4'd3;
            if (shift_reg[21:18] >= 4'd5) shift_reg[21:18] = shift_reg[21:18] + 4'd3;
            if (shift_reg[25:22] >= 4'd5) shift_reg[25:22] = shift_reg[25:22] + 4'd3;
            if (shift_reg[29:26] >= 4'd5) shift_reg[29:26] = shift_reg[29:26] + 4'd3;
            shift_reg = shift_reg << 1;
        end
        bcd = shift_reg[29:14];
    end

endmodule
