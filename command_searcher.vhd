library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity command_searcher is
port (
	clk : in std_logic;
	rst : in std_logic;
	rx_data : in std_logic_vector(7 downto 0);
	rx_valid : in std_logic;
	start_response : out std_logic;
	busy_with_response : in std_logic;
	response_success : out std_logic;
	parser_active : out std_logic;
	rom_data : in std_logic_vector(7 downto 0);
	rom_address : out std_logic_vector(7 downto 0);
	cmd_valid_out : out std_logic;
	cmd_code_out : out std_logic_vector(0 to 3)
);
end entity;

architecture rtl of command_searcher is
	constant ROM_SIZE : integer := 96;
	constant ROM_MAX_ADDR : integer := ROM_SIZE - 1;
	
	signal char_buffer : std_logic_vector(63 downto 0) := (others => '0');
	signal char_count : integer range 0 to 31 := 0;
	signal char_overflow : std_logic := '0';
	signal command_code : std_logic_vector(0 to 3) := (others => '0');
	signal right_in : std_logic := '0';
	
	type search_state_type is (IDLE, READ_ADDR, READ_DATA, COMPARE, NEXT_COMMAND, COMMAND_FOUND);
	signal search_state : search_state_type := IDLE;
	signal rom_address_in : integer range 0 to 127 := 0;
	signal command_start_address : integer range 0 to 127 := 0;
	signal compare_index : integer range 0 to 31 := 0;
	signal command_found_flag : std_logic := '0';
	signal need_to_search : std_logic := '0';
	signal search_counter : integer range 0 to 255 := 0;
	
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
    
begin
	parser_active <= need_to_search;
	cmd_valid_out <= right_in;
	cmd_code_out <= command_code;
	process(clk)
		variable rom_char : std_logic_vector(7 downto 0);
		variable buffer_char : std_logic_vector(7 downto 0);
		variable digit_val : integer := 0;
	begin
		if rising_edge(clk) then
			if rst = '0' then
				char_count <= 0;
				char_overflow <= '0';
				right_in <= '0';
				rom_address_in <= 0;
				command_start_address <= 0;
				command_found_flag <= '0';
				compare_index <= 0;
				need_to_search <= '0';
				search_counter <= 0;
				start_response <= '0';
				response_success <= '0';
				command_code <= (others => '0');
				char_buffer <= (others => '0');
				rom_address <= (others => '0');
				search_state <= IDLE;
			else
				start_response <= '0';
				if busy_with_response = '0' and need_to_search = '0' then
					if rx_valid = '1' then
						if is_valid_char(rx_data) then
							if rx_data = x"0D" or rx_data = x"0A" then
								if char_count > 0 then
									need_to_search <= '1';
									rom_address_in <= 0;
									command_start_address <= 0;
									compare_index <= 0;
									command_found_flag <= '0';
									search_counter <= 0;
									search_state <= READ_ADDR;
								end if;
							elsif char_count < 8 then
								char_buffer(8*char_count+7 downto 8*char_count) <= rx_data;
								char_count <= char_count + 1;
							else
								char_overflow <= '1';
								if char_count < 31 then
									char_count <= char_count + 1;
								end if;
							end if;
						end if;
					end if;
				end if;
				if need_to_search = '1' then
					command_found_flag <= '0';
					case search_state is
						when IDLE =>
							null;
						
						when READ_ADDR =>
							if rom_address_in > ROM_MAX_ADDR then
								command_found_flag <= '0';
								search_state <= COMMAND_FOUND;
							elsif char_count > 8 or char_count < 6 then
								search_state <= COMMAND_FOUND;
							else
								rom_address <= std_logic_vector(to_unsigned(rom_address_in, 8));
								search_state <= READ_DATA;
							end if;
						
						when READ_DATA =>
							rom_char := rom_data;
							if search_counter < 255 then
								search_counter <= search_counter + 1;
							end if;
							if search_counter >= ROM_SIZE then
								command_found_flag <= '0';
								search_state <= COMMAND_FOUND;
							else
								search_state <= COMPARE;
							end if;
						
						when COMPARE =>
							if rom_char = x"23" then
								if compare_index = char_count and compare_index > 0 then
									command_found_flag <= '1';
									search_state <= COMMAND_FOUND;
								else
									search_state <= NEXT_COMMAND;
								end if;
							elsif compare_index < char_count then
								if compare_index = 0 then
									command_start_address <= rom_address_in;
								end if;
								buffer_char := char_buffer(8*compare_index+7 downto 8*compare_index);
								if buffer_char = rom_char then
									compare_index <= compare_index + 1;
									rom_address_in <= rom_address_in + 1;
									search_state <= READ_ADDR;
								else
									search_state <= NEXT_COMMAND;
								end if;
							else
								search_state <= NEXT_COMMAND;
							end if;
						
						when NEXT_COMMAND =>
							if rom_char /= x"23" then
								if rom_address_in < ROM_MAX_ADDR then
									rom_address_in <= rom_address_in + 1;
									search_state <= READ_ADDR;
								else
									command_found_flag <= '0';
									search_state <= COMMAND_FOUND;
								end if;
							else
								if rom_address_in < ROM_SIZE - 1 then
									rom_address_in <= rom_address_in + 1;
								end if;
								compare_index <= 0;
								search_state <= READ_ADDR;
							end if;
							
						when COMMAND_FOUND =>
							start_response <= '1';
							if command_found_flag = '1' and (char_count = 6 or char_count = 7) then
								right_in <= '1';
								response_success <= '1';
								if char_buffer(7 downto 0) = x"72" and
									char_buffer(15 downto 8) = x"65" and
									char_buffer(23 downto 16) = x"73" then
									if char_count = 7 then
										if char_buffer(31 downto 24) = x"31" then
											if char_buffer(39 downto 32) = x"30" and
												char_buffer(47 downto 40) = x"32" and
												char_buffer(55 downto 48) = x"34" then
												command_code <= std_logic_vector(to_unsigned(1, 4));
											elsif char_buffer(39 downto 32) = x"33" and
												char_buffer(47 downto 40) = x"36" and
												char_buffer(55 downto 48) = x"30" then
												command_code <= std_logic_vector(to_unsigned(2, 4));
											end if;
										end if;
									else
										if char_buffer(31 downto 24) = x"36" and
											char_buffer(39 downto 32) = x"34" and
											char_buffer(47 downto 40) = x"30" then
											command_code <= std_logic_vector(to_unsigned(3, 4));
										else
											right_in <= '0';
											response_success <= '0';
										end if;
									end if;
								elsif char_buffer(7 downto 0) = x"73" and
										char_buffer(15 downto 8) = x"70" and
										char_buffer(23 downto 16) = x"65" and
										char_buffer(31 downto 24) = x"65" and
										char_buffer(39 downto 32) = x"64" then
										digit_val := to_integer(unsigned(char_buffer(47 downto 40))) - 48;
										command_code <= std_logic_vector(to_unsigned(digit_val + 3, 4));
								end if;
							else
								right_in <= '0';
								response_success <= '0';
								command_code <= (others => '0');
							end if;
							char_count <= 0;
							char_overflow <= '0';
							char_buffer <= (others => '0');
							need_to_search <= '0';
							search_state <= IDLE;
							search_counter <= 0;
							
						when others =>
							search_state <= IDLE;
					end case;
				end if;
			end if;
		end if;
	end process;
end architecture;
