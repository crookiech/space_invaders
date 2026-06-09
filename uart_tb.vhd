library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity uart_tb is
end entity;

architecture tb of uart_tb is
    signal clk : std_logic := '0';
    signal rst : std_logic := '0';
    signal rx_data : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_valid : std_logic := '0';
    signal tx_busy : std_logic := '0';
    signal tx_data : std_logic_vector(7 downto 0);
    signal tx_start : std_logic;
    signal parser_active : std_logic := '0';
    signal start_response : std_logic := '0';
    signal response_success : std_logic := '0';
    signal busy_with_response : std_logic;
    signal line_valid : std_logic;
    
    constant CLK_PERIOD : time := 20 ns;
    constant TX_TIME : time := 87 us;
    
    type byte_array is array (0 to 31) of std_logic_vector(7 downto 0);
    shared variable sent_bytes : byte_array := (others => (others => '0'));
    shared variable sent_count : integer := 0;
    
    signal errors : integer := 0;
    
    procedure send_char(signal rx_data_out : out std_logic_vector(7 downto 0);
        signal rx_valid_out : out std_logic;
        signal clk_sig : in std_logic;
        char_in : std_logic_vector(7 downto 0)) is
    begin
        wait until rising_edge(clk_sig);
        rx_data_out <= char_in;
        rx_valid_out <= '1';
        wait until rising_edge(clk_sig);
        rx_valid_out <= '0';
    end procedure;
    
    procedure send_string(signal rx_data_out : out std_logic_vector(7 downto 0);
        signal rx_valid_out : out std_logic;
        signal clk_sig : in std_logic;
        str : string) is
    begin
        for i in str'range loop
            send_char(rx_data_out, rx_valid_out, clk_sig, std_logic_vector(to_unsigned(character'pos(str(i)), 8)));
            wait for 150 us;
        end loop;
    end procedure;
    
begin
    uut: entity work.uart
    port map (
        clk => clk,
        rst => rst,
        rx_data => rx_data,
        rx_valid => rx_valid,
        tx_busy => tx_busy,
        tx_data => tx_data,
        tx_start => tx_start,
        parser_active => parser_active,
        start_response => start_response,
        response_success => response_success,
        busy_with_response => busy_with_response,
        line_valid => line_valid
    );
    
    clk_process: process
    begin
        clk <= '0';
        wait for CLK_PERIOD/2;
        clk <= '1';
        wait for CLK_PERIOD/2;
    end process;
    
    process(clk)
        variable last_tx_start : std_logic := '0';
    begin
        if rising_edge(clk) then
            if tx_start = '1' and last_tx_start = '0' then
                sent_bytes(sent_count) := tx_data;
                report "TX: x'" & to_hstring(tx_data) & "' (" &character'val(to_integer(unsigned(tx_data))) & ")";
                sent_count := sent_count + 1;
            end if;
            last_tx_start := tx_start;
        end if;
    end process;
    
    process
        variable last_tx_start : std_logic := '0';
    begin
        wait until rising_edge(clk);
        if tx_start = '1' and last_tx_start = '0' then
            tx_busy <= '1';
            wait for TX_TIME;
            tx_busy <= '0';
        end if;
        last_tx_start := tx_start;
    end process;
    
    stimulus: process
        variable local_sent_count : integer := 0;
        variable local_sent_bytes : byte_array := (others => (others => '0'));
    begin
        rst <= '0';
        wait for CLK_PERIOD * 5;
        rst <= '1';
        wait for CLK_PERIOD * 10;
        
        report "Starting uart module tests";
        
        sent_count := 0;
        
        report "Test 1: Echo character 'A'";
        parser_active <= '0';
        send_char(rx_data, rx_valid, clk, x"41");
        wait for 200 us;
        
        local_sent_count := sent_count;
        for i in 0 to local_sent_count-1 loop
            local_sent_bytes(i) := sent_bytes(i);
        end loop;
        
        if not(local_sent_count = 1 and local_sent_bytes(0) = x"41") then
            report "Error";
            errors <= errors + 1;
        end if;
        wait for 100 us;
        		  
        sent_count := 0;
        
        report "Test 2: Send OK response";
        start_response <= '1';
        response_success <= '1';
        wait for CLK_PERIOD * 2;
        start_response <= '0';
        wait for 600 us;
        
        local_sent_count := sent_count;
        for i in 0 to local_sent_count-1 loop
            local_sent_bytes(i) := sent_bytes(i);
        end loop;
        
        if not(local_sent_count = 6 and 
            local_sent_bytes(0) = x"0D" and local_sent_bytes(1) = x"0A" and
            local_sent_bytes(2) = x"4F" and local_sent_bytes(3) = x"4B" and
            local_sent_bytes(4) = x"0D" and local_sent_bytes(5) = x"0A") then
            report "Error";
            errors <= errors + 1;
        end if;
        wait for 100 us;
        
        sent_count := 0;
        
        report "Test 3: Send 'Unknown command' response";
        start_response <= '1';
        response_success <= '0';
        wait for CLK_PERIOD * 2;
        start_response <= '0';
        wait for 1700 us;
        
        local_sent_count := sent_count;
        for i in 0 to local_sent_count-1 loop
            local_sent_bytes(i) := sent_bytes(i);
        end loop;
        
        if not(local_sent_count = 19 and
            local_sent_bytes(0) = x"0D" and local_sent_bytes(1) = x"0A" and
            local_sent_bytes(2) = x"55" and local_sent_bytes(3) = x"6E" and
            local_sent_bytes(4) = x"6B" and local_sent_bytes(5) = x"6E" and
            local_sent_bytes(6) = x"6F" and local_sent_bytes(7) = x"77" and
            local_sent_bytes(8) = x"6E" and local_sent_bytes(9) = x"20" and
            local_sent_bytes(10) = x"63" and local_sent_bytes(11) = x"6F" and
            local_sent_bytes(12) = x"6D" and local_sent_bytes(13) = x"6D" and
            local_sent_bytes(14) = x"61" and local_sent_bytes(15) = x"6E" and
            local_sent_bytes(16) = x"64" and local_sent_bytes(17) = x"0D" and 
            local_sent_bytes(18) = x"0A") then
            report "Error";
            errors <= errors + 1;
        end if;
        wait for 100 us;
		  
		sent_count := 0;
        
        report "Test 4: Send string 'Hello'";
        parser_active <= '0';
        send_string(rx_data, rx_valid, clk, "Hello");
        wait for 800 us;
        
        local_sent_count := sent_count;
        for i in 0 to local_sent_count-1 loop
            local_sent_bytes(i) := sent_bytes(i);
        end loop;
        
        if not(local_sent_count = 5 and local_sent_bytes(0) = x"48" and local_sent_bytes(1) = x"65" and
            local_sent_bytes(2) = x"6C" and local_sent_bytes(3) = x"6C" and local_sent_bytes(4) = x"6F") then
            report "Error";
            errors <= errors + 1;
        end if;
        wait for 100 us;
        
        if errors = 0 then
            report "All uart tests completed";
        else
            report "Number of errors: " & integer'image(errors);
        end if;
        wait;
    end process;
end architecture;
