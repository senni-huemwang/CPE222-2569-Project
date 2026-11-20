`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: card_rom
// Description: Dual 48x48 12-bit RGB444 sprite ROM for ModeSelect cards:
//              sel=0 -> BirdPing (Classic), sel=1 -> BirdPeem (Attack).
//////////////////////////////////////////////////////////////////////////////////
module card_rom (
    input  wire        clk,
    input  wire        sel,     // 0=BirdPing, 1=BirdPeem
    input  wire [5:0]  x,       // 0..47
    input  wire [5:0]  y,       // 0..47
    output reg  [11:0] rgb_out
);
    localparam integer PIXELS = 48 * 48; // 2304
    (* rom_style = "block" *) reg [11:0] rom_ping [0:PIXELS-1];
    (* rom_style = "block" *) reg [11:0] rom_peem [0:PIXELS-1];

    initial begin
        $readmemh("card_ping.mem", rom_ping);
        $readmemh("card_peem.mem", rom_peem);
    end

    wire [11:0] addr = ({1'b0, y, 5'b00000}) + ({2'b00, y, 4'b0000}) + {6'd0, x};

    always @(posedge clk) begin
        if (sel) rgb_out <= rom_peem[addr];
        else     rgb_out <= rom_ping[addr];
    end

endmodule
