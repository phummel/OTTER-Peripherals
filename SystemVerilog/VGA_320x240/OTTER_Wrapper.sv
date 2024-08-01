`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: J. Calllenes
//           P. Hummel
// 
// Create Date: 01/20/2019 10:36:50 AM
// Module Name: OTTER_Wrapper 
// Project Name: OTTER_VGA
// Target Devices: Basys3 
// Tool Versions: Xilinx Vivado 2024.1
// Description: Wrapper to connect OTTER CPU core to Basys3 board peripherals
//              16 LEDs, 16 Switches, 4 buttons, 4 digit Seven Segment Display
//              12-bit color VGA port
// 
// Revision:
// Revision 0.01 - File Created
//////////////////////////////////////////////////////////////////////////////////

module OTTER_Wrapper(
   input CLK,
   input BTNL,
   input BTNC,
   input [15:0] SWITCHES,
   output logic [15:0] LEDS,
   output [7:0] CATHODES,
   output [3:0] ANODES,
   output [11:0] VGA_RGB,
   output VGA_HS,
   output VGA_VS
   );
        
    // INPUT PORT IDS ////////////////////////////////////////////////////////
    // Right now, the only possible inputs are the switches
    // In future labs you can add more MMIO, and you'll have
    // to add constants here for the mux below
    localparam SWITCHES_AD = 32'h11000000;
    localparam VGA_READ_AD = 32'h11000160;
           
    // OUTPUT PORT IDS ///////////////////////////////////////////////////////
    // In future labs you can add more MMIO
    localparam LEDS_AD      = 32'h11000020;
    localparam SSEG_AD      = 32'h11000040;
    localparam VGA_ADDR_AD  = 32'h11000120;
    localparam VGA_COLOR_AD = 32'h11000140; 
    
   // Signals for connecting OTTER_MCU to OTTER_wrapper /////////////////////////
   logic s_reset, s_interrupt;
   logic clk_50 = 1'b0;
   logic [31:0] IOBUS_out,IOBUS_in,IOBUS_addr;
   logic IOBUS_wr;
   
   // Signals for connecting VGA Framebuffer Driver
   logic r_vga_we;             // write enable
   logic [16:0] r_vga_wa;      // address of framebuffer to read and write
   logic [11:0] r_vga_wd;      // pixel color data to write to framebuffer
   logic [11:0] r_vga_rd;      // pixel color data read from framebuffer
 
   logic [15:0]  r_SSEG;
   
   // Connect Signals ////////////////////////////////////////////////////////////
   assign s_reset = BTNC;
   
   // Declare OTTER_CPU ///////////////////////////////////////////////////////
   OTTER_CPU CPU (.CPU_RST(s_reset), .CPU_INTR(s_interrupt), .CPU_CLK(clk_50),
                   .CPU_IOBUS_OUT(IOBUS_out), .CPU_IOBUS_IN(IOBUS_in),
                   .CPU_IOBUS_ADDR(IOBUS_addr), .CPU_IOBUS_WR(IOBUS_wr));

   // Declare Seven Segment Display /////////////////////////////////////////
   SevSegDisp SSG_DISP (.DATA_IN(r_SSEG), .CLK(CLK), .MODE(1'b0),
                       .CATHODES(CATHODES), .ANODES(ANODES));
   
   // Testing New Debouncer (DB_BTN unused)
   Debouncer DOS(.CLK_50(clk_50), .RST(s_reset), .BTN(BTNL), .OneShot(s_interrupt));
   
   // Declare VGA Frame Buffer //////////////////////////////////////////////
   VGA_FB_Driver VGA(.CLK_50MHz(clk_50), .WA(r_vga_wa), .WD(r_vga_wd),
                     .WE(r_vga_we), .RD(r_vga_rd), .ROUT(VGA_RGB[11:8]),
                     .GOUT(VGA_RGB[7:4]), .BOUT(VGA_RGB[3:0]),
                     .HS(VGA_HS), .VS(VGA_VS));
 
   // Clock Divider to create 50 MHz Clock /////////////////////////////////
   always_ff @(posedge CLK) begin
       clk_50 <= ~clk_50;
   end

   // Connect Board peripherals (Memory Mapped IO devices) to IOBUS /////////////////////////////////////////
   always_ff @ (posedge clk_50) begin
        r_vga_we<=0;       
        if(IOBUS_wr)
            case(IOBUS_addr)
                LEDS_AD: LEDS <= IOBUS_out[15:0];    
                SSEG_AD: r_SSEG <= IOBUS_out[15:0];
                VGA_ADDR_AD: r_vga_wa <= IOBUS_out[16:0];
                VGA_COLOR_AD: begin  
                        r_vga_wd <= IOBUS_out[11:0];
                        r_vga_we <= 1;  
                    end     
            endcase
    end
    
    always_comb begin
        case(IOBUS_addr)
            SWITCHES_AD: IOBUS_in = {16'b0, SWITCHES};
            VGA_READ_AD: IOBUS_in = {20'b0, r_vga_rd};
            default: IOBUS_in = 32'b0;
        endcase
    end
   endmodule

