`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Cal Poly
// Engineer: Paul Hummel
//
// Create Date: 06/07/2018 06:00:59 PM
// Design Name:
// Module Name: vga_fb_driver
// Project Name: OTTER VGA Framebuffer
// Target Devices: OTTER MCU on Basys3
// Description: VGA framebuffer interface driver for the the OTTER MCU. Creates
//              30k x 12 framebuffer, control input interfaces (WA, WD, WE, RD),
//              and VGA output signals (ROUT, GOUT, BOUT, HS, VS).
//
// Revision:
// Revision 0.01 - File Created
// Revision 0.10 - (Keefe Johnson) Renamed clocks for clarity. Other minor style
//                 tweaks.
// Revsion  0.20 - Update for 160x120 resolution and 12-bit color
//////////////////////////////////////////////////////////////////////////////////

module VGA_FB_Driver(
    input CLK_50MHz,
    input [14:0] WA,
    input [11:0] WD,
    input WE,
    output [11:0] RD,
    output [3:0] ROUT,
    output [3:0] GOUT,
    output [3:0] BOUT,
    output HS,
    output VS
    );
    
    logic CLK_25MHz = 0;
    logic [11:0] s_fb_rd;
    logic [14:0] s_fb_ra;
    logic [3:0] s_vga_red;
    logic [3:0] s_vga_green;
    logic [3:0] s_vga_blue;
    logic [9:0] s_vga_row;
    logic [9:0] s_vga_col;
    
    // divide by 2 clock divider to create 25 MHz clock
    always_ff @(posedge CLK_50MHz) begin
        CLK_25MHz <= ~CLK_25MHz;
    end

    // VGA output
    vga_driver vga_out(.CLK_25MHz(CLK_25MHz), .RED(s_vga_red),
                             .GREEN(s_vga_green), .BLUE(s_vga_blue),
                             .ROW(s_vga_row), .COLUMN(s_vga_col), .ROUT(ROUT),
                             .GOUT(GOUT), .BOUT(BOUT), .HSYNC(HS), .VSYNC(VS));
    
    // Framebuffer
    ram30k_12 framebuffer(.CLK_50MHz(CLK_50MHz), .WE(WE), .RA2(s_fb_ra),
                              .WA1(WA), .WD(WD), .RD2(s_fb_rd), .RD1(RD));
    
    // combine row and column from the vga_driver to create read address RA2
    // for the framebuffer which returns color data as RD2
    // drop LSBs to scale smaller resolution framebuffer to 640x480 VGA output
    assign s_fb_ra = {s_vga_row[8:2], s_vga_col[9:2]};  // MSB of row not needed
    
    // divide the color data from the framebuffer into individual RGB values
    // for the vga_driver
    assign s_vga_red   = s_fb_rd[11:8];
    assign s_vga_green = s_fb_rd[7:4];
    assign s_vga_blue  = s_fb_rd[3:0];

endmodule
