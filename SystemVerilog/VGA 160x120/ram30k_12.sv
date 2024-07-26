`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Cal Poly
// Engineer: Paul Hummel
//
// Create Date: 06/07/2018 06:00:59 PM
// Design Name:
// Module Name: ram30k_12
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
//////////////////////////////////////////////////////////////////////////////////

module ram30k_12(
    input CLK_50MHz,
    input WE,                   // write enable
    input [14:0] WA1,           // write address 1
    input [14:0] RA2,           // read address 2
    input [11:0] WD,            // write data to address 1
    output logic [11:0] RD1,    // read data from address 1
    output logic [11:0] RD2     // read data from address 2
    );
    
    // force BRAM utilization
    (* rom_style="{distributed | block}" *)
    (* ram_decomp = "power" *) logic [11:0] r_memory [0:30623];
    
    // 80 x 60 --> 128 x 60 - (128 - 80)
    // 7-bit column, 6-bit row
    // logic [11:0] r_memory [7631:0];  
    
    // 160 x 120 --> 256 x 120 - (256 - 160)
    // 8-bit column, 7-bit row
    // logic [11:0] r_memory [30623:0]
    
    // 320 x 240 --> 512 x 240 - (512 - 320)
    // 9-bit column, 8-bit row 
    // logic [11:0] [122687:0]
    
    // 640 X 480 --> 1024 X 480 - (1024 - 640)
    // 10-bit column, 9-bit row
    // [491135:0]    
    
    // Initialize all memory to 0s
    initial begin
        int i;
        for (i = 0; i < 30624; i++) begin
            r_memory[i] = 12'b0;
        end
    end
    
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
