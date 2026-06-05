library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity uart is
    port (
        clk : in std_logic;
        rst : in std_logic;
        
        -- UART интерфейс
        rx : in std_logic;
        tx : out std_logic;
        
        -- Интерфейс с модулем поиска ROM
        cmd_buffer : out std_logic_vector(63 downto 0);
        cmd_length : out integer range 0 to 31;
        need_search : out std_logic;  -- Это out, но мы читаем его внутри
        search_ready : in std_logic;
        command_found : in std_logic;
        command_code : in std_logic_vector(0 to 3);
        
        -- Выходные сигналы
        line_valid : out std_logic;
        right : out std_logic;
        led0, led1, led2, led3 : out std_logic;
        command_code_out : out std_logic_vector(0 to 3)
    );
end entity;

architecture rtl of uart is
    signal baud_pulse : std_logic;
    signal baud_x16_pulse : std_logic;
    signal rx_data : std_logic_vector(7 downto 0);
    signal rx_valid : std_logic;
    signal tx_busy : std_logic;
    signal tx_start : std_logic;
    signal tx_data : std_logic_vector(7 downto 0);
    
    signal char_buffer : std_logic_vector(63 downto 0) := (others => '0');
    signal char_count : integer range 0 to 31 := 0;
    signal char_overflow : std_logic := '0';
    signal internal_right : std_logic := '0';
    
    type chars_array_t is array (0 to 20) of std_logic_vector(7 downto 0);
    signal message : chars_array_t;
    signal msg_len : integer range 0 to 21 := 0;
    signal char_index : integer range 0 to 21 := 0;
    signal busy_with_response : std_logic := '0';
    
    type state_type is (IDLE_STATE, LOAD_CHAR, WAIT_START, WAIT_END, WAIT_TX);
    signal state : state_type := IDLE_STATE;
    
    -- Внутренний сигнал для need_search (решение проблемы)
    signal need_search_int : std_logic := '0';
    
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
    need_search <= need_search_int;  -- Присваиваем внутренний сигнал выходному порту
    
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
    
    process(clk)
        variable tmp_msg : chars_array_t;
    begin
        if rising_edge(clk) then
            if rst = '0' then
                tx_start <= '0';
                char_count <= 0;
                char_overflow <= '0';
                busy_with_response <= '0';
                state <= IDLE_STATE;
                internal_right <= '0';
                char_buffer <= (others => '0');
                line_valid <= '0';
                need_search_int <= '0';  -- Используем внутренний сигнал
                cmd_length <= 0;
                
                led0 <= '0';
                led1 <= '0';
                led2 <= '0';
                led3 <= '0';
            else
                tx_start <= '0';
                line_valid <= '0';
                
                -- Управление LED индикаторами
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
                
                -- FSM для отправки ответа
                case state is
                    when IDLE_STATE =>
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
                                state <= IDLE_STATE;
                            else
                                state <= LOAD_CHAR;
                            end if;
                        end if;
                        
                    when others =>
                        state <= IDLE_STATE;
                end case;
                
                -- Прием символов через UART
                if busy_with_response = '0' and search_ready = '1' then
                    need_search_int <= '0';  -- Используем внутренний сигнал
                end if;
                
                if busy_with_response = '0' and need_search_int = '0' then  -- Читаем внутренний сигнал
                    if rx_valid = '1' then
                        -- Эхо-ответ
                        if tx_busy = '0' then
                            tx_data <= rx_data;
                            tx_start <= '1';
                        end if;
                        
                        -- Обработка полученного символа
                        if rx_data = x"0D" or rx_data = x"0A" then
                            if char_count > 0 then
                                need_search_int <= '1';  -- Используем внутренний сигнал
                                cmd_length <= char_count;
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
                
                cmd_buffer <= char_buffer;
                
                -- Формирование ответа после завершения поиска
                if search_ready = '1' and need_search_int = '1' then  -- Используем внутренний сигнал
                    if command_found = '1' then
                        internal_right <= '1';
                        tmp_msg := to_ascii("OK", 2);
                        message(0) <= x"0D";
                        message(1) <= x"0A";
                        for i in 0 to 1 loop
                            message(i + 2) <= tmp_msg(i);
                        end loop;
                        message(4) <= x"0D";
                        message(5) <= x"0A";
                        msg_len <= 6;
                    else
                        internal_right <= '0';
                        tmp_msg := to_ascii("Unknown command", 15);
                        message(0) <= x"0D";
                        message(1) <= x"0A";
                        for i in 0 to 14 loop
                            message(i + 2) <= tmp_msg(i);
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
                end if;
            end if;
        end if;
    end process;
end architecture;