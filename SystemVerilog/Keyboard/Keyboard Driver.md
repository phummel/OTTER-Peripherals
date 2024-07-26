**Keyboard Driver (SystemVerilog Module)**  
written by Paul Hummel

The keyboard driver was designed for the Basys3 but should work for any device that uses a PS/2 connector or has a similar Auxiliary Function microcontroller to emulate a PS/2 bus. The keyboard connection uses two single-bit input signals, one for transmitting data serially and the other for controlling a clock as the data is sent. The keyboard driver also needs a system clock (100 MHz) input. As outputs, the driver sends out an 8-bit logic scan code that contains the keyboard scan code for the button pressed. The keyboard driver also has an output signal INTERPT that goes high for 70 ns after the keyboard button has been detected. This signal is designed to be used as an interrupt input into the OTTER MCU. Holding a single key down will cause the driver to repeat the interrupt about once a second. If holding down one key and another key gets pressed, the keypress of the 2nd key will cause an interrupt and the scan code will reflect the most recent keypress. If both keys remain pressed, only the 2nd (most recently pressed) key’s scan code will be output.

The scan codes for each key are shown below (image from the [Basys3 reference manual](https://reference.digilentinc.com/reference/programmable-logic/basys-3/reference-manual) by Digilent)

**Known Limitation**  
Some keys create an extended scan code of 2 bytes beginning with 0xE0. This is sometimes used to distinguish between two keys with the same function. For example, the ALT and CTRL keys on the right both produce an extended scan code to distinguish them from the left side. The other commonly used key that creates an extended scan code is the right arrow key. When pressing a key with an extended scan code the keyboard driver creates 2 interrupts. The first interrupt occurs when the key is pressed. The scan code output when the key is pressed is the 2nd byte of the extended scan code, so 0x14 for the right CTRL key. When the key is released, the driver creates a 2nd interrupt and outputs the scan code 0xE0. If an extended key is held down 2 interrupts are created repeatedly, alternating between the right byte scan code and 0xE0.

**Connecting the Keyboard to the Basys3**  
Included with the keyboard driver SystemVerilog file is a sample OTTER Wrapper to show how it is connected to the OTTER MCU. The keyboard interfaces to the Basys3 through a PS2 connection on the USB port. The PS2 connections to the FPGA are pins C17 and B17. The constraints file should be set to enable pull-up resistors on both ports. A sample constraints XDC file is given below:

\#\#USB HID (PS/2)  
set\_property PACKAGE\_PIN C17 \[get\_ports PS2CLK\]  
	set\_property IOSTANDARD LVCMOS33 \[get\_ports PS2CLK\]  
	set\_property PULLUP true \[get\_ports PS2CLK\]  
set\_property PACKAGE\_PIN B17 \[get\_ports PS2DATA\]					  
	set\_property IOSTANDARD LVCMOS33 \[get\_ports PS2DATA\]	  
	set\_property PULLUP true \[get\_ports PS2DATA\]

**OTTER Assembly Demo Program**  
A OTTER assembly test program is also provided. The test program uses interrupts to read from the keyboard. The number of interrupts is counted and displayed in binary on the LEDs (16 bits). The keyboard scan code is displayed on the 7-segment display. Pressing a button on the keyboard should only increment the LEDs by 1 and display a single scan code to the 7 segment. If the same key is pressed again, the scan code should not change, but the LEDs should increment by 1 again. Each successive key press should increment the LEDs by 1 and produce a valid scan code for the key that matches the image above. (Note that pressing a key with an extended scan code will trigger 2 interrupts and display both scan codes consecutively, although the last one will be 0xE0 which may be the only one that is visible)