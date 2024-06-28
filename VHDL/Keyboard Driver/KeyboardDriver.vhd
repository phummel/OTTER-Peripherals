----------------------------------------------------------------------------------
-- Company:  RAT Technologies
-- Engineer: Paul Hummel
-- 
-- Create Date:    3/10/2017
-- Module Name:    KeyboardDriver - Behavioral 
-- Target Devices: Basys3
-- Description: Keyboard driver for using USB HID PS/2 Keyboard
--              input for RAT MCU. This design is based off of the
--				demo keyboard module by homas Kappenman from Digilent
--
-- Revision: 
-- Revision 0.01 - File Created
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity KeyboardDriver is
	Port (	clk		: in  STD_LOGIC;
			keyclk	: in  STD_LOGIC;
			keydata	: in  STD_LOGIC;
			keycode	: out STD_LOGIC_VECTOR (7 downto 0);
			intrpt	: out STD_LOGIC);
end KeyboardDriver;

architecture Behavioral of KeyboardDriver is

	component debouncer 
		port (	clk		: in  STD_LOGIC;
				input	: in  STD_LOGIC;
				output	: out STD_LOGIC);
	end component debouncer;
	
	-- debounced signals ---
	signal	s_keyclk_db		: STD_LOGIC;
	signal  s_keydata_db	: STD_LOGIC;
	
	-- flag for signaling the keycode has been filled by the keyboard
	signal	s_keycode_set	: STD_LOGIC;
	
	-- counters ---
	signal  r_keyclk_count	: UNSIGNED (3 downto 0);
	
	-- registers --
	signal	r_keycode		: STD_LOGIC_VECTOR (7 downto 0);
	signal	r_keycode_full	: STD_LOGIC;
	signal	r_prev_full		: STD_LOGIC;
	signal	r_state			: STD_LOGIC_VECTOR (1 downto 0); 
			-- 00 - rest state, waiting for keypress
			-- 01 - key press detected, waiting for set code to settle
			-- 10 - set code has settled, count state 
			-- 11 - keycode set 3 times, so keypress is done, set interrupt
		
