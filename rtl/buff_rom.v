`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: buff_rom
// Description: 24x24 12-bit RGB444 sprite ROM for Boss_TA head buff.
//////////////////////////////////////////////////////////////////////////////////
module buff_rom (
    input  wire        clk,
    input  wire [4:0]  x,       // 0..23
    input  wire [4:0]  y,       // 0..23
    output reg  [11:0] rgb_out
);
    localparam integer PIXELS = 24 * 24; // 576
    (* rom_style = "block" *) reg [11:0] rom_buff [0:PIXELS-1];

    initial begin
        $readmemh("buff_head.mem", rom_buff);
    end

    // addr = y * 24 + x = (y * 16) + (y * 8) + x
    wire [9:0] addr = ({1'b0, y, 4'b0000}) + ({2'b00, y, 3'b000}) + {5'd0, x};

    always @(posedge clk) begin
        rgb_out <= rom_buff[addr];
    end

endmodule
