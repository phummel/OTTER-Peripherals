`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Cal Poly
// Engineer: Paul Hummel
//
// Create Date: 06/07/2018 06:00:59 PM
// Design Name:
// Module Name: ram8k_8_80x60
// Project Name: VGA 80x60
// Target Devices: OTTER MCU on Basys3
// Description: Framebuffer memory for VGA driver.
//              3 port memory, 2 for reading, 1 for writing
//              WA1 - first address for reading and writing,
//                    output is RD1, input is WD
//              WE  - write enable, only save data (WD to WA1) when high
//              RA2 - first address only for reading, output is RD2
//
// Revision:
// Revision 0.01 - File Created
// Revision 0.10 - (Keefe Johnson) Renamed clock for clarity. Other minor style
//                 tweaks.
//////////////////////////////////////////////////////////////////////////////////

module ram8k_8_80x60(
    input CLK_50MHz,
    input WE,           // write enable
    input [12:0] WA1,   // write address 1
    input [12:0] RA2,   // read address 2
    input [7:0] WD,     // write data to address 1
    output [7:0] RD1,   // read data from address 1
    output [7:0] RD2    // read data from address 2
    );
    
    logic [7:0] r_memory [7631:0];  // 128 * 60 - (128 - 80)
    
    // Initialize all memory to 0s
    initial begin
        int i;
        for (i = 0; i < 7632; i++) begin
            r_memory[i] = 8'h00;
        end
    end
    
    // only save data on rising edge
    always_ff @(posedge CLK_50MHz) begin
        if (WE) begin
            r_memory[WA1] <= WD;
        end
    end
    
    assign RD2 = r_memory[RA2];
    assign RD1 = r_memory[WA1];
    
endmodule
