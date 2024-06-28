`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Cal Poly
// Engineer: Paul Hummel
//
// Create Date: 06/29/2018 12:58:25 AM
// Design Name: Seven Segment Display Driver
// Module Name: SevSegDisp
// Target Devices: OTTER MCU on Basys3
// Description: 7 Segment Display Driver with a 16-bit input and 4 character
//              display. The input is assumed to be unsigned and  can be
//              displayed as hex or decimal. The BCD converts the 16-bit
//              input into binary coded decimal of 4 digits, giving a
//              maximum value of 9999. This is below the maximum value of a
//              16-bit input (65,535).
//
//              7 segment configuration for cathodes and anodes
//              CATHODES = {dp,a,b,c,d,e,f,g}
//              ANODES = {d4, d3, d2, d1}
//
// Revision:
// Revision 0.01 - File Created
//////////////////////////////////////////////////////////////////////////////////

module SevSegDisp(
    input CLK,              // 100 MHz clock
    input MODE,             // 0 - display hex, 1 - display decimal
    input [15:0] DATA_IN,
    output [7:0] CATHODES,
    output [3:0] ANODES
    );

    logic [15:0] BCD_Val;
    logic [15:0] Hex_Val;
    
    BCD BCDMod (.HEX(DATA_IN), .THOUSANDS(BCD_Val[15:12]),
                .HUNDREDS(BCD_Val[11:8]), .TENS(BCD_Val[7:4]),
                .ONES(BCD_Val[3:0]));
    
    CathodeDriver CathMod (.HEX(Hex_Val), .CLK(CLK), .CATHODES(CATHODES),
                            .ANODES(ANODES));
    
    // MUX to switch between HEX and BCD input
    always_comb begin
        if (MODE == 1'b1)
            Hex_Val = BCD_Val;
        else
            Hex_Val = DATA_IN;
    end
    
    
endmodule
