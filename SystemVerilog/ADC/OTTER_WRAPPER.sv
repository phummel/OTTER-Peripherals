`timescale 1ns / 1ps
/////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: J. Calllenes
//           P. Hummel
// 
// Create Date: 01/20/2019 10:36:50 AM
// Module Name: OTTER_Wrapper
// Target Devices: OTTER MCU on Basys3
// Description: OTTER_WRAPPER with Switches, LEDs, and 7-segment display
//
// Revision:
// Revision 0.01 - File Created
// Revision 0.02 - Updated MMIO addresses (0x1100_0000 - 0x1100_FFFF)
/////////////////////////////////////////////////////////////////////////////

module OTTER_Wrapper(
   input CLK,
//   input BTNL,
   input BTNC,
   input ANALOG_POS,
   input ANALOG_NEG,
   input [15:0] SWITCHES,
   output logic [15:0] LEDS,
   output [7:0] CATHODES,
   output [3:0] ANODES
   );
       
   // INPUT PORT IDS ///////////////////////////////////////////////////////
   // Right now, the only possible inputs are the switches
   // In future labs you can add more MMIO, and you'll have
   // to add constants here for the mux below
   localparam SWITCHES_AD = 32'h11000000;
   localparam ADC_AD      = 32'h11000050; 
           
   // OUTPUT PORT IDS //////////////////////////////////////////////////////
   // In future labs you can add more MMIO
   localparam LEDS_AD     = 32'h11000020;
   localparam SSEG_AD     = 32'h11000040;
    
   // Signals for connecting OTTER_MCU to OTTER_wrapper /////////////////////
   logic s_reset,s_load;
   logic clk_50 = 0;        // initialize to 0 for simulation
    
   logic [15:0]  r_SSEG;
   logic [11:0]  s_adc;
     
   logic [31:0] IOBUS_out,IOBUS_in,IOBUS_addr;
   logic IOBUS_wr;
   
   
   // Declare OTTER_CPU ////////////////////////////////////////////////////
   CPU CPU(.CPU_RST(s_reset),.CPU_INTR(1'b0), .CPU_CLK(clk_50), 
                   .CPU_IOBUS_OUT(IOBUS_out),.CPU_IOBUS_IN(IOBUS_in),
                   .CPU_IOBUS_ADDR(IOBUS_addr),.CPU_IOBUS_WR(IOBUS_wr));

   // Declare Seven Segment Display /////////////////////////////////////////
   SevSegDisp SSG_DISP (.DATA_IN(r_SSEG), .CLK(CLK), .MODE(1'b1), // BCD mode
                       .CATHODES(CATHODES), .ANODES(ANODES));
   
   // Declare ADC Module
   ADC ADC(.CLK_100(CLK), .ANALOG_POS(ANALOG_POS), .ANALOG_NEG(ANALOG_NEG), 
           .ADC_VALUE(s_adc));
           
   // Clock Divider to create 50 MHz Clock //////////////////////////////////
   always_ff @(posedge CLK) begin
       clk_50 <= ~clk_50;
   end
   
   // Connect Signals ///////////////////////////////////////////////////////
   assign s_reset = BTNC;
   
   // Connect Board output peripherals (Memory Mapped IO devices) to IOBUS 
    always_ff @ (posedge clk_50) begin
        if(IOBUS_wr)
            case(IOBUS_addr)
                LEDS_AD: LEDS   <= IOBUS_out[15:0];    
                SSEG_AD: r_SSEG <= IOBUS_out[15:0];
            endcase
    end
   
   // Connect Board output peripherals (Memory Mapped IO devices) to IOBUS 
   always_comb begin
        case(IOBUS_addr)
            SWITCHES_AD: IOBUS_in = {16'b0,SWITCHES};
            ADC_AD:      IOBUS_in = {20'b0, s_adc};
            default:     IOBUS_in = 32'b0;    // default bus input to 0
        endcase
    end
   endmodule