begin

	-- Instantiate Debouncers for input keyboard clock and data --------------------
	kclkdb: debouncer
	port map (	clk 	=> clk,
				input 	=> keyclk,
				output 	=> s_keyclk_db);

	kdatadb: debouncer
	port map (	clk		=> clk,
				input	=> keydata,
				output	=> s_keydata_db);
	-------------------------------------------------------------------------------
				
	-- process block to read data from keyboard into keycode ----------------------
	process (s_keyclk_db) begin
		if falling_edge(s_keyclk_db) then
			case r_keyclk_count is
		    	when x"0" =>	-- start bit so do nothing
		    	when x"1" =>	r_keycode(0) <= s_keydata_db;
		    	when x"2" =>	r_keycode(1) <= s_keydata_db;	
		    	when x"3" =>	r_keycode(2) <= s_keydata_db;
		    	when x"4" =>	r_keycode(3) <= s_keydata_db;
		    	when x"5" =>	r_keycode(4) <= s_keydata_db;
		    	when x"6" =>	r_keycode(5) <= s_keydata_db;
		    	when x"7" =>	r_keycode(6) <= s_keydata_db;
		    	when x"8" =>	r_keycode(7) <= s_keydata_db;
		    	when x"9" =>	r_keycode_full	<= '1';		-- flag to signal keycode full	
		    	when x"A" =>	r_keycode_full	<= '0';
		    	when others =>	r_keycode_full	<= '0';
			end case;
			
			-- reset keyboard clock counter when reaches 10
			if (r_keyclk_count = x"A") then
				r_keyclk_count <= x"0";
			else
				r_keyclk_count <= r_keyclk_count + 1;
			end if;
	
		end if;
	end process;
	
	-- sync keycode_set signal to system clock instead of keyboard clock signal
	process (clk) begin
		if rising_edge(clk) then
			if ((r_keycode_full = '1') and (r_prev_full = '0')) then	-- verify full flag was just set high
				keycode <= r_keycode;
				s_keycode_set <= '1';	
			else
				s_keycode_set <= '0';
			end if;
			
			r_prev_full <= r_keycode_full;		--  current full flag gets saved as previous
				
		end if;
	end process;
	
	-- State machine to create a one shot interrupt signal for the keyboard driver ------------
	-------------------------------------------------------------------------------------------
	-- Every key press results in the keycode register filling up 3 times. The keycode must           
	-- first be debounced, then counted how many times it is set. After filling up 3 times, 
	-- the interrupt signal is set high for only 2 clock signals to ensure the RAT MCU detects 
	-- the signal, but only triggers a single interrupt
	-------------------------------------------------------------------------------------------    
	
	process (clk) 
		variable	r_delay_count	: UNSIGNED (2 downto 0);
		variable	r_set_count		: UNSIGNED (1 downto 0);
	begin
		if rising_edge(clk) then
			if (r_state = "00") then			-- currently in rest state
				if (s_keycode_set = '1') then	-- keycode has been set, so now
					r_state <= "01";			--   wait for it to settle
					r_delay_count := "000";
				end if;
			elsif (r_state = "01") then			-- currently waiting for keycode set to settle
				if (s_keycode_set = '1') then	-- still high so keep waiting
					r_delay_count := "000";
				else							-- set goes low, so count delay
					r_delay_count := r_delay_count + 1;	
				end if;
				
				if (r_delay_count = 5) then		-- don't count a keycode set until it stays low 5 clk cycles
					r_state <= "10";			-- move to count state to ensure keycode has been filled
					r_delay_count := "000";		--  3 times before setting interrupt
				end if;
			elsif (r_state = "10") then				-- currently in the count state
				r_delay_count := r_delay_count + 1;	-- stay in this state for 1 clock cycle
				
				if (r_delay_count = 2) then
					r_set_count := r_set_count + 1;	-- count number of times keycode data has been filled
					r_state <= "00";				-- go back to rest state to get next keyboard code
					r_delay_count := "000";
				end if;
				
				if (r_set_count = 3) then			-- keycode has been filled 3 times, so keypress is over
					r_state <= "11";				-- move to state to set one shot interrupt
					r_delay_count := "000";
				end if;

			elsif (r_state = "11") then				-- currently in the one shot fire state
				intrpt <= '1';						-- fire interrupt
				r_set_count := "00";					-- reset count
				r_delay_count := r_delay_count + 1; -- only fire for 3 clock pulses
				
				if (r_delay_count = 3) then
					r_state <= "00";					-- go back to rest state wait for next key
					r_delay_count := "000";
					intrpt <= '0';
				end if;
			end if;
					
		end if;								
	end process;
	
end Behavioral;


----------------------------------------------------------------------------------
-- Company:  RAT Technologies
-- Engineer: Paul Hummel
-- 
-- Create Date:    3/10/2017
-- Module Name:    debouncer - Behavioral 
-- Target Devices: Basys3
-- Description: debouncer used for the keyboard driver. This design is based 
--              off of the demo keyboard module by homas Kappenman from Digilent
--
-- Revision: 
-- Revision 0.01 - File Created
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity debouncer is
	Port (	clk		: in  STD_LOGIC;
			input	: in  STD_LOGIC;
			output	: out STD_LOGIC);
end debouncer;

architecture Behavioral of debouncer is

	CONSTANT COUNT_MAX  : UNSIGNED (7 downto 0) := X"FF";
	signal	r_counter	: UNSIGNED (7 downto 0) := X"00";
	signal	r_in_prev	: STD_LOGIC;
	
begin
	
	process (clk) begin
		if rising_edge(clk) then
			if (input = r_in_prev) then
				if (r_counter = COUNT_MAX) then
					output <= input;
				else
					r_counter <= r_counter + 1;
				end if;
			else
				r_counter <= x"00";
				r_in_prev <= input;
			end if;
		end if;
	end process;

end Behavioral;
