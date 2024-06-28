`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Cal Poly
// Engineer: Paul Hummel
// 
// Create Date: 03/11/2021 12:19:22 PM
// Module Name: ADC 
// Target Devices: Basys3
// Tool Versions: Vivado 2020.2
// Description: 12-bit ADC using XADC on Atrix 7 (Basys3)
//              The ADC continuously performs convsersions on the VAUX6
//              differential pair input of the XADC. Using the 100 MHz clock
//              will create a sampling rate of ~961.54 ksps. Every conversion
//              is stored in an output register to keep the output value 
//              constant between conversions.
//              
//              The analog signal is measured as a unipolar differential pair 
//              between VAUXP6 (+) and VAUXN6 (-) using pins 1 and 7 of the 
//              XADC PMOD. The ADC is limited to a range of 1.0v max. The
//              voltage to either pin should never go below 0V or above 1.8V
//
//              !WARNING!    1.8 V MAX VOLTAGE   !WARNING!
//              !WARNING!    0.0 V MIN VOLTAGE   !WARNING!
// 
// Revision:
// Revision 0.01 - File Created
//////////////////////////////////////////////////////////////////////////////////

module ADC(
    input CLK_100,
    input ANALOG_POS,
    input ANALOG_NEG,
    output logic [11:0] ADC_VALUE
    );
    
    localparam ADC_CHANNEL_ADDRESS = 7'h16;  // address for VAUX6
    
    logic s_data_ready, s_adc_enable;
    logic [15:0] s_adc_data;
    
    // instantiate Xilinx XADC IP   
    xadc_wiz_0 ADC_module(
          .daddr_in(ADC_CHANNEL_ADDRESS),   // Address bus for the dynamic reconfiguration port
          .dclk_in(CLK_100),                // Clock input for the dynamic reconfiguration port
          .den_in(s_adc_enable),            // Enable Signal for the dynamic reconfiguration port
          .di_in(0),                        // Input data bus for the dynamic reconfiguration port
          .dwe_in(0),                       // Write Enable for the dynamic reconfiguration port
          .vauxp6(ANALOG_POS),              // Analog (+) input
          .vauxn6(ANALOG_NEG),              // Analog (-) input
          .busy_out(),                      // ADC Busy signal
          .channel_out(),                   // Channel Selection Outputs
          .do_out(s_adc_data),              // Output data bus for dynamic reconfiguration port
          .drdy_out(s_data_ready),          // Data ready signal for the dynamic reconfiguration port
          .eoc_out(s_adc_enable),           // End of Conversion Signal
          .eos_out(),                       // End of Sequence Signal
          .alarm_out(),                     // OR'ed output of all the Alarms    
          .vp_in(0),                        // Dedicated Analog Input Pair
          .vn_in(0));
    
    // output register to hold ADC value between conversions
    always_ff @(posedge CLK_100) begin
        if (s_data_ready == 1'b1)           // new sample taken
            ADC_VALUE <= s_adc_data[15:4];  // update  
    end
    
endmodule
