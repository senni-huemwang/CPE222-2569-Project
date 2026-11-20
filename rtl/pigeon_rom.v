`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: pigeon_rom
// Description: Dual-frame 64x64 12-bit RGB444 sprite BRAM ROM for BirdPlayer.
//              12'hF0F represents transparent pixels.
//////////////////////////////////////////////////////////////////////////////////
module pigeon_rom (
    input  wire        clk,
    input  wire        pose,       // 0 = dive, 1 = flap
    input  wire [5:0]  x,          // 0..63
    input  wire [5:0]  y,          // 0..63
    output reg  [11:0] rgb_out
);
    localparam integer SPRITE_PIXELS = 64 * 64; // 4096

    (* rom_style = "block" *) reg [11:0] rom_down [0:SPRITE_PIXELS-1];
    (* rom_style = "block" *) reg [11:0] rom_up   [0:SPRITE_PIXELS-1];

    initial begin
        $readmemh("pigeon_down.mem", rom_down);
        $readmemh("pigeon_up.mem",   rom_up);
    end

    wire [11:0] addr = {y, x};

    always @(posedge clk) begin
        if (pose) rgb_out <= rom_up[addr];
        else      rgb_out <= rom_down[addr];
    end

endmodule
