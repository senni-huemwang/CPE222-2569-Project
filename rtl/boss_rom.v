`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: boss_rom
// Description: 48x48 12-bit RGB444 sprite BRAM ROM for the Chibi Student Boss.
//              12'hF0F represents transparent pixels.
//////////////////////////////////////////////////////////////////////////////////
module boss_rom (
    input  wire        clk,
    input  wire [5:0]  x,       // 0..47
    input  wire [5:0]  y,       // 0..47
    output reg  [11:0] rgb_out
);
    localparam integer SPRITE_PIXELS = 48 * 48; // 2304

    (* rom_style = "block" *) reg [11:0] rom_boss [0:SPRITE_PIXELS-1];

    initial begin
        $readmemh("boss_chibi.mem", rom_boss);
    end

    wire [11:0] addr = ({1'b0, y, 5'b00000}) + ({2'b00, y, 4'b0000}) + {6'd0, x};

    always @(posedge clk) begin
        rgb_out <= rom_boss[addr];
    end

endmodule
