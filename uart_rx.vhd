library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library altera;
use altera.altera_syn_attributes.all;

entity uart_rx is
port (
	clk : in std_logic;
	rst : in std_logic;
	baud_x16_pulse : in std_logic;
	rx : in  std_logic;
	data_out : out std_logic_vector(7 downto 0);
	valid : out std_logic;
	v_parity_error : out std_logic;
	framing_error : out std_logic
);
end entity;

architecture rtl of uart_rx is
	type state_type is (IDLE, START_BIT, DATA_BITS, PARITY_BIT, STOP_BIT);
	signal state : state_type := IDLE;
	signal rx_in : std_logic_vector(7 downto 0);
	signal bit_count : integer range 0 to 7;
	signal ovs_count : integer range 0 to 15;
	signal parity_calc: std_logic;
	signal sampled_bit: std_logic;
	signal valid_in : std_logic;
	signal parity_error_in : std_logic;
	signal framing_error_in: std_logic;
begin
	data_out <= rx_in;
	valid <= valid_in;
	v_parity_error  <= parity_error_in;
	framing_error <= framing_error_in;
	process(clk, rst)
		variable v_parity_error  : std_logic;
		variable v_framing_error : std_logic;
	begin
		if rst = '0' then
			state <= IDLE;
			rx_in <= (others => '0');
			bit_count <= 0;
			ovs_count <= 0;
			parity_calc <= '0';
			valid_in <= '0';
			parity_error_in <= '0';
			framing_error_in <= '0';
			sampled_bit <= '0';
		elsif rising_edge(clk) then
			valid_in <= '0';
			parity_error_in <= '0';
			framing_error_in <= '0';
			v_parity_error  := '0';
			v_framing_error := '0';
			if baud_x16_pulse = '1' then
				case state is
					when IDLE =>
						if rx = '0' then
							state <= START_BIT;
							ovs_count <= 0;
							parity_calc <= '0';
						end if;
					
					when START_BIT =>
						if ovs_count = 7 then
							sampled_bit <= rx;
							if rx = '1' then
								state <= IDLE;
							end if;
						end if;
						if ovs_count = 15 then
							if sampled_bit = '0' then
								state <= DATA_BITS;
								bit_count <= 0;
							else
								state <= IDLE;
							end if;
							ovs_count <= 0;
						else
							ovs_count <= ovs_count + 1;
						end if;
					
					when DATA_BITS =>
						if ovs_count = 7 then
							sampled_bit <= rx;
							rx_in(bit_count) <= rx;
							parity_calc <= parity_calc xor rx;
						end if;
						if ovs_count = 15 then
							if bit_count = 7 then
								state <= PARITY_BIT;
							else
								bit_count <= bit_count + 1;
							end if;
							ovs_count <= 0;
						else
							ovs_count <= ovs_count + 1;
						end if;
					
					when PARITY_BIT =>
						if ovs_count = 7 then
							sampled_bit <= rx;
						end if;
						if ovs_count = 15 then
							if sampled_bit /= parity_calc then
								v_parity_error := '1';
							end if;
							state <= STOP_BIT;
							ovs_count <= 0;
						else
							ovs_count <= ovs_count + 1;
						end if;
					
					when STOP_BIT =>
						if ovs_count = 7 then
							sampled_bit <= rx;
						end if;
						if ovs_count = 15 then
							if sampled_bit /= '1' then
								v_framing_error := '1';
							end if;
							parity_error_in  <= v_parity_error;
							framing_error_in <= v_framing_error;
							if v_parity_error = '0' and v_framing_error = '0' then
								valid_in <= '1';
							end if;
							state <= IDLE;
							ovs_count <= 0;
						else
							ovs_count <= ovs_count + 1;
						end if;
					
					when others =>
						state <= IDLE;
				end case;
			end if;
		end if;
	end process;
end architecture;
