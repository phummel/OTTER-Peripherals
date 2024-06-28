`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Cal Poly
// Engineer: Paul Hummel
//
// Create Date: 03/10/2022 11:34:01 AM
// Module Name: Debouncer
// Project Name: Button Debouncer for OTTER
// Target Devices: Basys3
// Description: Debounces a button input.
//              DB_BTN is the debounced button with a 1.25 ms pulse (800 Hz)
//              OneShot is an adjustable length pulse that is triggered
//                  once for every button press. Initially 80 ns for OTTER
// Revision:
// Revision 0.01 - File Created
//          0.02 - Update simulation to wait for slow clock to become valid
//               - Change 400 Hz clock to 800 Hz for quicker response
//               - Change one shot from 40ns to 80ns with shift reg
//////////////////////////////////////////////////////////////////////////////////

module Debouncer(
    input CLK_100,
    input RST,
    input BTN,
    output DB_BTN,
    output OneShot
    );

    // clock divider signals
    logic clk_800z;
    logic [31:0] clock_div_counter;

    // debouncer register signals
    logic db_dff_1, db_dff_2;
    logic db_onepulse;

    // oneshot register signals
    logic [8:0] oneshot_reg;

    // create a 800 Hz clock from 100 MHz input clock
    always_ff @(posedge CLK_100) begin

        if (RST == 1'b1) begin
            clock_div_counter <= 0;
            clk_800z <= 0;
        end
        else
            clock_div_counter <= clock_div_counter + 1;

        if (clock_div_counter >= 62499) begin    // 124999 = 400 Hz, 62499 = 800 Hz
            clock_div_counter <= 0;
            clk_800z <= ~clk_800z;
        end

    end

    // create debouncer with double buffer registers at slow clock
    always_ff @(posedge clk_800z) begin
       db_dff_1 <= BTN;
       db_dff_2 <= db_dff_1;
    end

    // create debounced oneshot at 800 Hz clock from the output of both registers
    assign db_onepulse = db_dff_1 & ~db_dff_2;
    assign DB_BTN = db_onepulse;

    // create an 80ns OneShot with 8 high speed registers in series
    always_ff @(posedge CLK_100) begin
        oneshot_reg <= {oneshot_reg[7:0],db_onepulse};
    end

    // create one shot signal from 8 registers.
    assign OneShot = oneshot_reg[0] & ~oneshot_reg[8];

endmodule

