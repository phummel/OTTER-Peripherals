----------------------------------------------------------------------------------
-- Company: Cal Poly 
-- Engineer: Paul Hummel
-- 
-- Create Date: 01/31/2018 01:52:13 PM
-- Module Name: SpeakerDriver - Behavioral
-- Project Name: Speaker Driver      
-- Target Devices: Basys3
-- Tool Versions: Vivado 2017.4
-- Description: Creates a square wave of preconfigured frequencies that
--              correspond to a range of notes. The frequency range covers
--              3 full octaves (Octave 6 - 8) with each octave containing
--              12 possible notes (C - B). The note is selected with an
--              8-bit input. This project uses the switches for the input
--              The input range does not need 8-bits, but that width was
--              selected for portability of using this module as a peripheral
--              for the RAT MCU. 
-- Revision:
-- Revision 0.01 - Initial working version
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity SpeakerDriver is
    Port ( Switches : in STD_LOGIC_VECTOR (7 downto 0);
           Clk      : in STD_LOGIC;
           SpkFreq : out STD_LOGIC);
end SpeakerDriver;

architecture Behavioral of SpeakerDriver is

    signal FreqCount : unsigned (19 downto 0) := x"00000";

begin
    -- Frequencies were calculated based on a 100 MHz input clock
    -- Period Count = 100x10^6 / Note Frequency
    -- FreqCount = Period Count / 2
    setfreq: process (Switches)
    begin
        case (Switches) is
            when x"00" => FreqCount <= x"00000";
            when x"01" => FreqCount <= x"17544"; -- C     Octave 6
            when x"02" => FreqCount <= x"16051"; -- C#
            when x"03" => FreqCount <= x"14C8B"; -- D
            when x"04" => FreqCount <= x"139E1"; -- D#
            when x"05" => FreqCount <= x"12843"; -- E
            when x"06" => FreqCount <= x"117A2"; -- F
            when x"07" => FreqCount <= x"107F1"; -- F#
            when x"08" => FreqCount <= x"0F920"; -- G
            when x"09" => FreqCount <= x"0EB25"; -- G#
            when x"0A" => FreqCount <= x"0DDF2"; -- A
            when x"0B" => FreqCount <= x"0D17D"; -- A#
            when x"0C" => FreqCount <= x"0C5BB"; -- B
            --------------------------------------------------------
            when x"0D" => FreqCount <= x"0BAA2"; -- C     Octave 7
            when x"0E" => FreqCount <= x"0B029"; -- C#
            when x"0F" => FreqCount <= x"0A646"; -- D
            when x"10" => FreqCount <= x"09CF1"; -- D#
            when x"11" => FreqCount <= x"09422"; -- E
            when x"12" => FreqCount <= x"08BD1"; -- F
            when x"13" => FreqCount <= x"083F8"; -- F#
            when x"14" => FreqCount <= x"07C90"; -- G
            when x"15" => FreqCount <= x"07592"; -- G#
            when x"16" => FreqCount <= x"06EF9"; -- A
            when x"17" => FreqCount <= x"068BF"; -- A#
            when x"18" => FreqCount <= x"062DE"; -- B
            --------------------------------------------------------
            when x"19" => FreqCount <= x"05D51"; -- C     Octave 8
            when x"1A" => FreqCount <= x"05814"; -- C#
            when x"1B" => FreqCount <= x"05323"; -- D
            when x"1C" => FreqCount <= x"04E78"; -- D#
            when x"1D" => FreqCount <= x"04A11"; -- E
            when x"1E" => FreqCount <= x"045E9"; -- F
            when x"1F" => FreqCount <= x"041FC"; -- F#
            when x"20" => FreqCount <= x"03E48"; -- G
            when x"21" => FreqCount <= x"03AC9"; -- G#
            when x"22" => FreqCount <= x"0377D"; -- A
            when x"23" => FreqCount <= x"0345F"; -- A#
            when x"24" => FreqCount <= x"0316F"; -- B          
            when others => FreqCount <= x"00000";
        end case; 
    end process setfreq;

    clkdiv: process (Clk)
        variable ClkCount : unsigned (19 downto 0) := x"00000";
        variable SpkWave : std_logic := '0';
    begin     
        if rising_edge(Clk) then
            ClkCount := ClkCount + 1;
            if (FreqCount = x"00000") then -- output no sound
                SpkWave := '0';            -- keep output low
                ClkCount := x"00000";      -- keep ClkCount reset
            elsif (ClkCount = FreqCount) then -- create square wave
                SpkWave := not SpkWave;       -- toggle every half period       
                ClkCount := x"00000";         -- reset counter
            end if;
        end if;
        SpkFreq <= SpkWave; -- output square wave
    end process clkdiv;

end Behavioral;
