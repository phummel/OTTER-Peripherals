`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Cal Poly
// Engineer: Paul Hummel
//
// Create Date: 06/07/2018 06:00:59 PM
// Design Name:
// Module Name: ram75k_12
// Project Name: OTTER VGA Framebuffer
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
// Revision 0.20 - Expand to 160x120 and 12-bit color
// Revision 0.30 - Expand to 320x240 with better memory utilization
//               - Create possible initialization with memory (mem) file
//////////////////////////////////////////////////////////////////////////////////

module ram75k_12(
    input CLK_50MHz,
    input WE,                   // write enable
    input [16:0] WA1,           // write address 1
    input [16:0] RA2,           // read address 2
    input [11:0] WD,            // write data to address 1
    output logic [11:0] RD1,    // read data from address 1
    output logic [11:0] RD2     // read data from address 2
    );
    
    // 320 x 240 = 76800 (75k)
    // force BRAM utilization
    (* rom_style="{distributed | block}" *)
    (* ram_decomp = "power" *) logic [11:0] r_memory [0:76799];
    
    // Initialization of BRAM is possible with a mem file. Otherwise the memory will
    // be initialized to all 0s
    /*
     * initial begin
     *     $readmemh("vga_init.mem", r_memory, 0, 76799);
     * end
     */
    
    // only save data on rising edge
    always_ff @(posedge CLK_50MHz) begin
        if (WE) begin
            r_memory[WA1] <= WD;
        end
        
        // make reading synchronous for using BRAM
        RD2 <= r_memory[RA2];
        RD1 <= r_memory[WA1];

    end
    
endmodule
