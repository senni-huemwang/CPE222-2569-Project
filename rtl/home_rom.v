`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: home_rom
// Description: 160x120 12-bit RGB444 BRAM ROM for the HomePage background
//              (scaled 4x to 640x480 on VGA).
//////////////////////////////////////////////////////////////////////////////////
module home_rom (
    input  wire        clk,
    input  wire [7:0]  x,       // 0..159
    input  wire [6:0]  y,       // 0..119
    output reg  [11:0] rgb_out
);
    localparam integer PIXELS = 160 * 120; // 19200
    (* rom_style = "block" *) reg [11:0] rom_home [0:PIXELS-1];

    initial begin
        $readmemh("home_bg.mem", rom_home);
    end

    // addr = y * 160 + x = (y * 128) + (y * 32) + x
    wire [14:0] addr = ({1'b0, y, 7'b0000000}) + ({3'b000, y, 5'b00000}) + {7'd0, x};

    always @(posedge clk) begin
        rgb_out <= rom_home[addr];
    end

endmodule
