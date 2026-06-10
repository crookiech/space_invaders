library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity uart is
port (
	clk : in std_logic;
	rst : in std_logic;
	rx_data : in std_logic_vector(7 downto 0);
	rx_valid : in std_logic;
	tx_busy : in std_logic;
	tx_data : out std_logic_vector(7 downto 0);
	tx_start : out std_logic;
	parser_active : in std_logic;
	start_response : in std_logic;
	response_success : in std_logic;
	busy_with_response : out std_logic;
	line_valid : out std_logic
);
end entity;

architecture rtl of uart is
	type chars_array_type is array (0 to 20) of std_logic_vector(7 downto 0);
	signal message : chars_array_type := (others => (others => '0'));
	signal message_len : integer range 0 to 21 := 0;
	signal char_index : integer range 0 to 21 := 0;
	signal busy_in : std_logic := '0';
	
	type state_type is (IDLE, LOAD_CHAR, WAIT_START, WAIT_END, WAIT_TX);
	signal state : state_type := IDLE;
	
	function is_valid_char(data : std_logic_vector(7 downto 0)) return boolean is
		variable char : integer;
	begin
		char := to_integer(unsigned(data));
		if (char >= 65 and char <= 90) or (char >= 97 and char <= 122) or (char >= 48 and char <= 57) or char = 32 or char = 13 or char = 10 then
			return true;
		else
			return false;
		end if;
	end function;
	
	function to_ascii(str : string; len : integer) return chars_array_type is
		variable result : chars_array_type := (others => (others => '0'));
	begin
		for i in 0 to len-1 loop
			result(i) := std_logic_vector(to_unsigned(character'pos(str(i+1)), 8));
		end loop;
		return result;
	end function;
    
begin
	busy_with_response <= busy_in;
	process(clk)
		variable tmp_message : chars_array_type;
	begin
		if rising_edge(clk) then
			if rst = '0' then
				tx_start <= '0';
				busy_in <= '0';
				line_valid <= '0';
				char_index <= 0;
				message_len <= 0;
				tx_data <= (others => '0');
				message <= (others => (others => '0'));
				state <= IDLE;
			else
				tx_start <= '0';
				line_valid <= '0';
				if busy_in = '0' and parser_active = '0' then
					if rx_valid = '1' then
						if is_valid_char(rx_data) and tx_busy = '0' then
							tx_data <= rx_data;
							tx_start <= '1';
						end if;
					end if;
				end if;
				case state is
					when IDLE =>
						if busy_in = '1' then
							busy_in <= '0';
							line_valid <= '1';
						end if;
						if start_response = '1' then
							busy_in <= '1';
							if response_success = '1' then
								tmp_message := to_ascii("OK", 2);
								message(0) <= x"0D";
								message(1) <= x"0A";
								for i in 0 to 1 loop
									message(i + 2) <= tmp_message(i);
								end loop;
								message(4) <= x"0D";
								message(5) <= x"0A";
								message_len <= 6;
							else
								tmp_message := to_ascii("Unknown command", 15);
								message(0) <= x"0D";
								message(1) <= x"0A";
								for i in 0 to 14 loop
									message(i + 2) <= tmp_message(i);
								end loop;
								message(17) <= x"0D";
								message(18) <= x"0A";
								message_len <= 19;
							end if;
							char_index <= 0;
							state <= LOAD_CHAR;
						end if;
					
					when LOAD_CHAR =>
						tx_data <= message(char_index);
						char_index <= char_index + 1;
						state <= WAIT_START;
						
					when WAIT_START =>
						if tx_busy = '0' then
							tx_start <= '1';
							state <= WAIT_END;
						end if;
					
					when WAIT_END =>
						if tx_busy = '1' then
							tx_start <= '0';
							state <= WAIT_TX;
						end if;
					
					when WAIT_TX =>
						if tx_busy = '0' then
							if char_index = message_len then
								state <= IDLE;
							else
								state <= LOAD_CHAR;
							end if;
						end if;
					
					when others =>
						state <= IDLE;
				end case;
			end if;
		end if;
	end process;
end architecture;
