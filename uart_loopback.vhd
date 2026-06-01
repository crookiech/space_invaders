library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity uart_loopback is
	port (
		clk : in std_logic;
		rst : in std_logic;
		rx : in std_logic;
		tx : out std_logic;
		line_valid : out std_logic;
		right : out std_logic;
		led0 : out std_logic;
		led1 : out std_logic;
		led2 : out std_logic;
		led3 : out std_logic;
		command_code_out : out std_logic_vector(0 to 3)
	);
end entity;

architecture rtl of uart_loopback is
	attribute chip_pin : string;
	attribute chip_pin of clk : signal is "R20";
	attribute chip_pin of rst : signal is "Y16";
	attribute chip_pin of tx : signal is "L9";
	attribute chip_pin of rx : signal is "M9";
	attribute chip_pin of right : signal is "H9";
	attribute chip_pin of led0 : signal is "J10";
	attribute chip_pin of led1 : signal is "H7";
	attribute chip_pin of led2 : signal is "K8";
	attribute chip_pin of led3 : signal is "K10";
	
	signal baud_pulse : std_logic;
	signal baud_x16_pulse : std_logic;
	signal rx_data : std_logic_vector(7 downto 0);
	signal rx_valid : std_logic;
	signal parity_error : std_logic;
	signal framing_error : std_logic;
	signal tx_busy : std_logic;
	signal tx_start : std_logic;
	signal tx_data : std_logic_vector(7 downto 0);
	signal char_buffer : std_logic_vector(63 downto 0) := (others => '0');
	signal char_count : integer range 0 to 31 := 0;
	signal char_overflow : std_logic := '0';
	signal command_code : std_logic_vector(0 to 3) := (others => '0');
	signal internal_right : std_logic := '0';
	type chars_array_t is array (0 to 20) of std_logic_vector(7 downto 0);
	signal message : chars_array_t;
	signal msg_len : integer range 0 to 21 := 0;
	signal char_index : integer range 0 to 21 := 0;
	signal busy_with_response : std_logic := '0';
	
	type state_type is (IDLE, LOAD_CHAR, WAIT_START, WAIT_END, WAIT_TX);
	signal state : state_type := IDLE;
	
	function to_ascii(str : string; len : integer) return chars_array_t is
		variable result : chars_array_t := (others => (others => '0'));
	begin
		for i in 0 to len-1 loop
			result(i) := std_logic_vector(to_unsigned(character'pos(str(i+1)), 8));
		end loop;
		return result;
	end function;
    
begin
	command_code_out <= command_code;
	right <= internal_right;
	
	gen: entity work.baud_rate_gen
	port map (
		clk => clk,
		rst => rst,
		baud_pulse => baud_pulse,
		baud_x16_pulse => baud_x16_pulse);
	
	u_rx: entity work.uart_rx
	port map (
		clk => clk,
		rst => rst,
		baud_x16_pulse => baud_x16_pulse,
		rx => rx,
		data_out => rx_data,
		valid => rx_valid,
		parity_error => parity_error,
		framing_error => framing_error
	);
	
	u_tx: entity work.uart_tx
	port map (
		clk => clk,
		rst => rst,
		baud_pulse => baud_pulse,
		data_in => tx_data,
		start => tx_start,
		tx => tx,
		busy => tx_busy
	);
	
	process(clk)
		variable match_found : boolean;
		variable tmp_msg : chars_array_t;
		variable digit_val : integer := 0;
	begin
		if rising_edge(clk) then
			if rst = '0' then
				tx_start <= '0';
				char_count <= 0;
				char_overflow <= '0';
				internal_right <= '0';
				busy_with_response <= '0';
				state <= IDLE;
				command_code <= (others => '0');
				led0 <= '0';
            led1 <= '0';
            led2 <= '0';
            led3 <= '0';
			else
				tx_start <= '0';
				line_valid <= '0';
				if internal_right = '1' then
                led0 <= command_code(0);
                led1 <= command_code(1);
                led2 <= command_code(2);
                led3 <= command_code(3);
            else
                led0 <= '0';
                led1 <= '0';
                led2 <= '0';
                led3 <= '0';
            end if;
				if busy_with_response = '0' then
					if rx_valid = '1' then
						if tx_busy = '0' then
							tx_data <= rx_data;
							tx_start <= '1';
						end if;
						if rx_data = x"0D" then
							match_found := false;
							if char_overflow = '1' then
								match_found := false;
							else
							-- Проверка res1024 и res1028
							if char_count = 7 then
								if char_buffer(7 downto 0) = x"72" and -- 'r'
									char_buffer(15 downto 8) = x"65" and -- 'e'
									char_buffer(23 downto 16) = x"73" and -- 's'
									char_buffer(31 downto 24) = x"31" and -- '1'
									char_buffer(39 downto 32) = x"30" and -- '0'
									char_buffer(47 downto 40) = x"32" then -- '2'
									if char_buffer(55 downto 48) = x"34" then -- '4'
										match_found := true;
										command_code <= std_logic_vector(to_unsigned(1, 4));
									elsif char_buffer(55 downto 48) = x"38" then -- '8'
										match_found := true;
										command_code <= std_logic_vector(to_unsigned(2, 4));
									end if;
								end if;
							end if;
							-- Проверка speed1..speed10
							if not match_found then
								if char_count = 6 or char_count = 7 then
									if char_buffer(7 downto 0) = x"73" and -- 's'
										char_buffer(15 downto 8) = x"70" and -- 'p'
										char_buffer(23 downto 16) = x"65" and -- 'e'
										char_buffer(31 downto 24) = x"65" and -- 'e'
										char_buffer(39 downto 32) = x"64" then -- 'd'
										if char_count = 6 then
											if char_buffer(47 downto 40) >= x"31" and char_buffer(47 downto 40) <= x"39" then
												digit_val := to_integer(unsigned(char_buffer(47 downto 40))) - 48;
												match_found := true;
												command_code <= std_logic_vector(to_unsigned(digit_val + 2, 4));
											end if;
										else
											if char_buffer(47 downto 40) = x"31" and -- '1'
												char_buffer(55 downto 48) = x"30" then -- '0'
												match_found := true;
												command_code <= std_logic_vector(to_unsigned(12, 4));
											end if;
										end if;
									end if;
								end if;
							end if;
						end if;
						if match_found then
							internal_right <= '1';
							tmp_msg := to_ascii("OK", 2);
							message(0) <= x"0D";
							message(1) <= x"0A";
							for i_msg in 0 to 1 loop
								message(i_msg + 2) <= tmp_msg(i_msg);
							end loop;
							message(4) <= x"0D";
							message(5) <= x"0A";
							msg_len <= 6;
						else
							internal_right <= '0';
							tmp_msg := to_ascii("Unknown command", 15);
							message(0) <= x"0D";
							message(1) <= x"0A";
							for i_msg in 0 to 14 loop
								message(i_msg + 2) <= tmp_msg(i_msg);
							end loop;
							message(17) <= x"0D";
							message(18) <= x"0A";
							msg_len <= 19;
						end if;
						char_index <= 0;
						state <= LOAD_CHAR;
						busy_with_response <= '1';
						char_count <= 0;
						char_overflow <= '0';
						char_buffer <= (others => '0');
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
			case state is
				when IDLE =>
					if busy_with_response = '1' then
						busy_with_response <= '0';
						line_valid <= '1';
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
						if char_index = msg_len then
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

