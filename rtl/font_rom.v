`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: font_rom
// Description: Synchronous 8x8 pixel bitmap font ROM (0-9, A-Z, a-z, punctuation)
//              with 8-neighbor outline_on output for bordered banners.
//              MSB (bit 7) is leftmost pixel (x=0).
//////////////////////////////////////////////////////////////////////////////////
module font_rom (
    input  wire       clk,
    input  wire [6:0] char_code,
    input  wire [2:0] row,
    input  wire [2:0] col,
    output reg        pix_on,
    output reg        outline_on
);
    function [7:0] glyph_row;
        input [6:0] ch;
        input [2:0] r;
        begin
            glyph_row = 8'h00;
            case (ch)
                7'h20: glyph_row = 8'h00; // ' '
                7'h21: case (r) // '!'
                    3'd0: glyph_row = 8'h18; 3'd1: glyph_row = 8'h18; 3'd2: glyph_row = 8'h18;
                    3'd3: glyph_row = 8'h18; 3'd4: glyph_row = 8'h18; 3'd6: glyph_row = 8'h18;
                    default: glyph_row = 8'h00;
                endcase
                7'h2B: case (r) // '+'
                    3'd1: glyph_row = 8'h18; 3'd2: glyph_row = 8'h18; 3'd3: glyph_row = 8'h7E;
                    3'd4: glyph_row = 8'h18; 3'd5: glyph_row = 8'h18;
                    default: glyph_row = 8'h00;
                endcase
                7'h2C: case (r) // ','
                    3'd5: glyph_row = 8'h18; 3'd6: glyph_row = 8'h18; 3'd7: glyph_row = 8'h30;
                    default: glyph_row = 8'h00;
                endcase
                7'h2D: if (r == 3'd3) glyph_row = 8'h7E; // '-'
                7'h2E: if (r == 3'd5 || r == 3'd6) glyph_row = 8'h18; // '.'
                7'h2F: case (r) // '/'
                    3'd0: glyph_row = 8'h06; 3'd1: glyph_row = 8'h0C; 3'd2: glyph_row = 8'h18;
                    3'd3: glyph_row = 8'h30; 3'd4: glyph_row = 8'h60; 3'd5: glyph_row = 8'hC0;
                    default: glyph_row = 8'h00;
                endcase
                7'h3A: if (r == 3'd2 || r == 3'd5) glyph_row = 8'h18; // ':'
                // Digits 0-9
                7'h30: case (r) 3'd0:glyph_row=8'h3C;3'd1:glyph_row=8'h66;3'd2:glyph_row=8'h6E;3'd3:glyph_row=8'h76;3'd4:glyph_row=8'h66;3'd5:glyph_row=8'h66;3'd6:glyph_row=8'h3C;default:glyph_row=8'h00; endcase
                7'h31: case (r) 3'd0:glyph_row=8'h18;3'd1:glyph_row=8'h38;3'd2:glyph_row=8'h18;3'd3:glyph_row=8'h18;3'd4:glyph_row=8'h18;3'd5:glyph_row=8'h18;3'd6:glyph_row=8'h7E;default:glyph_row=8'h00; endcase
                7'h32: case (r) 3'd0:glyph_row=8'h3C;3'd1:glyph_row=8'h66;3'd2:glyph_row=8'h06;3'd3:glyph_row=8'h1C;3'd4:glyph_row=8'h30;3'd5:glyph_row=8'h60;3'd6:glyph_row=8'h7E;default:glyph_row=8'h00; endcase
                7'h33: case (r) 3'd0:glyph_row=8'h3C;3'd1:glyph_row=8'h66;3'd2:glyph_row=8'h06;3'd3:glyph_row=8'h1C;3'd4:glyph_row=8'h06;3'd5:glyph_row=8'h66;3'd6:glyph_row=8'h3C;default:glyph_row=8'h00; endcase
                7'h34: case (r) 3'd0:glyph_row=8'h0C;3'd1:glyph_row=8'h1C;3'd2:glyph_row=8'h3C;3'd3:glyph_row=8'h6C;3'd4:glyph_row=8'h7E;3'd5:glyph_row=8'h0C;3'd6:glyph_row=8'h0C;default:glyph_row=8'h00; endcase
                7'h35: case (r) 3'd0:glyph_row=8'h7E;3'd1:glyph_row=8'h60;3'd2:glyph_row=8'h7C;3'd3:glyph_row=8'h06;3'd4:glyph_row=8'h06;3'd5:glyph_row=8'h66;3'd6:glyph_row=8'h3C;default:glyph_row=8'h00; endcase
                7'h36: case (r) 3'd0:glyph_row=8'h3C;3'd1:glyph_row=8'h60;3'd2:glyph_row=8'h60;3'd3:glyph_row=8'h7C;3'd4:glyph_row=8'h66;3'd5:glyph_row=8'h66;3'd6:glyph_row=8'h3C;default:glyph_row=8'h00; endcase
                7'h37: case (r) 3'd0:glyph_row=8'h7E;3'd1:glyph_row=8'h66;3'd2:glyph_row=8'h0C;3'd3:glyph_row=8'h18;3'd4:glyph_row=8'h18;3'd5:glyph_row=8'h18;3'd6:glyph_row=8'h18;default:glyph_row=8'h00; endcase
                7'h38: case (r) 3'd0:glyph_row=8'h3C;3'd1:glyph_row=8'h66;3'd2:glyph_row=8'h66;3'd3:glyph_row=8'h3C;3'd4:glyph_row=8'h66;3'd5:glyph_row=8'h66;3'd6:glyph_row=8'h3C;default:glyph_row=8'h00; endcase
                7'h39: case (r) 3'd0:glyph_row=8'h3C;3'd1:glyph_row=8'h66;3'd2:glyph_row=8'h66;3'd3:glyph_row=8'h3E;3'd4:glyph_row=8'h06;3'd5:glyph_row=8'h06;3'd6:glyph_row=8'h3C;default:glyph_row=8'h00; endcase
                // Uppercase A-Z
                7'h41: case (r) 3'd0:glyph_row=8'h18;3'd1:glyph_row=8'h3C;3'd2:glyph_row=8'h66;3'd3:glyph_row=8'h66;3'd4:glyph_row=8'h7E;3'd5:glyph_row=8'h66;3'd6:glyph_row=8'h66;default:glyph_row=8'h00; endcase
                7'h42: case (r) 3'd0:glyph_row=8'h7C;3'd1:glyph_row=8'h66;3'd2:glyph_row=8'h66;3'd3:glyph_row=8'h7C;3'd4:glyph_row=8'h66;3'd5:glyph_row=8'h66;3'd6:glyph_row=8'h7C;default:glyph_row=8'h00; endcase
                7'h43: case (r) 3'd0:glyph_row=8'h3C;3'd1:glyph_row=8'h66;3'd2:glyph_row=8'h60;3'd3:glyph_row=8'h60;3'd4:glyph_row=8'h60;3'd5:glyph_row=8'h66;3'd6:glyph_row=8'h3C;default:glyph_row=8'h00; endcase
                7'h44: case (r) 3'd0:glyph_row=8'h78;3'd1:glyph_row=8'h6C;3'd2:glyph_row=8'h66;3'd3:glyph_row=8'h66;3'd4:glyph_row=8'h66;3'd5:glyph_row=8'h6C;3'd6:glyph_row=8'h78;default:glyph_row=8'h00; endcase
                7'h45: case (r) 3'd0:glyph_row=8'h7E;3'd1:glyph_row=8'h60;3'd2:glyph_row=8'h60;3'd3:glyph_row=8'h78;3'd4:glyph_row=8'h60;3'd5:glyph_row=8'h60;3'd6:glyph_row=8'h7E;default:glyph_row=8'h00; endcase
                7'h46: case (r) 3'd0:glyph_row=8'h7E;3'd1:glyph_row=8'h60;3'd2:glyph_row=8'h60;3'd3:glyph_row=8'h78;3'd4:glyph_row=8'h60;3'd5:glyph_row=8'h60;3'd6:glyph_row=8'h60;default:glyph_row=8'h00; endcase
                7'h47: case (r) 3'd0:glyph_row=8'h3C;3'd1:glyph_row=8'h66;3'd2:glyph_row=8'h60;3'd3:glyph_row=8'h6E;3'd4:glyph_row=8'h66;3'd5:glyph_row=8'h66;3'd6:glyph_row=8'h3E;default:glyph_row=8'h00; endcase
                7'h48: case (r) 3'd0:glyph_row=8'h66;3'd1:glyph_row=8'h66;3'd2:glyph_row=8'h66;3'd3:glyph_row=8'h7E;3'd4:glyph_row=8'h66;3'd5:glyph_row=8'h66;3'd6:glyph_row=8'h66;default:glyph_row=8'h00; endcase
                7'h49: case (r) 3'd0:glyph_row=8'h3C;3'd1:glyph_row=8'h18;3'd2:glyph_row=8'h18;3'd3:glyph_row=8'h18;3'd4:glyph_row=8'h18;3'd5:glyph_row=8'h18;3'd6:glyph_row=8'h3C;default:glyph_row=8'h00; endcase
                7'h4A: case (r) 3'd0:glyph_row=8'h1E;3'd1:glyph_row=8'h0C;3'd2:glyph_row=8'h0C;3'd3:glyph_row=8'h0C;3'd4:glyph_row=8'h6C;3'd5:glyph_row=8'h6C;3'd6:glyph_row=8'h38;default:glyph_row=8'h00; endcase
                7'h4B: case (r) 3'd0:glyph_row=8'h66;3'd1:glyph_row=8'h6C;3'd2:glyph_row=8'h78;3'd3:glyph_row=8'h70;3'd4:glyph_row=8'h78;3'd5:glyph_row=8'h6C;3'd6:glyph_row=8'h66;default:glyph_row=8'h00; endcase
                7'h4C: case (r) 3'd0:glyph_row=8'h60;3'd1:glyph_row=8'h60;3'd2:glyph_row=8'h60;3'd3:glyph_row=8'h60;3'd4:glyph_row=8'h60;3'd5:glyph_row=8'h60;3'd6:glyph_row=8'h7E;default:glyph_row=8'h00; endcase
                7'h4D: case (r) 3'd0:glyph_row=8'h63;3'd1:glyph_row=8'h77;3'd2:glyph_row=8'h7F;3'd3:glyph_row=8'h6B;3'd4:glyph_row=8'h63;3'd5:glyph_row=8'h63;3'd6:glyph_row=8'h63;default:glyph_row=8'h00; endcase
                7'h4E: case (r) 3'd0:glyph_row=8'h66;3'd1:glyph_row=8'h76;3'd2:glyph_row=8'h7E;3'd3:glyph_row=8'h7E;3'd4:glyph_row=8'h6E;3'd5:glyph_row=8'h66;3'd6:glyph_row=8'h66;default:glyph_row=8'h00; endcase
                7'h4F: case (r) 3'd0:glyph_row=8'h3C;3'd1:glyph_row=8'h66;3'd2:glyph_row=8'h66;3'd3:glyph_row=8'h66;3'd4:glyph_row=8'h66;3'd5:glyph_row=8'h66;3'd6:glyph_row=8'h3C;default:glyph_row=8'h00; endcase
                7'h50: case (r) 3'd0:glyph_row=8'h7C;3'd1:glyph_row=8'h66;3'd2:glyph_row=8'h66;3'd3:glyph_row=8'h7C;3'd4:glyph_row=8'h60;3'd5:glyph_row=8'h60;3'd6:glyph_row=8'h60;default:glyph_row=8'h00; endcase
                7'h51: case (r) 3'd0:glyph_row=8'h3C;3'd1:glyph_row=8'h66;3'd2:glyph_row=8'h66;3'd3:glyph_row=8'h66;3'd4:glyph_row=8'h6A;3'd5:glyph_row=8'h6C;3'd6:glyph_row=8'h36;default:glyph_row=8'h00; endcase
                7'h52: case (r) 3'd0:glyph_row=8'h7C;3'd1:glyph_row=8'h66;3'd2:glyph_row=8'h66;3'd3:glyph_row=8'h7C;3'd4:glyph_row=8'h6C;3'd5:glyph_row=8'h66;3'd6:glyph_row=8'h66;default:glyph_row=8'h00; endcase
                7'h53: case (r) 3'd0:glyph_row=8'h3C;3'd1:glyph_row=8'h66;3'd2:glyph_row=8'h60;3'd3:glyph_row=8'h3C;3'd4:glyph_row=8'h06;3'd5:glyph_row=8'h66;3'd6:glyph_row=8'h3C;default:glyph_row=8'h00; endcase
                7'h54: case (r) 3'd0:glyph_row=8'h7E;3'd1:glyph_row=8'h18;3'd2:glyph_row=8'h18;3'd3:glyph_row=8'h18;3'd4:glyph_row=8'h18;3'd5:glyph_row=8'h18;3'd6:glyph_row=8'h18;default:glyph_row=8'h00; endcase
                7'h55: case (r) 3'd0:glyph_row=8'h66;3'd1:glyph_row=8'h66;3'd2:glyph_row=8'h66;3'd3:glyph_row=8'h66;3'd4:glyph_row=8'h66;3'd5:glyph_row=8'h66;3'd6:glyph_row=8'h3C;default:glyph_row=8'h00; endcase
                7'h56: case (r) 3'd0:glyph_row=8'h66;3'd1:glyph_row=8'h66;3'd2:glyph_row=8'h66;3'd3:glyph_row=8'h66;3'd4:glyph_row=8'h66;3'd5:glyph_row=8'h3C;3'd6:glyph_row=8'h18;default:glyph_row=8'h00; endcase
                7'h57: case (r) 3'd0:glyph_row=8'h63;3'd1:glyph_row=8'h63;3'd2:glyph_row=8'h63;3'd3:glyph_row=8'h6B;3'd4:glyph_row=8'h7F;3'd5:glyph_row=8'h77;3'd6:glyph_row=8'h63;default:glyph_row=8'h00; endcase
                7'h58: case (r) 3'd0:glyph_row=8'h66;3'd1:glyph_row=8'h66;3'd2:glyph_row=8'h3C;3'd3:glyph_row=8'h18;3'd4:glyph_row=8'h3C;3'd5:glyph_row=8'h66;3'd6:glyph_row=8'h66;default:glyph_row=8'h00; endcase
                7'h59: case (r) 3'd0:glyph_row=8'h66;3'd1:glyph_row=8'h66;3'd2:glyph_row=8'h66;3'd3:glyph_row=8'h3C;3'd4:glyph_row=8'h18;3'd5:glyph_row=8'h18;3'd6:glyph_row=8'h18;default:glyph_row=8'h00; endcase
                7'h5A: case (r) 3'd0:glyph_row=8'h7E;3'd1:glyph_row=8'h06;3'd2:glyph_row=8'h0C;3'd3:glyph_row=8'h18;3'd4:glyph_row=8'h30;3'd5:glyph_row=8'h60;3'd6:glyph_row=8'h7E;default:glyph_row=8'h00; endcase
                // Lowercase a-z
                7'h61: case (r) 3'd2:glyph_row=8'h3C;3'd3:glyph_row=8'h06;3'd4:glyph_row=8'h3E;3'd5:glyph_row=8'h66;3'd6:glyph_row=8'h3E;default:glyph_row=8'h00; endcase
                7'h62: case (r) 3'd0:glyph_row=8'h60;3'd1:glyph_row=8'h60;3'd2:glyph_row=8'h7C;3'd3:glyph_row=8'h66;3'd4:glyph_row=8'h66;3'd5:glyph_row=8'h66;3'd6:glyph_row=8'h7C;default:glyph_row=8'h00; endcase
                7'h63: case (r) 3'd2:glyph_row=8'h3C;3'd3:glyph_row=8'h60;3'd4:glyph_row=8'h60;3'd5:glyph_row=8'h66;3'd6:glyph_row=8'h3C;default:glyph_row=8'h00; endcase
                7'h64: case (r) 3'd0:glyph_row=8'h06;3'd1:glyph_row=8'h06;3'd2:glyph_row=8'h3E;3'd3:glyph_row=8'h66;3'd4:glyph_row=8'h66;3'd5:glyph_row=8'h66;3'd6:glyph_row=8'h3E;default:glyph_row=8'h00; endcase
                7'h65: case (r) 3'd2:glyph_row=8'h3C;3'd3:glyph_row=8'h66;3'd4:glyph_row=8'h7E;3'd5:glyph_row=8'h60;3'd6:glyph_row=8'h3E;default:glyph_row=8'h00; endcase
                7'h66: case (r) 3'd0:glyph_row=8'h1C;3'd1:glyph_row=8'h30;3'd2:glyph_row=8'h7C;3'd3:glyph_row=8'h30;3'd4:glyph_row=8'h30;3'd5:glyph_row=8'h30;3'd6:glyph_row=8'h30;default:glyph_row=8'h00; endcase
                7'h67: case (r) 3'd2:glyph_row=8'h3E;3'd3:glyph_row=8'h66;3'd4:glyph_row=8'h66;3'd5:glyph_row=8'h3E;3'd6:glyph_row=8'h06;3'd7:glyph_row=8'h3C;default:glyph_row=8'h00; endcase
                7'h68: case (r) 3'd0:glyph_row=8'h60;3'd1:glyph_row=8'h60;3'd2:glyph_row=8'h7C;3'd3:glyph_row=8'h66;3'd4:glyph_row=8'h66;3'd5:glyph_row=8'h66;3'd6:glyph_row=8'h66;default:glyph_row=8'h00; endcase
                7'h69: case (r) 3'd0:glyph_row=8'h18;3'd2:glyph_row=8'h38;3'd3:glyph_row=8'h18;3'd4:glyph_row=8'h18;3'd5:glyph_row=8'h18;3'd6:glyph_row=8'h3C;default:glyph_row=8'h00; endcase
                7'h6A: case (r) 3'd0:glyph_row=8'h0C;3'd2:glyph_row=8'h1C;3'd3:glyph_row=8'h0C;3'd4:glyph_row=8'h0C;3'd5:glyph_row=8'h6C;3'd6:glyph_row=8'h38;default:glyph_row=8'h00; endcase
                7'h6B: case (r) 3'd0:glyph_row=8'h60;3'd1:glyph_row=8'h60;3'd2:glyph_row=8'h66;3'd3:glyph_row=8'h6C;3'd4:glyph_row=8'h78;3'd5:glyph_row=8'h6C;3'd6:glyph_row=8'h66;default:glyph_row=8'h00; endcase
                7'h6C: case (r) 3'd0:glyph_row=8'h38;3'd1:glyph_row=8'h18;3'd2:glyph_row=8'h18;3'd3:glyph_row=8'h18;3'd4:glyph_row=8'h18;3'd5:glyph_row=8'h18;3'd6:glyph_row=8'h3C;default:glyph_row=8'h00; endcase
                7'h6D: case (r) 3'd2:glyph_row=8'h76;3'd3:glyph_row=8'h7F;3'd4:glyph_row=8'h6B;3'd5:glyph_row=8'h63;3'd6:glyph_row=8'h63;default:glyph_row=8'h00; endcase
                7'h6E: case (r) 3'd2:glyph_row=8'h7C;3'd3:glyph_row=8'h66;3'd4:glyph_row=8'h66;3'd5:glyph_row=8'h66;3'd6:glyph_row=8'h66;default:glyph_row=8'h00; endcase
                7'h6F: case (r) 3'd2:glyph_row=8'h3C;3'd3:glyph_row=8'h66;3'd4:glyph_row=8'h66;3'd5:glyph_row=8'h66;3'd6:glyph_row=8'h3C;default:glyph_row=8'h00; endcase
                7'h70: case (r) 3'd2:glyph_row=8'h7C;3'd3:glyph_row=8'h66;3'd4:glyph_row=8'h66;3'd5:glyph_row=8'h7C;3'd6:glyph_row=8'h60;3'd7:glyph_row=8'h60;default:glyph_row=8'h00; endcase
                7'h71: case (r) 3'd2:glyph_row=8'h3E;3'd3:glyph_row=8'h66;3'd4:glyph_row=8'h66;3'd5:glyph_row=8'h3E;3'd6:glyph_row=8'h06;3'd7:glyph_row=8'h06;default:glyph_row=8'h00; endcase
                7'h72: case (r) 3'd2:glyph_row=8'h6C;3'd3:glyph_row=8'h76;3'd4:glyph_row=8'h60;3'd5:glyph_row=8'h60;3'd6:glyph_row=8'h60;default:glyph_row=8'h00; endcase
                7'h73: case (r) 3'd2:glyph_row=8'h3E;3'd3:glyph_row=8'h60;3'd4:glyph_row=8'h3C;3'd5:glyph_row=8'h06;3'd6:glyph_row=8'h7C;default:glyph_row=8'h00; endcase
                7'h74: case (r) 3'd0:glyph_row=8'h30;3'd1:glyph_row=8'h30;3'd2:glyph_row=8'h7C;3'd3:glyph_row=8'h30;3'd4:glyph_row=8'h30;3'd5:glyph_row=8'h34;3'd6:glyph_row=8'h18;default:glyph_row=8'h00; endcase
                7'h75: case (r) 3'd2:glyph_row=8'h66;3'd3:glyph_row=8'h66;3'd4:glyph_row=8'h66;3'd5:glyph_row=8'h66;3'd6:glyph_row=8'h3E;default:glyph_row=8'h00; endcase
                7'h76: case (r) 3'd2:glyph_row=8'h66;3'd3:glyph_row=8'h66;3'd4:glyph_row=8'h66;3'd5:glyph_row=8'h3C;3'd6:glyph_row=8'h18;default:glyph_row=8'h00; endcase
                7'h77: case (r) 3'd2:glyph_row=8'h63;3'd3:glyph_row=8'h63;3'd4:glyph_row=8'h6B;3'd5:glyph_row=8'h7F;3'd6:glyph_row=8'h36;default:glyph_row=8'h00; endcase
                7'h78: case (r) 3'd2:glyph_row=8'h66;3'd3:glyph_row=8'h3C;3'd4:glyph_row=8'h18;3'd5:glyph_row=8'h3C;3'd6:glyph_row=8'h66;default:glyph_row=8'h00; endcase
                7'h79: case (r) 3'd2:glyph_row=8'h66;3'd3:glyph_row=8'h66;3'd4:glyph_row=8'h3E;3'd5:glyph_row=8'h06;3'd6:glyph_row=8'h3C;default:glyph_row=8'h00; endcase
                7'h7A: case (r) 3'd2:glyph_row=8'h7E;3'd3:glyph_row=8'h0C;3'd4:glyph_row=8'h18;3'd5:glyph_row=8'h30;3'd6:glyph_row=8'h7E;default:glyph_row=8'h00; endcase
                7'h7E: case (r) 3'd2:glyph_row=8'h32;3'd3:glyph_row=8'h4C;default:glyph_row=8'h00; endcase // '~'
                default: glyph_row = 8'h00;
            endcase
        end
    endfunction

    wire [7:0] r_cur = glyph_row(char_code, row);
    wire [7:0] r_up  = (row > 3'd0) ? glyph_row(char_code, row - 3'd1) : 8'h00;
    wire [7:0] r_dn  = (row < 3'd7) ? glyph_row(char_code, row + 3'd1) : 8'h00;

    wire c_pix = r_cur[3'd7 - col];
    wire l_pix = (col > 3'd0) ? r_cur[3'd7 - (col - 3'd1)] : 1'b0;
    wire r_pix = (col < 3'd7) ? r_cur[3'd7 - (col + 3'd1)] : 1'b0;
    wire u_pix = r_up[3'd7 - col];
    wire d_pix = r_dn[3'd7 - col];
    wire ul_pix = (col > 3'd0) ? r_up[3'd7 - (col - 3'd1)] : 1'b0;
    wire ur_pix = (col < 3'd7) ? r_up[3'd7 - (col + 3'd1)] : 1'b0;
    wire dl_pix = (col > 3'd0) ? r_dn[3'd7 - (col - 3'd1)] : 1'b0;
    wire dr_pix = (col < 3'd7) ? r_dn[3'd7 - (col + 3'd1)] : 1'b0;

    always @(posedge clk) begin
        pix_on     <= c_pix;
        outline_on <= (~c_pix) & (l_pix | r_pix | u_pix | d_pix | ul_pix | ur_pix | dl_pix | dr_pix);
    end

endmodule
