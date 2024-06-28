`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Cal Poly
// Engineer: Paul Hummel
//
// Create Date: 11/08/2018
// Module Name: PS2Receiver
// Target Devices: Basys3
// Description: PS2 Receiver module to get scancodes from a keyboard connected
//              to the USB plug. Based on the Verilog module by Joey Conenna
//              https://github.com/jconenna/FPGA-Projects for the Basys2
//
//              The interrupt signal will pulse for 60 ns on each key press
//
//              Holding a key will repeatedly trigger an interrupt with the
//              same scancode being output every few seconds.
//
//  Known Issues:
//  Keys with extended scancodes will trigger two interrupts, once on key press
//  and another on release. The release interrupt will always correspond with
//  outputing scancode E0. Holding an extended key down will repeatedly
//  trigger 2 interrupts, the first for the key scancode and the 2nd for E0
//
// Revision:
// Revision 0.01 - File Created
//////////////////////////////////////////////////////////////////////////////////


module KeyboardDriver(
    input CLK,                    // 100 MHz input clock
    input PS2DATA,
    input PS2CLK,
    output logic INTRPT,
    output logic [7:0] SCANCODE
  );

    // Define State Labels
    typedef enum {ST_WAIT, ST_INTRPT} STATES;
    STATES StateReg = ST_WAIT;

    logic CLK50 = 0;              // 50 MHz clock
    logic [7:0] ps_code;
    logic [3:0] intrptCount;
    logic code_ready, letter_case;

    // Clock Divider 100 MHz -> 50 MHz
    always_ff @(posedge(CLK))begin
        CLK50 <= ~CLK50;
    end
    
    // Initialize keyboard FSM
    keyboard keybd (.clk(CLK50), .reset(1'b0), .ps2d(PS2DATA), .ps2c(PS2CLK),
                    .scan_code(ps_code), .scan_code_ready(code_ready),
                    .letter_case_out(letter_case));
    
    // simple FSM to create interrupt pulse
    always_ff @(posedge CLK) begin
        case(StateReg)
            ST_WAIT: begin            // wait for keyboard button press
                intrptCount <= 0;
                INTRPT <= 1'b0;
                
                if (code_ready == 1'b1) begin   // check if scancode received
                  SCANCODE <= ps_code;          // output scancode
                  StateReg <= ST_INTRPT;        // transition to interrupt state
                end else
                  StateReg <= ST_WAIT;          // otherwise keep waiting
              end
              
            ST_INTRPT: begin
                INTRPT <= 1'b1;                 // create interrupt pulse
                if (intrptCount == 8) begin     // if pulse has been at least 60 ns
                  StateReg <= ST_WAIT;          // go back to waiting for next key
                end else begin
                  intrptCount <= intrptCount + 1;   // count how long interrupt pulse is high
                  StateReg <= ST_INTRPT;            // stay for at least 60 ns
                end
              end
            
            default: begin              // should never happen
                StateReg <= ST_WAIT;    // if something went wrong, go back to waiting
                INTRPT   <= 1'b0;
              end
        endcase;
    end
    
endmodule


// Keyboard FSM to interpret raw scancodes from PS2 receiver
module keyboard (
    input clk, reset,
    input ps2d, ps2c,         // ps2 data and clock lines
    output [7:0] scan_code,   // scan_code received from keyboard to process
    output scan_code_ready,   // signal to outer control system to sample scan_code
    output letter_case_out    // output to determine if scan code is converted to lower or upper ascii code for a key
  );
	
    // constant declarations
    localparam  BREAKKEY = 8'hf0, // break code
                SHIFT1   = 8'h12, // first shift scan
                SHIFT2   = 8'h59, // second shift scan
                CAPS     = 8'h58; // caps lock

    // FSM symbolic states
    localparam [2:0] ST_lowercase          = 3'b000, // idle, process lower case letters
                     ST_ignore_break       = 3'b001, // ignore repeated scan code after break code -F0- reeived
                     ST_shift              = 3'b010, // process uppercase letters for shift key held
                     ST_ignore_shift_break = 3'b011, // check scan code after F0, either idle or go back to uppercase
                     ST_capslock           = 3'b100, // process uppercase letter after capslock button pressed
                     ST_ignore_caps_break  = 3'b101; // check scan code after F0, either ignore repeat, or decrement caps_num
                     
    // internal signal declarations
    logic [2:0] state_reg, state_next;  // FSM state register and next state logic
    logic [7:0] scan_out;               // scan code received from keyboard
    logic got_code_tick;                // asserted to write current scan code received to FIFO
    logic scan_done_tick;               // asserted to signal that ps2_rx has received a scan code
    logic letter_case;                  // 0 for lower case, 1 for uppercase, outputed to use when converting scan code to ascii
    logic [7:0] shift_type_reg, shift_type_next;  // register to hold scan code for either of the shift keys or caps lock
    logic [1:0] caps_num_reg, caps_num_next;      // keeps track of number of capslock scan codes received in capslock state (3 before going back to lowecase state)
   
    // instantiate ps2 receiver
    ps2_rx ps2_rx_unit (.clk(clk), .reset(reset), .rx_en(1'b1), .ps2d(ps2d), .ps2c(ps2c), .rx_done_tick(scan_done_tick), .rx_data(scan_out));
	
	// FSM stat, shift_type, caps_num register
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
          state_reg      <= ST_lowercase;
          shift_type_reg <= 0;
          caps_num_reg   <= 0;
        end else begin
          state_reg      <= state_next;
          shift_type_reg <= shift_type_next;
          caps_num_reg   <= caps_num_next;
        end
      end
	 
    //FSM next state logic
    always_comb begin
        
        // defaults
        got_code_tick   = 1'b0;
        letter_case     = 1'b0;
        caps_num_next   = caps_num_reg;
        shift_type_next = shift_type_reg;
        state_next      = state_reg;
       
        case(state_reg)
        
          // state to process lowercase key strokes, go to uppercase state to process shift/capslock
          ST_lowercase: begin
              if(scan_done_tick) begin                                 // if scan code received
		          if(scan_out == SHIFT1 || scan_out == SHIFT2)  begin  // if code is shift
		              shift_type_next = scan_out;                      // record which shift key was pressed
			          state_next = ST_shift;            // go to shift state
                  end else if(scan_out == CAPS) begin   // if code is capslock
			          caps_num_next = 2'b11;            // set caps_num to 3, num of capslock scan codes to receive before going back to lowecase
			          state_next = ST_capslock;         // go to capslock state
		          end else if (scan_out == BREAKKEY)    // else if code is break code
                      state_next = ST_ignore_break;     // go to ignore_break state
                  else                                  // else if code is none of the above...
                      got_code_tick = 1'b1;             // assert got_code_tick to write scan_out to FIFO
              end
          end
            
          // state to ignore repeated scan code after break code FO received in lowercase state
          ST_ignore_break: begin
            if(scan_done_tick)            // if scan code received,
                state_next = ST_lowercase;   // go back to lowercase state
            end
            
          // state to process scan codes after shift received in lowercase state
          ST_shift: begin
            letter_case = 1'b1;           // routed out to convert scan code to upper value for a key
            if(scan_done_tick) begin      // if scan code received,
		      if(scan_out == BREAKKEY)     // if code is break code
		          state_next = ST_ignore_shift_break;  // go to ignore_shift_break state to ignore repeated scan code after F0
              else if(scan_out != SHIFT1 && scan_out != SHIFT2 && scan_out != CAPS) // else if code is not shift/capslock
                got_code_tick = 1'b1;   // assert got_code_tick to write scan_out to FIFO
              end
          end
            
          // state to ignore repeated scan code after break code F0 received in shift state
          ST_ignore_shift_break: begin
              if(scan_done_tick) begin            // if scan code received
                  if(scan_out == shift_type_reg)  // if scan code is shift key initially pressed
                      state_next = ST_lowercase;     // shift/capslock key unpressed, go back to lowercase state
                  else                            // else repeated scan code received, go back to uppercase state
                      state_next = ST_shift;
                end
            end
            
          // state to process scan codes after capslock code received in lowecase state
          ST_capslock: begin
              letter_case = 1'b1;           // routed out to convert scan code to upper value for a key
              if(caps_num_reg == 0)         // if capslock code received 3 times,
                state_next = ST_lowercase;     // go back to lowecase state
              if(scan_done_tick) begin      // if scan code received
                  if(scan_out == CAPS)      // if code is capslock,
                      caps_num_next = caps_num_reg - 1;   // decrement caps_num
                  else if(scan_out == BREAKKEY)              // else if code is break, go to ignore_caps_break state
                      state_next = ST_ignore_caps_break;
                  else if(scan_out != SHIFT1 && scan_out != SHIFT2)    // else if code isn't a shift key
                      got_code_tick = 1'b1;               // assert got_code_tick to write scan_out to FIFO
                end
            end
            
          // state to ignore repeated scan code after break code F0 received in capslock state
          ST_ignore_caps_break: begin
              if(scan_done_tick) begin    // if scan code received
                  if(scan_out == CAPS)    // if code is capslock
                      caps_num_next = caps_num_reg - 1;   // decrement caps_num
                  
                  state_next = ST_capslock;                  // return to capslock state
                end
            end
        endcase
      end
		
    // output, route letter_case to output to use during scan to ascii code conversion
    assign letter_case_out = letter_case;
	
    // output, route got_code_tick to out control circuit to signal when to sample scan_out
    assign scan_code_ready = got_code_tick;
	
    // route scan code data out
    assign scan_code = scan_out;
	
endmodule

// PS2 Receiver to debounce and filter serial bits to data bytes
module ps2_rx (
		input clk, reset,
		input ps2d, ps2c, rx_en,    // ps2 data and clock inputs, receive enable input
		output logic rx_done_tick,  // ps2 receive done tick
		output logic [7:0] rx_data  // data received
	);
	
	// FSMD state declaration
	localparam  IDLE = 1'b0,
	            RX   = 1'b1;
	
	// internal signal declaration
	logic state_reg, state_next;    // FSMD state register
	logic [7:0] filter_reg;         // shift register filter for ps2c
	logic [7:0] filter_next;        // next state value of ps2c filter register
	logic f_val_reg;                // reg for ps2c filter value, either 1 or 0
	logic f_val_next;               // next state for ps2c filter value
	logic [3:0] n_reg, n_next;      // register to keep track of bit number
	logic [10:0] d_reg, d_next;     // register to shift in rx data
	logic neg_edge;                 // negative edge of ps2c clock filter value
	
	// register for ps2c filter register and filter value
	always_ff @(posedge clk, posedge reset) begin
		  if (reset) begin
			  filter_reg <= 0;
			  f_val_reg  <= 0;
		  end else begin
			  filter_reg <= filter_next;
			  f_val_reg  <= f_val_next;
		  end
		end

	// next state value of ps2c filter: right shift in current ps2c value to register
	assign filter_next = {ps2c, filter_reg[7:1]};
	
	// filter value next state, 1 if all bits are 1, 0 if all bits are 0, else no change
	assign f_val_next = (filter_reg == 8'b11111111) ? 1'b1 :
	        (filter_reg == 8'b00000000) ? 1'b0 :
	        f_val_reg;
	
	// negative edge of filter value: if current value is 1, and next state value is 0
	assign neg_edge = f_val_reg & ~f_val_next;
	
	// FSMD state, bit number, and data registers
	always_ff @(posedge clk, posedge reset) begin
	    if (reset) begin
			  state_reg <= IDLE;
			  n_reg     <= 0;
			  d_reg     <= 0;
			end else begin
			  state_reg <= state_next;
			  n_reg     <= n_next;
			  d_reg     <= d_next;
			end
		end
	
	// FSMD next state logic
	always_comb begin
		
		// defaults
		state_next = state_reg;
		rx_done_tick = 1'b0;
		n_next = n_reg;
		d_next = d_reg;
		
		case (state_reg)
			IDLE: begin
				  if (neg_edge & rx_en) begin   // start bit received
					  n_next = 4'b1010;           // set bit count down to 10
					  state_next = RX;            // go to rx state
					end
				end
			
			RX: begin
				  if (neg_edge) begin             // if ps2c negative edge...
					  d_next = {ps2d, d_reg[10:1]}; // sample ps2d, right shift into data register
					  n_next = n_reg - 1;           // decrement bit count
				  end
			
				  if (n_reg == 0) begin   // after 10 bits shifted in, go to done state
					  rx_done_tick = 1'b1;  // assert dat received done tick
					  state_next = IDLE;    // go back to idle
				  end
			  end
		endcase
	end
		
	assign rx_data = d_reg[8:1]; // output data bits

endmodule

