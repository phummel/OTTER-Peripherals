`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: J. Calllenes
//           P. Hummel
//
// Create Date: 01/20/2019 10:36:50 AM
// Design Name:
// Module Name: OTTER_Wrapper
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
///////////////////////////////////////////////////////////////////////////////
module OTTER_Wrapper(
   input CLK,
   input BTNC,
   input [15:0] SWITCHES,
   input PS2Clk,
   input PS2Data,
   output logic [15:0] LEDS,
   output [7:0] CATHODES,
   output [3:0] ANODES
   );
        

    // INPUT PORT IDS /////////////////////////////////////////////////////////
    // Right now, the only possible inputs are the switches
    // In future labs you can add more MMIO, and you'll have
    // to add constants here for the mux below
    localparam SWITCHES_AD = 32'h11000000;
           
    // OUTPUT PORT IDS ////////////////////////////////////////////////////////
    // In future labs you can add more MMIO
    localparam LEDS_AD      = 32'h11000020;
    localparam SSEG_AD      = 32'h11000040;
    localparam KEYBOARD_AD  = 32'h11000100;
    
   // Signals for connecting OTTER_MCU to OTTER_wrapper ///////////////////////
   logic [31:0] IOBUS_out,IOBUS_in,IOBUS_addr;
   logic IOBUS_wr;
   
   logic s_interrupt, keyboard_int, btn_int;
   logic s_reset;
   logic clk_50 = 1'b0;
   
   logic [15:0]  r_SSEG;

   // Signals for keyboard
   logic [7:0] s_scancode;
   
   // Connect Signals /////////////////////////////////////////////////////////
   assign s_reset = BTNC;
   assign s_interrupt = keyboard_int;
   
   // Clock Divider to create 50 MHz Clock ////////////////////////////////////
   always_ff @(posedge CLK) begin
       clk_50 <= ~clk_50;
   end

   // Declare OTTER_CPU ///////////////////////////////////////////////////////
   OTTER_MCU MCU (.RESET(s_reset),.INTR(s_interrupt), .CLK(clk_50),
                   .IOBUS_OUT(IOBUS_out),.IOBUS_IN(IOBUS_in),
                   .IOBUS_ADDR(IOBUS_addr),.IOBUS_WR(IOBUS_wr));

   // Declare Seven Segment Display ///////////////////////////////////////////
   SevSegDisp SSG_DISP (.DATA_IN(r_SSEG), .CLK(CLK), .MODE(1'b0),
                       .CATHODES(CATHODES), .ANODES(ANODES));
   
   // Declare Keyboard Driver /////////////////////////////////////////////////
   KeyboardDriver KEYBD (.CLK(CLK), .PS2DATA(PS2Data), .PS2CLK(PS2Clk),
                          .INTRPT(keyboard_int), .SCANCODE(s_scancode));

                          
   // Connect Board peripherals (Memory Mapped IO devices) to IOBUS ///////////
   // Ouput MUX and Registers
    always_ff @ (posedge clk_50)
    begin
        if(IOBUS_wr)
            case(IOBUS_addr)
                LEDS_AD: LEDS <= IOBUS_out[15:0];
                SSEG_AD: r_SSEG <= IOBUS_out[15:0];
            endcase
    end
    
    // Input MUX
    always_comb
    begin
        case(IOBUS_addr)
            SWITCHES_AD: IOBUS_in = {16'b0,SWITCHES};
            KEYBOARD_AD: IOBUS_in = {24'b0, s_scancode};
            default: IOBUS_in = 32'b0;
        endcase
    end
   endmodule
