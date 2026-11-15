`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: pigeon_rom
// Description: Dual-frame 48x48 12-bit RGB444 sprite ROM for the Pixel Pigeon AI.
//              12'hF0F represents transparent pixels.
//////////////////////////////////////////////////////////////////////////////////
module pigeon_rom (
    input  wire        clk,
    input  wire        pose,       // 0 = dive/wings-down, 1 = flap/wings-up
    input  wire [5:0]  x,          // 0..47
    input  wire [5:0]  y,          // 0..47
    output reg  [11:0] rgb_out
);
    localparam integer SPRITE_PIXELS = 48 * 48; // 2304

    (* rom_style = "block" *) reg [11:0] rom_down [0:SPRITE_PIXELS-1];
    (* rom_style = "block" *) reg [11:0] rom_up   [0:SPRITE_PIXELS-1];

    initial begin
        $readmemh("pigeon_down.mem", rom_down);
        $readmemh("pigeon_up.mem",   rom_up);
    end

    // addr = y * 48 + x = (y * 32) + (y * 16) + x (shift-add, no DSP needed)
    wire [11:0] addr = ({1'b0, y, 5'b00000}) + ({2'b00, y, 4'b0000}) + {6'd0, x};

    always @(posedge clk) begin
        if (pose) begin
            rgb_out <= rom_up[addr];
        end else begin
            rgb_out <= rom_down[addr];
        end
    end

endmodule
