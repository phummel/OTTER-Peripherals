`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Cal Poly
// Engineer: Paul Hummel
//
// Create Date: 06/07/2018 06:00:59 PM
// Design Name:
// Module Name: vga_driver
// Project Name: OTTER VGA Framebuffer
// Target Devices: OTTER MCU on Basys3
// Description: VGA signal driver. Reads 8-bit RGB data and outputs appropriate
//              VGA signals (Rout, Gout, Bout) includeing horizontal and
//              vertical sync. Ideal clock input signal is 25.175 MHz, but can
//              work with 25 MHz clock input. The driver communicates with the
//              framebuffer memory to read RGB data by location using the row
//              and column outputs. The row and column will combine to form
//              the address of the ram8k_8 framebuffer. For VGA, the column
//              values that are valid are from 0 to 639, all other values
//              should be ignored. The row values that are valid are from
//              0 to 479 and all other values are ignored. To turn on a pixel
//              on the VGA monitor, some combination of red, green and blue
//              should be asserted before the rising edge of the clock.
//              Objects which are displayed on the monitor, assert their
//              combination of red, green and blue when they detect the row and
//              column values are within their range. For multiple objects
//              sharing a screen, they must be combined using logic to create
//              single red, green, and blue signals.
//
// Revision:
// Revision 0.01 - File Created
// Revision 0.10 - (Keefe Johnson) One-screen-pixel-delay issue corrected by
//                 changing the horizontal/vertical assignments to non-blocking so
//                 the data latched into the RGB/VS/HS output registers is based
//                 on the pre-clock-edge coordinates that the asynchronous memory
//                 used to lookup the data, and also removing the registers on
//                 ROW/COLUMN. Corresondingly reordered the code sections for
//                 clarity. Renamed the timing constants for clarity and revised
//                 their comments to match the terminology of common VGA timing
//                 websites (front vs back porches). Renamed clocks for clarity.
//                 Other minor style tweaks.
//////////////////////////////////////////////////////////////////////////////////

module vga_driver(
    input CLK_25MHz,
    input [3:0] RED,            // Color from previous ROW / COLUMN 
    input [3:0] GREEN,          // read from framebuffer memory
    input [3:0] BLUE,
    output logic [9:0] ROW,     // coords of next pixel to be displayed
    output logic [9:0] COLUMN,  // creates an address for the framebuffer
    output logic [3:0] ROUT,    // color at current pixel being displayed
    output logic [3:0] GOUT,
    output logic [3:0] BOUT,
    output logic HSYNC,         // horizontal and vertical sync signals
    output logic VSYNC
    );
    
    // values from 25 MHz VGA specifications
    const integer HW = 640;                // horizontal columns: 25.17 us
    const integer HF = 22;                 // front porch: 0.94 us
    const integer HS = 93;                 // horizontal sync pulse: 3.77 us
    const integer HB = 45;                 // back porch: 1.89 us
    const integer HC = HW + HF + HS + HB;  // one horizontal sync cycle: 31.77 us
    const integer VW = 480;                // vertical rows: 15.25 ms
    const integer VF = 11;                 // front porch: 0.35 ms
    const integer VS = 2;                  // vertical sync pulse: 64 us
    const integer VB = 32;                 // back porch: 1.02 ms
    const integer VC = VW + VF + VS + VB;  // one vertical sync cycle: 16.6 ms

    logic [9:0] horizontal = '0;  // holds up to HC - 1
    logic [9:0] vertical = '0;    // holds up to VC - 1

    assign ROW = vertical;
    assign COLUMN = horizontal;

    always_ff @(posedge CLK_25MHz) begin

        // define horizontal sync pulse
        if ((horizontal >= (HW + HF)) && (horizontal < (HW + HF + HS))) begin
            HSYNC <= 1'b0;
        end else begin
            HSYNC <= 1'b1;
        end
      
        // define vertical sync pulse
        if ((vertical >= (VW + VF)) && (vertical < (VW + VF + VS))) begin
            VSYNC <= 1'b0;
        end else begin
            VSYNC <= 1'b1;
        end
        
        // if in valid range displayed on screen, output pixel color data
        if ((horizontal < HW) && (vertical < VW)) begin
            ROUT <= RED;
            GOUT <= GREEN;
            BOUT <= BLUE;
        end else begin
            ROUT <= 3'b000;
            GOUT <= 3'b000;
            BOUT <= 2'b00;
        end
     
        // update counters
        if (horizontal < HC - 1) begin
            horizontal <= horizontal + 1;
        end else begin
            horizontal <= '0;
            if (vertical < VC - 1) begin
                vertical <= vertical + 1;
            end else begin
                vertical <= '0;
            end
        end

    end

endmodule
