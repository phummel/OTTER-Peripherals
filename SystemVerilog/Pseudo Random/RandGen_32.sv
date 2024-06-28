`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Cal Poly
// Engineer: Paul Hummel
//
// Create Date: 06/27/2018 10:47:03 PM
// Module Name: RandGen
// Target Devices: OTTER MCU Peripheral
// Description: Implement a 32 bit linear feedback shift register to create a
//              uniform pseudo random number generator. CLK connected to 100 MHz
//              Basys3 system clock
// Revision:
// Revision 0.01 - File Created
// Revision 0.02 - Updated for 32-bit output for OTTER
// Revision 0.03 - fixes: sync reset, remove initial, non-blocking assignment
//////////////////////////////////////////////////////////////////////////////////


module RandGen(
    input CLK,
    input RST,
    output [31:0] RANDOM
    );
    
    // SEED value to create a longer sequence before repeating
    // see Xilinx xapp210 Documentation
    const logic [31:0] SEED = 32'h6B1CCA14;
    logic [31:0] r_random;
    logic s_feedback;
   
    // taps at bits 32,22,2,1 (Xilinx xapp210 Documentation)
    assign s_feedback = ~(r_random[31] ^ r_random[21] ^ r_random[1] ^ r_random[0]);
    assign RANDOM = r_random;
      
    always_ff @(posedge CLK) begin
        if (RST == 1'b1)                            // reset to SEED value
            r_random <= SEED;
        else
            r_random <= {r_random[30:0],s_feedback}; // shift with feedback
    end
    
endmodule
