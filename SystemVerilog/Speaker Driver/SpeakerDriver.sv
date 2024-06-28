`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Cal Poly 
// Engineer: Paul Hummel
// 
// Create Date: 02/26/2021 03:30:47 PM
// Module Name: SpeakerDriver
// Project Name: Speaker Driver
// Target Devices: Basys3 
// Tool Versions: Vivado 2020.2
// Description: Creates a square wave of preconfigured frequencies that
//              correspond to a range of notes. The frequency range covers
//              4 full octaves (Octave 5 - 8) with each octave containing
//              12 possible notes (C - B). All note calculations based off
//              the input clock being 100 MHz. The note is selected with an
//              8-bit input. The input range does not need  the full 8-bits, 
//              but that width was selected for portability of using this 
//              module as a peripheral for the OTTER MCU.
// 
// Revision:
// Revision 0.01 - File Created
//////////////////////////////////////////////////////////////////////////////////

module SpeakerDriver(
    input [7:0] Note,
    input CLK,              // 100 MHz
    output logic Speaker
    );
    
    logic [19:0] FreqCount, ClkCount;
    
    // Create speaker square wave by clock dividing 100 MHz
    always_ff @(posedge CLK) begin
        ClkCount <= ClkCount + 1;
        if (FreqCount == 20'h00000) begin // Output no sound
            Speaker <= 1'b0;              // Speaker off
            ClkCount <= 20'h0;            // Keep ClkCount reset to 0
          end
        else if (FreqCount == ClkCount) begin  // check period count
            Speaker <= ~Speaker;    // toggle to create square wave
            ClkCount <= 20'h0;      // reset counter
        end                        
    end    
    
    // Frequencies were calculated based on a 100 MHz input clock
    // Period Count = 100x10^6 / Note Frequency
    // FreqCount = Period Count / 2
    always_comb begin
        case(Note)
            8'h00: FreqCount = 20'h00000; // Speaker off
            ////////////////////////////////////////////////////////
            8'h01: FreqCount = 20'h17544; // C     Octave 5
            8'h02: FreqCount = 20'h16051; // C#
            8'h03: FreqCount = 20'h14C8B; // D
            8'h04: FreqCount = 20'h139E1; // D#
            8'h05: FreqCount = 20'h12843; // E
            8'h06: FreqCount = 20'h117A2; // F
            8'h07: FreqCount = 20'h107F1; // F#
            8'h08: FreqCount = 20'h0F920; // G
            8'h09: FreqCount = 20'h0EB25; // G#
            8'h0A: FreqCount = 20'h0DDF2; // A
            8'h0B: FreqCount = 20'h0D17D; // A#
            8'h0C: FreqCount = 20'h0C5BB; // B
            ////////////////////////////////////////////////////////
            8'h0D: FreqCount = 20'h0BAA2; // C     Octave 6
            8'h0E: FreqCount = 20'h0B029; // C#
            8'h0F: FreqCount = 20'h0A646; // D
            8'h10: FreqCount = 20'h09CF1; // D#
            8'h11: FreqCount = 20'h09422; // E
            8'h12: FreqCount = 20'h08BD1; // F
            8'h13: FreqCount = 20'h083F8; // F#
            8'h14: FreqCount = 20'h07C90; // G
            8'h15: FreqCount = 20'h07592; // G#
            8'h16: FreqCount = 20'h06EF9; // A
            8'h17: FreqCount = 20'h068BF; // A#
            8'h18: FreqCount = 20'h062DE; // B
            ////////////////////////////////////////////////////////
            8'h19: FreqCount = 20'h05D51; // C     Octave 7
            8'h1A: FreqCount = 20'h05814; // C#
            8'h1B: FreqCount = 20'h05323; // D
            8'h1C: FreqCount = 20'h04E78; // D#
            8'h1D: FreqCount = 20'h04A11; // E
            8'h1E: FreqCount = 20'h045E9; // F
            8'h1F: FreqCount = 20'h041FC; // F#
            8'h20: FreqCount = 20'h03E48; // G
            8'h21: FreqCount = 20'h03AC9; // G#
            8'h22: FreqCount = 20'h0377D; // A
            8'h23: FreqCount = 20'h0345F; // A#
            8'h24: FreqCount = 20'h0316F; // B       
            ////////////////////////////////////////////////////////
            8'h25: FreqCount = 20'h02EA9; // C     Octave 8
            8'h26: FreqCount = 20'h02C0A; // C#
            8'h27: FreqCount = 20'h02991; // D
            8'h28: FreqCount = 20'h0273C; // D#
            8'h29: FreqCount = 20'h02508; // E
            8'h2A: FreqCount = 20'h022F4; // F
            8'h2B: FreqCount = 20'h020F3; // F#
            8'h2C: FreqCount = 20'h01F24; // G
            8'h2D: FreqCount = 20'h01D65; // G#
            8'h2E: FreqCount = 20'h01BBE; // A
            8'h2F: FreqCount = 20'h01A30; // A#
            8'h30: FreqCount = 20'h018B7; // B          
            default: FreqCount = 20'h00000;  // default to speaker off          
        endcase
    end
    
    
endmodule
