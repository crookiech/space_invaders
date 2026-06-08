library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity command_controller is
port (
	clk : in std_logic;
	rst : in std_logic;
	rx : in std_logic;
	tx : out std_logic;
	line_valid : out std_logic;
	right : out std_logic;
	led0, led1, led2, led3 : out std_logic;
	command_code_out : out std_logic_vector(0 to 3)
);
end entity;

architecture rtl of command_controller is
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
	signal tx_busy : std_logic;
	signal tx_start : std_logic;
	signal tx_data : std_logic_vector(7 downto 0);
	
	signal rom_address : std_logic_vector(7 downto 0);
	signal rom_data : std_logic_vector(7 downto 0);
	signal rom_clock : std_logic;
	
	signal parser_active : std_logic;
	signal right_in : std_logic;
	signal command_code : std_logic_vector(0 to 3);
	signal start_response : std_logic;
	signal response_success : std_logic;
	signal busy_with_response : std_logic;

begin
	command_code_out <= command_code;
	right <= right_in;
	rom_clock <= clk;
	
	rom: entity work.ROM
	port map (
		address => rom_address,
		clock => rom_clock,
		q => rom_data
	);
	
	gen: entity work.baud_rate_gen
	port map (
		clk => clk,
		rst => rst,
		baud_pulse => baud_pulse,
		baud_x16_pulse => baud_x16_pulse
	);
	
	u_rx: entity work.uart_rx
	port map (
		clk => clk,
		rst => rst,
		baud_x16_pulse => baud_x16_pulse,
		rx => rx,
		data_out => rx_data,
		valid => rx_valid
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
	
	searcher: entity work.command_searcher
	port map (
		clk => clk,
		rst => rst,
		rx_data => rx_data,
		rx_valid => rx_valid,
		rom_data => rom_data,
		rom_address => rom_address,
		parser_active => parser_active,
		cmd_valid_out => right_in,
		cmd_code_out => command_code,
		busy_with_response => busy_with_response,
		start_response => start_response,
		response_success => response_success
	);
	
	uart: entity work.uart
	port map (
		clk => clk,
		rst => rst,
		rx_data => rx_data,
		rx_valid => rx_valid,
		parser_active => parser_active,
		tx_busy => tx_busy,
		tx_data => tx_data,
		tx_start => tx_start,
		start_response => start_response,
		response_success => response_success,
		busy_with_response => busy_with_response,
		line_valid => line_valid
	);
	
	process(clk)
	begin
		if rising_edge(clk) then
			if rst = '0' then
				led0 <= '0';
				led1 <= '0';
				led2 <= '0';
				led3 <= '0';
			else
				if right_in = '1' then
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
			end if;
		end if;
	end process;
end architecture;

