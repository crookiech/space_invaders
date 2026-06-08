library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library altera;
use altera.altera_syn_attributes.all;

entity baud_rate_gen is
port (
	clk : in std_logic;
	rst : in std_logic;
	baud_pulse : out std_logic;
	baud_x16_pulse : out std_logic
);
end entity baud_rate_gen;

architecture rtl of baud_rate_gen is
	constant MAX_COUNT_baud_pulse : integer := 50_000_000 / 115_200 - 1;
	constant MAX_COUNT_baud_x16_pulse : integer := 50_000_000 / (115_200 * 16) - 1;
	signal counter_baud_pulse : integer range 0 to MAX_COUNT_baud_pulse;
	signal counter_baud_x16_pulse : integer range 0 to MAX_COUNT_baud_x16_pulse;

begin
	process(clk, rst)
	begin
		if rst = '0' then
			counter_baud_pulse <= 0;
			counter_baud_x16_pulse <= 0;
			baud_pulse  <= '0';
			baud_x16_pulse  <= '0';
		elsif rising_edge(clk) then
			if counter_baud_pulse = MAX_COUNT_baud_pulse then
				counter_baud_pulse <= 0;
				baud_pulse <= '1';
			else
				counter_baud_pulse <= counter_baud_pulse + 1;
				baud_pulse <= '0';
			end if;
			if counter_baud_x16_pulse = MAX_COUNT_baud_x16_pulse then
				counter_baud_x16_pulse <= 0;
				baud_x16_pulse <= '1';
			else
				counter_baud_x16_pulse <= counter_baud_x16_pulse + 1;
				baud_x16_pulse <= '0';
			end if;
		end if;
	end process;
end architecture rtl;
