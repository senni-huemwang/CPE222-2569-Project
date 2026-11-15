`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: font_rom
// Description: Synchronous 8x8 pixel bitmap font ROM (ASCII subset: 0-9, A-Z,
//              space, '-', '/', ':', '!'). MSB (bit 7) is leftmost pixel (x=0).
//////////////////////////////////////////////////////////////////////////////////
module font_rom (
    input  wire       clk,
    input  wire [6:0] char_code,
    input  wire [2:0] row,        // 0..7
    input  wire [2:0] col,        // 0..7
    output reg        pix_on
);
    reg [7:0] row_data;

    always @(*) begin
        row_data = 8'h00;
        case (char_code)
            // Space ' ' (0x20)
            7'h20: row_data = 8'h00;
            // '!' (0x21)
            7'h21: case (row)
                3'd0: row_data = 8'h18; 3'd1: row_data = 8'h18;
                3'd2: row_data = 8'h18; 3'd3: row_data = 8'h18;
                3'd4: row_data = 8'h18; 3'd5: row_data = 8'h00;
                3'd6: row_data = 8'h18; 3'd7: row_data = 8'h00;
            endcase
            // '-' (0x2D)
            7'h2D: case (row)
                3'd3: row_data = 8'h7E;
                default: row_data = 8'h00;
            endcase
            // '/' (0x2F)
            7'h2F: case (row)
                3'd0: row_data = 8'h06; 3'd1: row_data = 8'h0C;
                3'd2: row_data = 8'h18; 3'd3: row_data = 8'h30;
                3'd4: row_data = 8'h60; 3'd5: row_data = 8'hC0;
                default: row_data = 8'h00;
            endcase
            // ':' (0x3A)
            7'h3A: case (row)
                3'd2: row_data = 8'h18; 3'd5: row_data = 8'h18;
                default: row_data = 8'h00;
            endcase
            // Digits '0'-'9'
            7'h30: case (row) // 0
                3'd0: row_data = 8'h3C; 3'd1: row_data = 8'h66;
                3'd2: row_data = 8'h6E; 3'd3: row_data = 8'h76;
                3'd4: row_data = 8'h66; 3'd5: row_data = 8'h66;
                3'd6: row_data = 8'h3C; default: row_data = 8'h00;
            endcase
            7'h31: case (row) // 1
                3'd0: row_data = 8'h18; 3'd1: row_data = 8'h38;
                3'd2: row_data = 8'h18; 3'd3: row_data = 8'h18;
                3'd4: row_data = 8'h18; 3'd5: row_data = 8'h18;
                3'd6: row_data = 8'h7E; default: row_data = 8'h00;
            endcase
            7'h32: case (row) // 2
                3'd0: row_data = 8'h3C; 3'd1: row_data = 8'h66;
                3'd2: row_data = 8'h06; 3'd3: row_data = 8'h1C;
                3'd4: row_data = 8'h30; 3'd5: row_data = 8'h60;
                3'd6: row_data = 8'h7E; default: row_data = 8'h00;
            endcase
            7'h33: case (row) // 3
                3'd0: row_data = 8'h3C; 3'd1: row_data = 8'h66;
                3'd2: row_data = 8'h06; 3'd3: row_data = 8'h1C;
                3'd4: row_data = 8'h06; 3'd5: row_data = 8'h66;
                3'd6: row_data = 8'h3C; default: row_data = 8'h00;
            endcase
            7'h34: case (row) // 4
                3'd0: row_data = 8'h0C; 3'd1: row_data = 8'h1C;
                3'd2: row_data = 8'h3C; 3'd3: row_data = 8'h6C;
                3'd4: row_data = 8'h7E; 3'd5: row_data = 8'h0C;
                3'd6: row_data = 8'h0C; default: row_data = 8'h00;
            endcase
            7'h35: case (row) // 5
                3'd0: row_data = 8'h7E; 3'd1: row_data = 8'h60;
                3'd2: row_data = 8'h7C; 3'd3: row_data = 8'h06;
                3'd4: row_data = 8'h06; 3'd5: row_data = 8'h66;
                3'd6: row_data = 8'h3C; default: row_data = 8'h00;
            endcase
            7'h36: case (row) // 6
                3'd0: row_data = 8'h3C; 3'd1: row_data = 8'h60;
                3'd2: row_data = 8'h60; 3'd3: row_data = 8'h7C;
                3'd4: row_data = 8'h66; 3'd5: row_data = 8'h66;
                3'd6: row_data = 8'h3C; default: row_data = 8'h00;
            endcase
            7'h37: case (row) // 7
                3'd0: row_data = 8'h7E; 3'd1: row_data = 8'h66;
                3'd2: row_data = 8'h0C; 3'd3: row_data = 8'h18;
                3'd4: row_data = 8'h18; 3'd5: row_data = 8'h18;
                3'd6: row_data = 8'h18; default: row_data = 8'h00;
            endcase
            7'h38: case (row) // 8
                3'd0: row_data = 8'h3C; 3'd1: row_data = 8'h66;
                3'd2: row_data = 8'h66; 3'd3: row_data = 8'h3C;
                3'd4: row_data = 8'h66; 3'd5: row_data = 8'h66;
                3'd6: row_data = 8'h3C; default: row_data = 8'h00;
            endcase
            7'h39: case (row) // 9
                3'd0: row_data = 8'h3C; 3'd1: row_data = 8'h66;
                3'd2: row_data = 8'h66; 3'd3: row_data = 8'h3E;
                3'd4: row_data = 8'h06; 3'd5: row_data = 8'h06;
                3'd6: row_data = 8'h3C; default: row_data = 8'h00;
            endcase
            // Letters A-Z
            7'h41: case (row) // A
                3'd0: row_data = 8'h18; 3'd1: row_data = 8'h3C;
                3'd2: row_data = 8'h66; 3'd3: row_data = 8'h66;
                3'd4: row_data = 8'h7E; 3'd5: row_data = 8'h66;
                3'd6: row_data = 8'h66; default: row_data = 8'h00;
            endcase
            7'h42: case (row) // B
                3'd0: row_data = 8'h7C; 3'd1: row_data = 8'h66;
                3'd2: row_data = 8'h66; 3'd3: row_data = 8'h7C;
                3'd4: row_data = 8'h66; 3'd5: row_data = 8'h66;
                3'd6: row_data = 8'h7C; default: row_data = 8'h00;
            endcase
            7'h43: case (row) // C
                3'd0: row_data = 8'h3C; 3'd1: row_data = 8'h66;
                3'd2: row_data = 8'h60; 3'd3: row_data = 8'h60;
                3'd4: row_data = 8'h60; 3'd5: row_data = 8'h66;
                3'd6: row_data = 8'h3C; default: row_data = 8'h00;
            endcase
            7'h44: case (row) // D
                3'd0: row_data = 8'h78; 3'd1: row_data = 8'h6C;
                3'd2: row_data = 8'h66; 3'd3: row_data = 8'h66;
                3'd4: row_data = 8'h66; 3'd5: row_data = 8'h6C;
                3'd6: row_data = 8'h78; default: row_data = 8'h00;
            endcase
            7'h45: case (row) // E
                3'd0: row_data = 8'h7E; 3'd1: row_data = 8'h60;
                3'd2: row_data = 8'h60; 3'd3: row_data = 8'h78;
                3'd4: row_data = 8'h60; 3'd5: row_data = 8'h60;
                3'd6: row_data = 8'h7E; default: row_data = 8'h00;
            endcase
            7'h46: case (row) // F
                3'd0: row_data = 8'h7E; 3'd1: row_data = 8'h60;
                3'd2: row_data = 8'h60; 3'd3: row_data = 8'h78;
                3'd4: row_data = 8'h60; 3'd5: row_data = 8'h60;
                3'd6: row_data = 8'h60; default: row_data = 8'h00;
            endcase
            7'h47: case (row) // G
                3'd0: row_data = 8'h3C; 3'd1: row_data = 8'h66;
                3'd2: row_data = 8'h60; 3'd3: row_data = 8'h6E;
                3'd4: row_data = 8'h66; 3'd5: row_data = 8'h66;
                3'd6: row_data = 8'h3E; default: row_data = 8'h00;
            endcase
            7'h48: case (row) // H
                3'd0: row_data = 8'h66; 3'd1: row_data = 8'h66;
                3'd2: row_data = 8'h66; 3'd3: row_data = 8'h7E;
                3'd4: row_data = 8'h66; 3'd5: row_data = 8'h66;
                3'd6: row_data = 8'h66; default: row_data = 8'h00;
            endcase
            7'h49: case (row) // I
                3'd0: row_data = 8'h3C; 3'd1: row_data = 8'h18;
                3'd2: row_data = 8'h18; 3'd3: row_data = 8'h18;
                3'd4: row_data = 8'h18; 3'd5: row_data = 8'h18;
                3'd6: row_data = 8'h3C; default: row_data = 8'h00;
            endcase
            7'h4A: case (row) // J
                3'd0: row_data = 8'h1E; 3'd1: row_data = 8'h0C;
                3'd2: row_data = 8'h0C; 3'd3: row_data = 8'h0C;
                3'd4: row_data = 8'h6C; 3'd5: row_data = 8'h6C;
                3'd6: row_data = 8'h38; default: row_data = 8'h00;
            endcase
            7'h4B: case (row) // K
                3'd0: row_data = 8'h66; 3'd1: row_data = 8'h6C;
                3'd2: row_data = 8'h78; 3'd3: row_data = 8'h70;
                3'd4: row_data = 8'h78; 3'd5: row_data = 8'h6C;
                3'd6: row_data = 8'h66; default: row_data = 8'h00;
            endcase
            7'h4C: case (row) // L
                3'd0: row_data = 8'h60; 3'd1: row_data = 8'h60;
                3'd2: row_data = 8'h60; 3'd3: row_data = 8'h60;
                3'd4: row_data = 8'h60; 3'd5: row_data = 8'h60;
                3'd6: row_data = 8'h7E; default: row_data = 8'h00;
            endcase
            7'h4D: case (row) // M
                3'd0: row_data = 8'h63; 3'd1: row_data = 8'h77;
                3'd2: row_data = 8'h7F; 3'd3: row_data = 8'h6B;
                3'd4: row_data = 8'h63; 3'd5: row_data = 8'h63;
                3'd6: row_data = 8'h63; default: row_data = 8'h00;
            endcase
            7'h4E: case (row) // N
                3'd0: row_data = 8'h66; 3'd1: row_data = 8'h76;
                3'd2: row_data = 8'h7E; 3'd3: row_data = 8'h7E;
                3'd4: row_data = 8'h6E; 3'd5: row_data = 8'h66;
                3'd6: row_data = 8'h66; default: row_data = 8'h00;
            endcase
            7'h4F: case (row) // O
                3'd0: row_data = 8'h3C; 3'd1: row_data = 8'h66;
                3'd2: row_data = 8'h66; 3'd3: row_data = 8'h66;
                3'd4: row_data = 8'h66; 3'd5: row_data = 8'h66;
                3'd6: row_data = 8'h3C; default: row_data = 8'h00;
            endcase
            7'h50: case (row) // P
                3'd0: row_data = 8'h7C; 3'd1: row_data = 8'h66;
                3'd2: row_data = 8'h66; 3'd3: row_data = 8'h7C;
                3'd4: row_data = 8'h60; 3'd5: row_data = 8'h60;
                3'd6: row_data = 8'h60; default: row_data = 8'h00;
            endcase
            7'h51: case (row) // Q
                3'd0: row_data = 8'h3C; 3'd1: row_data = 8'h66;
                3'd2: row_data = 8'h66; 3'd3: row_data = 8'h66;
                3'd4: row_data = 8'h6A; 3'd5: row_data = 8'h6C;
                3'd6: row_data = 8'h36; default: row_data = 8'h00;
            endcase
            7'h52: case (row) // R
                3'd0: row_data = 8'h7C; 3'd1: row_data = 8'h66;
                3'd2: row_data = 8'h66; 3'd3: row_data = 8'h7C;
                3'd4: row_data = 8'h6C; 3'd5: row_data = 8'h66;
                3'd6: row_data = 8'h66; default: row_data = 8'h00;
            endcase
            7'h53: case (row) // S
                3'd0: row_data = 8'h3C; 3'd1: row_data = 8'h66;
                3'd2: row_data = 8'h60; 3'd3: row_data = 8'h3C;
                3'd4: row_data = 8'h06; 3'd5: row_data = 8'h66;
                3'd6: row_data = 8'h3C; default: row_data = 8'h00;
            endcase
            7'h54: case (row) // T
                3'd0: row_data = 8'h7E; 3'd1: row_data = 8'h18;
                3'd2: row_data = 8'h18; 3'd3: row_data = 8'h18;
                3'd4: row_data = 8'h18; 3'd5: row_data = 8'h18;
                3'd6: row_data = 8'h18; default: row_data = 8'h00;
            endcase
            7'h55: case (row) // U
                3'd0: row_data = 8'h66; 3'd1: row_data = 8'h66;
                3'd2: row_data = 8'h66; 3'd3: row_data = 8'h66;
                3'd4: row_data = 8'h66; 3'd5: row_data = 8'h66;
                3'd6: row_data = 8'h3C; default: row_data = 8'h00;
            endcase
            7'h56: case (row) // V
                3'd0: row_data = 8'h66; 3'd1: row_data = 8'h66;
                3'd2: row_data = 8'h66; 3'd3: row_data = 8'h66;
                3'd4: row_data = 8'h66; 3'd5: row_data = 8'h3C;
                3'd6: row_data = 8'h18; default: row_data = 8'h00;
            endcase
            7'h57: case (row) // W
                3'd0: row_data = 8'h63; 3'd1: row_data = 8'h63;
                3'd2: row_data = 8'h63; 3'd3: row_data = 8'h6B;
                3'd4: row_data = 8'h7F; 3'd5: row_data = 8'h77;
                3'd6: row_data = 8'h63; default: row_data = 8'h00;
            endcase
            7'h58: case (row) // X
                3'd0: row_data = 8'h66; 3'd1: row_data = 8'h66;
                3'd2: row_data = 8'h3C; 3'd3: row_data = 8'h18;
                3'd4: row_data = 8'h3C; 3'd5: row_data = 8'h66;
                3'd6: row_data = 8'h66; default: row_data = 8'h00;
            endcase
            7'h59: case (row) // Y
                3'd0: row_data = 8'h66; 3'd1: row_data = 8'h66;
                3'd2: row_data = 8'h66; 3'd3: row_data = 8'h3C;
                3'd4: row_data = 8'h18; 3'd5: row_data = 8'h18;
                3'd6: row_data = 8'h18; default: row_data = 8'h00;
            endcase
            7'h5A: case (row) // Z
                3'd0: row_data = 8'h7E; 3'd1: row_data = 8'h06;
                3'd2: row_data = 8'h0C; 3'd3: row_data = 8'h18;
                3'd4: row_data = 8'h30; 3'd5: row_data = 8'h60;
                3'd6: row_data = 8'h7E; default: row_data = 8'h00;
            endcase
            default: row_data = 8'h00;
        endcase
    end

    always @(posedge clk) begin
        pix_on <= row_data[3'd7 - col];
    end

endmodule
