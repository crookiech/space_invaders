library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity command_searcher_tb is
end entity;

architecture tb of command_searcher_tb is
    signal clk : std_logic := '0';
    signal rst : std_logic := '0';
    signal rx_data : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_valid : std_logic := '0';
    signal start_response : std_logic;
    signal busy_with_response : std_logic := '0';
    signal response_success : std_logic;
    signal parser_active : std_logic;
    signal rom_data : std_logic_vector(7 downto 0) := (others => '0');
    signal rom_address : std_logic_vector(7 downto 0);
    signal cmd_valid_out : std_logic;
    signal cmd_code_out : std_logic_vector(0 to 3);
    
    constant CLK_PERIOD : time := 20 ns;
    
    type rom_array is array (0 to 111) of std_logic_vector(7 downto 0);
    signal rom_content : rom_array := (others => (others => '0'));
    
    signal errors : integer := 0;
    
begin
    uut: entity work.command_searcher
    port map (
        clk => clk,
        rst => rst,
        rx_data => rx_data,
        rx_valid => rx_valid,
        start_response => start_response,
        busy_with_response => busy_with_response,
        response_success => response_success,
        parser_active => parser_active,
        rom_data => rom_data,
        rom_address => rom_address,
        cmd_valid_out => cmd_valid_out,
        cmd_code_out => cmd_code_out
    );
    
    clk_process: process
    begin
        clk <= '0';
        wait for CLK_PERIOD/2;
        clk <= '1';
        wait for CLK_PERIOD/2;
    end process;
    
    rom_process: process(rom_address)
        variable addr_int : integer;
    begin
        addr_int := to_integer(unsigned(rom_address));
        if addr_int < 95 then
            rom_data <= rom_content(addr_int);
        else
            rom_data <= (others => '0');
        end if;
    end process;
    
    stimulus: process
        procedure send_char(char_in : std_logic_vector(7 downto 0)) is
        begin
            wait until rising_edge(clk);
            rx_data <= char_in;
            rx_valid <= '1';
            wait until rising_edge(clk);
            rx_valid <= '0';
            wait for CLK_PERIOD;
        end procedure;
        
        procedure send_string(str : string) is
            variable char_idx : integer;
        begin
            for char_idx in str'range loop
                send_char(std_logic_vector(to_unsigned(character'pos(str(char_idx)), 8)));
            end loop;
        end procedure;
        
    begin
        rom_content(0) <= x"72";
        rom_content(1) <= x"65";
        rom_content(2) <= x"73";
        rom_content(3) <= x"31";
        rom_content(4) <= x"30";
        rom_content(5) <= x"32";
        rom_content(6) <= x"34";
        rom_content(7) <= x"23";

        rom_content(8) <= x"72";
        rom_content(9) <= x"65";
        rom_content(10) <= x"73";
        rom_content(11) <= x"31";
        rom_content(12) <= x"33";
        rom_content(13) <= x"36";
        rom_content(14) <= x"30";
        rom_content(15) <= x"23";
            
        rom_content(16) <= x"72";
        rom_content(17) <= x"65";
        rom_content(18) <= x"73";
        rom_content(19) <= x"36";
        rom_content(20) <= x"34";
        rom_content(21) <= x"30";
        rom_content(22) <= x"23";
        rom_content(23) <= x"23";
            
        rom_content(24) <= x"73";
        rom_content(25) <= x"70";
        rom_content(26) <= x"65";
        rom_content(27) <= x"65";
        rom_content(28) <= x"64";
        rom_content(29) <= x"31";
        rom_content(30) <= x"23";
        rom_content(31) <= x"23";
            
        rom_content(32) <= x"73";
        rom_content(33) <= x"70";
        rom_content(34) <= x"65";
        rom_content(35) <= x"65";
        rom_content(36) <= x"64";
        rom_content(37) <= x"32";
        rom_content(38) <= x"23";
        rom_content(39) <= x"23";
            
        rom_content(40) <= x"73";
        rom_content(41) <= x"70";
        rom_content(42) <= x"65";
        rom_content(43) <= x"65";
        rom_content(44) <= x"64";
        rom_content(45) <= x"33";
        rom_content(46) <= x"23";
        rom_content(47) <= x"23";
            
        rom_content(48) <= x"73";
        rom_content(49) <= x"70";
        rom_content(50) <= x"65";
        rom_content(51) <= x"65";
        rom_content(52) <= x"64";
        rom_content(53) <= x"34";
        rom_content(54) <= x"23";
        rom_content(55) <= x"23";
            
        rom_content(56) <= x"73";
        rom_content(57) <= x"70";
        rom_content(58) <= x"65";
        rom_content(59) <= x"65";
        rom_content(60) <= x"64";
        rom_content(61) <= x"35";
        rom_content(62) <= x"23";
        rom_content(63) <= x"23";
            
        rom_content(64) <= x"73";
        rom_content(65) <= x"70";
        rom_content(66) <= x"65";
        rom_content(67) <= x"65";
        rom_content(68) <= x"64";
        rom_content(69) <= x"36";
        rom_content(70) <= x"23";
        rom_content(71) <= x"23";
            
        rom_content(72) <= x"73";
        rom_content(73) <= x"70";
        rom_content(74) <= x"65";
        rom_content(75) <= x"65";
        rom_content(76) <= x"64";
        rom_content(77) <= x"37";
        rom_content(78) <= x"23";
        rom_content(79) <= x"23";
            
        rom_content(80) <= x"73";
        rom_content(81) <= x"70";
        rom_content(82) <= x"65";
        rom_content(83) <= x"65";
        rom_content(84) <= x"64";
        rom_content(85) <= x"38";
        rom_content(86) <= x"23";
        rom_content(87) <= x"23";
            
        rom_content(88) <= x"73";
        rom_content(89) <= x"70";
        rom_content(90) <= x"65";
        rom_content(91) <= x"65";
        rom_content(92) <= x"64";
        rom_content(93) <= x"39";
        rom_content(94) <= x"23";
        rom_content(95) <= x"23";
        
        rst <= '0';
        wait for CLK_PERIOD * 3;
        rst <= '1';
        wait for CLK_PERIOD * 2;
        
        report "Starting command_searcher tests";
        
        report "Test 1: sending command 'res1024'";
        send_string("res1024");
        send_char(x"0D");
        wait for CLK_PERIOD * 50;
        if cmd_valid_out = '0' and cmd_code_out(0) = '0' and cmd_code_out(1) = '0' and cmd_code_out(2) = '0' and cmd_code_out(3) = '0' then
            report "Error";
            errors <= errors + 1;
        else
            report "cmd_valid_out = " & std_logic'image(cmd_valid_out) & " cmd_code_out = " &
            std_logic'image(cmd_code_out(0)) &
            std_logic'image(cmd_code_out(1)) &
            std_logic'image(cmd_code_out(2)) &
            std_logic'image(cmd_code_out(3));
        end if;
		  
        report "Test 2: sending command 'res1360'";
        send_string("res1360");
        send_char(x"0D");
		wait for CLK_PERIOD * 100;
        if cmd_valid_out = '0' and cmd_code_out(0) = '0' and cmd_code_out(1) = '0' and cmd_code_out(2) = '0' and cmd_code_out(3) = '1' then
			report "Error";
			errors <= errors + 1;
		else
			report "cmd_valid_out = " & std_logic'image(cmd_valid_out) & " cmd_code_out = " &
			std_logic'image(cmd_code_out(0)) &
			std_logic'image(cmd_code_out(1)) &
			std_logic'image(cmd_code_out(2)) &
			std_logic'image(cmd_code_out(3));
		end if;
		  
        report "Test 3: sending command 'res640'";
        send_string("res640");
        send_char(x"0D");
		wait for CLK_PERIOD * 100;
        if cmd_valid_out = '0' and cmd_code_out(0) = '0' and cmd_code_out(1) = '0' and cmd_code_out(2) = '1' and cmd_code_out(3) = '1' then
			report "Error";
			errors <= errors + 1;
		else
			report "cmd_valid_out = " & std_logic'image(cmd_valid_out) & " cmd_code_out = " &
			std_logic'image(cmd_code_out(0)) &
			std_logic'image(cmd_code_out(1)) &
			std_logic'image(cmd_code_out(2)) &
			std_logic'image(cmd_code_out(3));
		end if;
		  
        report "Test 4: sending command 'speed1'";
        send_string("speed1");
        send_char(x"0D");
		wait for CLK_PERIOD * 150;
        if cmd_valid_out = '0' and cmd_code_out(0) = '0' and cmd_code_out(1) = '1' and cmd_code_out(2) = '0' and cmd_code_out(3) = '0' then
			report "Error";
			errors <= errors + 1;
		else
			report "cmd_valid_out = " & std_logic'image(cmd_valid_out) & " cmd_code_out = " &
			std_logic'image(cmd_code_out(0)) &
			std_logic'image(cmd_code_out(1)) &
			std_logic'image(cmd_code_out(2)) &
			std_logic'image(cmd_code_out(3));
		end if;
		  
        report "Test 5: sending command 'speed2'";
        send_string("speed2");
        send_char(x"0D");
		wait for CLK_PERIOD * 200;
        if cmd_valid_out = '0' and cmd_code_out(0) = '0' and cmd_code_out(1) = '1' and cmd_code_out(2) = '0' and cmd_code_out(3) = '1' then
			report "Error";
			errors <= errors + 1;
		else
			report "cmd_valid_out = " & std_logic'image(cmd_valid_out) & " cmd_code_out = " &
			std_logic'image(cmd_code_out(0)) &
			std_logic'image(cmd_code_out(1)) &
			std_logic'image(cmd_code_out(2)) &
			std_logic'image(cmd_code_out(3));
		end if;
		  
        report "Test 6: sending command 'speed3'";
        send_string("speed3");
        send_char(x"0D");
		wait for CLK_PERIOD * 250;
        if cmd_valid_out = '0' and cmd_code_out(0) = '0' and cmd_code_out(1) = '1' and cmd_code_out(2) = '1' and cmd_code_out(3) = '0' then
			report "Error";
			errors <= errors + 1;
		else
			report "cmd_valid_out = " & std_logic'image(cmd_valid_out) & " cmd_code_out = " &
			std_logic'image(cmd_code_out(0)) &
			std_logic'image(cmd_code_out(1)) &
			std_logic'image(cmd_code_out(2)) &
			std_logic'image(cmd_code_out(3));
		end if;
		  
        report "Test 7: sending command 'speed4'";
        send_string("speed4");
        send_char(x"0D");
		wait for CLK_PERIOD * 300;
        if cmd_valid_out = '0' and cmd_code_out(0) = '0' and cmd_code_out(1) = '1' and cmd_code_out(2) = '1' and cmd_code_out(3) = '1' then
			report "Error";
			errors <= errors + 1;
		else
			report "cmd_valid_out = " & std_logic'image(cmd_valid_out) & " cmd_code_out = " &
			std_logic'image(cmd_code_out(0)) &
			std_logic'image(cmd_code_out(1)) &
			std_logic'image(cmd_code_out(2)) &
			std_logic'image(cmd_code_out(3));
		end if;
		  
        report "Test 8: sending command 'speed5'";
        send_string("speed5");
        send_char(x"0D");
		wait for CLK_PERIOD * 350;
        if cmd_valid_out = '0' and cmd_code_out(0) = '1' and cmd_code_out(1) = '0' and cmd_code_out(2) = '0' and cmd_code_out(3) = '0' then
			report "Error";
			errors <= errors + 1;
		else
			report "cmd_valid_out = " & std_logic'image(cmd_valid_out) & " cmd_code_out = " &
			std_logic'image(cmd_code_out(0)) &
			std_logic'image(cmd_code_out(1)) &
			std_logic'image(cmd_code_out(2)) &
			std_logic'image(cmd_code_out(3));
		end if;
		  
        report "Test 9: sending command 'speed6'";
        send_string("speed6");
        send_char(x"0D");
		wait for CLK_PERIOD * 400;
        if cmd_valid_out = '0' and cmd_code_out(0) = '1' and cmd_code_out(1) = '0' and cmd_code_out(2) = '0' and cmd_code_out(3) = '1' then
			report "Error";
			errors <= errors + 1;
		else
			report "cmd_valid_out = " & std_logic'image(cmd_valid_out) & " cmd_code_out = " &
			std_logic'image(cmd_code_out(0)) &
			std_logic'image(cmd_code_out(1)) &
			std_logic'image(cmd_code_out(2)) &
			std_logic'image(cmd_code_out(3));
		end if;
		  
        report "Test 10: sending command 'speed7'";
        send_string("speed7");
        send_char(x"0D");
		wait for CLK_PERIOD * 450;
        if cmd_valid_out = '0' and cmd_code_out(0) = '1' and cmd_code_out(1) = '0' and cmd_code_out(2) = '1' and cmd_code_out(3) = '0' then
			report "Error";
			errors <= errors + 1;
		else
			report "cmd_valid_out = " & std_logic'image(cmd_valid_out) & " cmd_code_out = " &
			std_logic'image(cmd_code_out(0)) &
			std_logic'image(cmd_code_out(1)) &
			std_logic'image(cmd_code_out(2)) &
			std_logic'image(cmd_code_out(3));
		end if;
		  
        report "Test 11: sending command 'speed8'";
        send_string("speed8");
        send_char(x"0D");
		wait for CLK_PERIOD * 500;
        if cmd_valid_out = '0' and cmd_code_out(0) = '1' and cmd_code_out(1) = '0' and cmd_code_out(2) = '1' and cmd_code_out(3) = '1' then
			report "Error";
			errors <= errors + 1;
		else
			report "cmd_valid_out = " & std_logic'image(cmd_valid_out) & " cmd_code_out = " &
			std_logic'image(cmd_code_out(0)) &
			std_logic'image(cmd_code_out(1)) &
			std_logic'image(cmd_code_out(2)) &
			std_logic'image(cmd_code_out(3));
		end if;
		  
        report "Test 12: sending command 'speed9'";
        send_string("speed9");
        send_char(x"0D");
		wait for CLK_PERIOD * 550;
        if cmd_valid_out = '0' and cmd_code_out(0) = '1' and cmd_code_out(1) = '1' and cmd_code_out(2) = '0' and cmd_code_out(3) = '0' then
			report "Error";
			errors <= errors + 1;
		else
			report "cmd_valid_out = " & std_logic'image(cmd_valid_out) & " cmd_code_out = " &
			std_logic'image(cmd_code_out(0)) &
			std_logic'image(cmd_code_out(1)) &
			std_logic'image(cmd_code_out(2)) &
			std_logic'image(cmd_code_out(3));
		end if;
		  
        report "Test 13: sending command 'long command'";
        send_string("long command");
        send_char(x"0D");
		wait for CLK_PERIOD * 30;
        if cmd_valid_out = '0' and cmd_code_out(0) = '0' and cmd_code_out(1) = '0' and cmd_code_out(2) = '0' and cmd_code_out(3) = '0' then
			report "cmd_valid_out = " & std_logic'image(cmd_valid_out) & " cmd_code_out = " &
			std_logic'image(cmd_code_out(0)) &
			std_logic'image(cmd_code_out(1)) &
			std_logic'image(cmd_code_out(2)) &
			std_logic'image(cmd_code_out(3));
		else
			report "Error";
			errors <= errors + 1;
		end if;
        
		report "Test 14: sending command 'cmd'";
        send_string("cmd");
        send_char(x"0D");
        if cmd_valid_out = '0' and cmd_code_out(0) = '0' and cmd_code_out(1) = '0' and cmd_code_out(2) = '0' and cmd_code_out(3) = '0' then
			report "cmd_valid_out = " & std_logic'image(cmd_valid_out) & " cmd_code_out = " &
			std_logic'image(cmd_code_out(0)) &
			std_logic'image(cmd_code_out(1)) &
			std_logic'image(cmd_code_out(2)) &
			std_logic'image(cmd_code_out(3));
		else
			report "Error";
			errors <= errors + 1;
		end if;
        
		if errors = 0 then
			report "All command_searcher tests completed";
		else 
			report "Number of errors: " & integer'image(errors);
		end if;
        wait;
    end process;
end architecture;