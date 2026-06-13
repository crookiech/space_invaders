library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity command_controller_tb is
end entity;

architecture tb of command_controller_tb is
    signal clk : std_logic := '0';
    signal rst : std_logic := '0';
    signal rx : std_logic := '1';
    signal tx : std_logic;
    signal line_valid : std_logic;
    signal right : std_logic;
    signal led0, led1, led2, led3 : std_logic;
    signal command_code_out : std_logic_vector(0 to 3);
    
    constant CLK_PERIOD : time := 20 ns;
    constant BAUD_RATE : integer := 115200;
    constant BIT_PERIOD : time := 8680 ns;
    
    signal tx_data_monitor : std_logic_vector(7 downto 0) := (others => '0');
	signal rx_data_monitor : std_logic_vector(7 downto 0) := (others => '0');
    
    signal errors : integer := 0;
    
    procedure send_char(char_in : std_logic_vector(7 downto 0); signal tx_line : out std_logic) is
    begin
        tx_line <= '0';
        wait for BIT_PERIOD;
        for i in 0 to 7 loop
            tx_line <= char_in(i);
            wait for BIT_PERIOD;
        end loop;
        tx_line <= '1';
        wait for BIT_PERIOD;
    end procedure;
    
    procedure send_string(str : string; signal tx_line : out std_logic) is
    begin
        for i in 1 to str'length loop
            send_char(std_logic_vector(to_unsigned(character'pos(str(i)), 8)), tx_line);
            wait for BIT_PERIOD * 2;
        end loop;
    end procedure;
    
begin
    uut: entity work.command_controller
    port map (
        clk => clk,
        rst => rst,
        rx => rx,
        tx => tx,
        line_valid => line_valid,
        right => right,
        led0 => led0,
        led1 => led1,
        led2 => led2,
        led3 => led3,
        command_code_out => command_code_out
    );
    
    clk_process: process
    begin
        clk <= '0';
        wait for CLK_PERIOD/2;
        clk <= '1';
        wait for CLK_PERIOD/2;
    end process;
    
    process
        variable bit_count : integer := 0;
        variable rx_byte : std_logic_vector(7 downto 0) := (others => '0');
        variable start_bit_detected : boolean := false;
    begin
        wait until falling_edge(tx);
        if not start_bit_detected then
            start_bit_detected := true;
            bit_count := 0;
            wait for BIT_PERIOD/2;
            for i in 0 to 7 loop
                wait for BIT_PERIOD;
                rx_byte(i) := tx;
            end loop;
            wait for BIT_PERIOD;
            start_bit_detected := false;
            tx_data_monitor <= rx_byte;
        end if;
    end process;
	 
	process
        variable bit_count : integer := 0;
        variable rx_byte : std_logic_vector(7 downto 0) := (others => '0');
        variable start_bit_detected : boolean := false;
    begin
        wait until falling_edge(rx);
        if not start_bit_detected then
            start_bit_detected := true;
            bit_count := 0;
            wait for BIT_PERIOD/2;
            for i in 0 to 7 loop
                wait for BIT_PERIOD;
                rx_byte(i) := rx;
            end loop;
            wait for BIT_PERIOD;
            start_bit_detected := false;
            rx_data_monitor <= rx_byte;
        end if;
    end process;
    
    stimulus: process
    begin
        rst <= '0';
        wait for CLK_PERIOD * 5;
        rst <= '1';
        wait for CLK_PERIOD * 10;
        
        report "Starting command_controller tests";
        
        report "Test 1: sending command 'res1024'";
        send_string("res1024", rx);
        send_char(x"0D", rx);
        wait for 2 ms;
        
        if right = '1' then
            report "right = " &std_logic'image(right);
        else
            report "Error";
            errors <= errors + 1;
        end if;
        wait for 200 us;
		  
		report "Test 2: sending command 'res1025'";
        send_string("res1025", rx);
        send_char(x"0D", rx);
        wait for 2 ms;
        
        if right = '0' then
            report "right = " &std_logic'image(right);
        else
            report "Error";
            errors <= errors + 1;
        end if;
        wait for 200 us;
		  
		report "Test 3: sending command 'speed9'";
        send_string("speed9", rx);
        send_char(x"0D", rx);
        wait for 2 ms;
        
        if right = '1' then
            report "right = " &std_logic'image(right);
        else
            report "Error";
            errors <= errors + 1;
        end if;
        wait for 200 us;
		  
		report "Test 4: sending command 'speed10'";
        send_string("speed10", rx);
        send_char(x"0D", rx);
        wait for 2 ms;
        
        if right = '0' then
            report "right = " &std_logic'image(right);
        else
            report "Error";
            errors <= errors + 1;
        end if;
        wait for 200 us;
        
        report "Test 5: sending command 'long command'";
        send_string("long command", rx);
        send_char(x"0D", rx);
        wait for 2 ms;
        
        if right = '0' then
            report "right = " &std_logic'image(right);
        else
            report "Error";
            errors <= errors + 1;
        end if;
        wait for 200 us;
        
        report "Test 6: sending command 'cmd'";
        send_string("cmd", rx);
        send_char(x"0D", rx);
        wait for 2 ms;
        
        if right = '0' then
            report "right = " &std_logic'image(right);
        else
            report "Error";
            errors <= errors + 1;
        end if;
        wait for 200 us;
        
        if errors = 0 then
			report "All command_controller tests completed";
		else 
			report "Number of errors: " & integer'image(errors);
		end if;
        wait;
    end process;
end architecture;
