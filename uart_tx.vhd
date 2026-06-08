library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library altera;
use altera.altera_syn_attributes.all;

entity uart_tx is
port (
	clk : in std_logic;
	rst : in std_logic;
	baud_pulse: in std_logic;
	data_in : in std_logic_vector(7 downto 0);
	start : in std_logic;
	tx : out std_logic;
	busy : out std_logic
);
end entity;

architecture rtl of uart_tx is
	type state_type is (IDLE, START_BIT, DATA_BITS, PARITY_BIT, STOP_BIT);
	signal state : state_type;
	signal tx_in : std_logic := '1';
	signal data_buffer : std_logic_vector(7 downto 0);
	signal bit_count : integer range 0 to 7;
	signal parity : std_logic;
begin
	tx <= tx_in;
	process(data_in)
		variable tmp : std_logic;
	begin
		tmp := '0';
		for i in 0 to 7 loop
			tmp := tmp xor data_in(i);
		end loop;
		parity <= tmp;
	end process;
	
	process(clk, rst)
	begin
		if rst = '0' then
			state <= IDLE;
			tx_in <= '1';
			busy <= '0';
			bit_count <= 0;
		elsif rising_edge(clk) then
			case state is
				when IDLE =>
					tx_in <= '1';
					busy <= '0';
					if start = '1' then
						data_buffer <= data_in;
						bit_count <= 0;
						state <= START_BIT;
						busy <= '1';
					end if;
				
				when START_BIT =>
					if baud_pulse = '1' then
						tx_in <= '0';
						state <= DATA_BITS;
					end if;
				
				when DATA_BITS =>
					if baud_pulse = '1' then
						tx_in <= data_buffer(0);
						data_buffer <= '0' & data_buffer(7 downto 1);
						if bit_count = 7 then
							state <= PARITY_BIT;
							bit_count <= 0;
						else
							bit_count <= bit_count + 1;
						end if;
					end if;
				
				when PARITY_BIT =>
					if baud_pulse = '1' then
						tx_in <= parity;
						state <= STOP_BIT;
					end if;
				
				when STOP_BIT =>
					if baud_pulse = '1' then
						tx_in <= '1';
						state <= IDLE;
					end if;
				
				when others =>
					state <= IDLE;
			end case;
		end if;
	end process;
end architecture;
