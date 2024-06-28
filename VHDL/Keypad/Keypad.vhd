----------------------------------------------------------------------------------
-- Company:  Cal Poly
-- Engineer: Paul Hummel
--
-- Create Date: 01/23/2018 04:17:58 AM
-- Module Name: Keypad
-- Target Devices: Basys3
-- Description: FSM to read keypresses from a 4x3 resistive keypad and create an
--              interrupt signal pulse optimized for the RAT MCU (40 ns pulse)
--                 The data sent out is the key value (0-9).
--                 * (Col 0, Row 3) is value 10 (xA)
--                 # (Col 2, Row 3) is value 11 (xB)
--                 When no keypress is detected, the output value is 15 (xF)
--
--              Scans rows while reading the columns. Assumes no button bounce
--              exists at the 1kHz scan rate. When a keypress is detected, a
--              single interrupt pulse (40 ns) is sent. The button must be
--              released before another interrupt can be created. Only a single
--              button is detected at a time. If holding a button down, a button
--              on the same row, but a "higher" column can be detected. This
--              "new" button detection will not trigger a new interrupt if there
--              was no button release detected between presses.
--
--              Pull down resistors should be added to the column inputs.
-- Revision:
-- Revision 0.01 - File Created
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Keypad is
    Port ( Clk : in STD_LOGIC;
           Row : out STD_LOGIC_VECTOR (3 downto 0);
           Col : in STD_LOGIC_VECTOR (2 downto 0);
           Data : out STD_LOGIC_VECTOR (3 downto 0);
           Int : out STD_LOGIC);
end Keypad;

architecture Behavioral of Keypad is

    --signal ButtonPress : STD_LOGIC;
    signal Clk_1k, Clk_25M, Intr : STD_LOGIC := '0';
    
    TYPE states IS (NoPress, Row0, Row1, Row2, Row3);
    -- NoPress  - waiting for button to be pressed, all Rows are high
    -- Row#     - button press deteced, scan rows to find which button was
    --            pressed. Once found, hold row high and wait for release
    
    signal NS, PS : states;
    
begin

    -- Create a 1kHz clock to drive state register
    clkdiv: process (Clk)
        variable counter : unsigned (15 downto 0) := x"0000";
    begin
        if rising_edge(Clk) then
            counter := counter + 1;
            if counter = x"C350" then -- 0xc350 = 50,000 (100 MHz --> 1kHz)
                Clk_1k <= not Clk_1k;
                counter := x"0000";
            end if;
        end if;
    end process clkdiv;
    
    -- Create a 25MHz clock to drive interrupt
    clk25div: process (Clk)
        variable counter : unsigned (1 downto 0) := "00";
    begin
        if rising_edge(Clk) then
            counter := counter + 1;
            if counter = 2 then -- divide by 4 (100 MHz -> 25 MHz)
                Clk_25M <= not Clk_25M;
                counter := "00";
            end if;
        end if;
    end process clk25div;

    -- Update state every 1 ms (1 kHz)
    StateReg: process (Clk_1k)
    begin
        if rising_edge(Clk_1k) then
            PS <= NS;
        end if;
    end process StateReg;

    -- Input / Output logic of FSM
    NextState: process(PS, Col)
        --variable row_cnt : unsigned (1 downto 0) := "00";
    begin
        --Data <= x"F";   -- Data is F when no button is pressed to
                        -- to disguish from button 0
        case (PS) is
            when NoPress =>     -- Waiting for button press

                Row <= "1111";    -- Set all rows high
                NS <= NoPress;
                Intr <= '0';        -- reset interrupt
                Data <= x"F";    -- no input
                
                if (Col /= "000") then  -- check for any button
                    NS <= Row0;     -- Start scanning with Row0
                end if;
                
            when Row0 =>        -- Button press on Row 0
                Row <= "0001";  -- Row 0 stays high
                NS <= Row0;
                
                -- Determine keybutton value by rows
                if (Col(2) = '1') then
                    Data <= x"3";
                    Intr <='1';
                elsif (Col(1) = '1') then
                    Data <= x"2";
                    Intr <='1';
                elsif (Col(0) = '1') then
                    Data <= x"1";
                    Intr <='1';
                else                -- button has been released
                    Data <= x"F";
                    NS <= Row1;
                    Intr <= '0';
                end if;
                
            when Row1 =>        -- Button detected on Row 1
                Row <= "0010";
                NS <= Row1;
                Data <= x"3";
                
                if (Col(2) = '1') then
                    Data <= x"6";
                    Intr <= '1';        -- Key found so interrupt
                elsif (Col(1) = '1') then
                    Data <= x"5";
                    Intr <= '1';        -- Key found so interrupt
                elsif (Col(0) = '1') then
                    Data <= x"4";
                    Intr <= '1';        -- Key found so interrupt
                else                -- Button has been released
                    Data <= x"F";
                    NS <= Row2;
                    Intr <= '0';
                end if;

            when Row2 =>            -- Button detedted on Row 2
                Row <= "0100";
                NS <= Row2;
                                
                if (Col(2) = '1') then
                    Data <= x"9";
                    Intr <= '1';        -- Key found so interrupt
                elsif (Col(1) = '1') then
                    Data <= x"8";
                    Intr <= '1';        -- Key found so interrupt
                elsif (Col(0) = '1') then
                    Data <= x"7";
                    Intr <= '1';        -- Key found so interrupt
                else                -- Button has been released
                    Data <= x"F";
                    NS <= Row3;
                    Intr <= '0';
                end if;

            when Row3 =>
                Row <= "1000";      -- Button detected on Row 3
                NS <= Row3;
                
                if (Col(2) = '1') then
                    Data <= x"B";      -- *
                    Intr <= '1';        -- Key found so interrupt
                elsif (Col(1) = '1') then
                    Data <= x"0";
                    Intr <= '1';        -- Key found so interrupt
                elsif (Col(0) = '1') then
                    Data <= x"A";      -- #
                    Intr <= '1';        -- Key found so interrupt
                else                -- Button has been released
                    Data <= x"F";
                    NS <= NoPress;
                    Intr <= '0';
                end if;

            when others =>  -- failsafe state should never happen
                NS <= NoPress;
                Data <= x"F";
                Row <= "1111";
                Intr <= '0';
        end case;
    end process NextState;
    
    -- Interrupt driver with one shot (40 ns / 25 MHz)
    Interrupt: process (Clk_25M)
        variable IntFire : std_logic := '0';
    begin
        if rising_edge(Clk_25M) then
            if ((Intr = '1') and (IntFire = '0')) then -- Key pressed
                Int <= '1';                         -- Output interrupt pulse
                IntFire := '1';         -- Set flag an interrupt has occurred
            elsif ((Intr = '1') and (IntFire = '1')) then -- Key still pressed
                Int <= '0';       -- Stop interrupt pulse after 40 ns
                IntFire := '1';   -- Keep signaling interrupt has occurred
            else                    -- Either key released or nothing pressed
                Int <= '0';         -- Stop interrupt pulse
                IntFire := '0';     -- Reset interrupt flag for new key press
            end if;
        end if;
    end process Interrupt;
    
end Behavioral;
