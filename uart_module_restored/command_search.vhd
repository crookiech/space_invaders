library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity command_search is
    port (
        clk : in std_logic;
        rst : in std_logic;
        
        -- Интерфейс с UART модулем
        cmd_buffer : in std_logic_vector(63 downto 0);  -- Буфер команды (до 8 символов)
        cmd_length : in integer range 0 to 31;          -- Длина команды
        need_search : in std_logic;                      -- Запуск поиска
        search_ready : out std_logic;                    -- Поиск завершен
        
        -- Результаты поиска
        command_found : out std_logic;                   -- Команда найдена
        command_code : out std_logic_vector(0 to 3);    -- Код команды
        
        -- Интерфейс с ROM
        rom_address : out std_logic_vector(7 downto 0);
        rom_data : in std_logic_vector(7 downto 0);
        rom_clock : out std_logic
    );
end entity;

architecture rtl of command_search is
    constant ROM_SIZE : integer := 112;
    constant ROM_MAX_ADDR : integer := ROM_SIZE - 1;
    
    type search_state_type is (IDLE, READ_ADDR, READ_DATA, COMPARE, 
                               NEXT_COMMAND, FOUND);
    signal search_state : search_state_type := IDLE;
    signal rom_addr : integer range 0 to 127 := 0;
    signal command_start_addr : integer range 0 to 127 := 0;
    signal compare_idx : integer range 0 to 31 := 0;
    signal command_found_flag : std_logic := '0';
    signal search_delay : integer range 0 to 3 := 0;
    signal search_counter : integer range 0 to 255 := 0;
    
begin
    rom_clock <= clk;
    
    process(clk)
        variable rom_char : std_logic_vector(7 downto 0);
        variable buffer_char : std_logic_vector(7 downto 0);
        variable digit_val : integer := 0;
    begin
        if rising_edge(clk) then
            if rst = '0' then
                search_state <= IDLE;
                rom_addr <= 0;
                command_start_addr <= 0;
                compare_idx <= 0;
                command_found_flag <= '0';
                search_ready <= '0';
                command_found <= '0';
                command_code <= (others => '0');
                search_counter <= 0;
                rom_address <= (others => '0');
            else
                search_ready <= '0';
                
                if need_search = '1' then
                    search_state <= READ_ADDR;
                    rom_addr <= 0;
                    compare_idx <= 0;
                    command_found_flag <= '0';
                    search_counter <= 0;
                    command_found <= '0';
                end if;
                
                case search_state is
                    when IDLE =>
                        null;
                        
                    when READ_ADDR =>
                        if rom_addr > ROM_MAX_ADDR then
                            command_found_flag <= '0';
                            search_state <= FOUND;
                        else
                            rom_address <= std_logic_vector(to_unsigned(rom_addr, 8));
                            search_state <= READ_DATA;
                        end if;
                        
                    when READ_DATA =>
                        rom_char := rom_data;
                        if search_counter < 255 then
                            search_counter <= search_counter + 1;
                        end if;
                        if search_counter >= ROM_SIZE then
                            command_found_flag <= '0';
                            search_state <= FOUND;
                        else
                            search_state <= COMPARE;
                        end if;
                        
                    when COMPARE =>
                        if rom_char = x"61" then  -- символ 'a' (разделитель команд)
                            if compare_idx = cmd_length and compare_idx > 0 then
                                command_found_flag <= '1';
                                search_state <= FOUND;
                            else
                                search_state <= NEXT_COMMAND;
                            end if;
                        elsif compare_idx < cmd_length then
                            if compare_idx = 0 then
                                command_start_addr <= rom_addr;
                            end if;
                            buffer_char := cmd_buffer(8*compare_idx+7 downto 8*compare_idx);
                            if buffer_char = rom_char then
                                compare_idx <= compare_idx + 1;
                                rom_addr <= rom_addr + 1;
                                search_state <= READ_ADDR;
                            else
                                search_state <= NEXT_COMMAND;
                            end if;
                        else
                            search_state <= NEXT_COMMAND;
                        end if;
                        
                    when NEXT_COMMAND =>
                        if rom_char /= x"61" then
                            if rom_addr < ROM_MAX_ADDR then
                                rom_addr <= rom_addr + 1;
                                search_state <= READ_ADDR;
                            else
                                command_found_flag <= '0';
                                search_state <= FOUND;
                            end if;
                        else
                            if rom_addr < ROM_SIZE - 1 then
                                rom_addr <= rom_addr + 1;
                            end if;
                            compare_idx <= 0;
                            search_state <= READ_ADDR;
                        end if;
                        
                    when FOUND =>
                        command_found <= command_found_flag;
                        
                        if command_found_flag = '1' and (cmd_length = 6 or cmd_length = 7) then
                            -- Декодирование кода команды
                            if cmd_buffer(7 downto 0) = x"72" and  -- 'r'
                               cmd_buffer(15 downto 8) = x"65" and -- 'e'
                               cmd_buffer(23 downto 16) = x"73" then -- 's'
                                if cmd_length = 7 then
                                    if cmd_buffer(31 downto 24) = x"31" then -- '1'
                                        if cmd_buffer(39 downto 32) = x"30" and   -- '0'
                                           cmd_buffer(47 downto 40) = x"32" and   -- '2'
                                           cmd_buffer(55 downto 48) = x"34" then  -- '4'
                                            command_code <= std_logic_vector(to_unsigned(1, 4));
                                        elsif cmd_buffer(39 downto 32) = x"33" and   -- '3'
                                              cmd_buffer(47 downto 40) = x"36" and   -- '6'
                                              cmd_buffer(55 downto 48) = x"30" then  -- '0'
                                            command_code <= std_logic_vector(to_unsigned(2, 4));
                                        end if;
                                    end if;
                                else
                                    if cmd_buffer(31 downto 24) = x"36" and   -- '6'
                                       cmd_buffer(39 downto 32) = x"34" and   -- '4'
                                       cmd_buffer(47 downto 40) = x"30" then  -- '0'
                                        command_code <= std_logic_vector(to_unsigned(3, 4));
                                    end if;
                                end if;
                            elsif cmd_buffer(7 downto 0) = x"73" and      -- 's'
                                  cmd_buffer(15 downto 8) = x"70" and     -- 'p'
                                  cmd_buffer(23 downto 16) = x"65" and    -- 'e'
                                  cmd_buffer(31 downto 24) = x"65" and    -- 'e'
                                  cmd_buffer(39 downto 32) = x"64" then   -- 'd'
                                if cmd_length = 6 then
                                    if cmd_buffer(47 downto 40) >= x"31" and 
                                       cmd_buffer(47 downto 40) <= x"39" then
                                        digit_val := to_integer(unsigned(cmd_buffer(47 downto 40))) - 48;
                                        command_code <= std_logic_vector(to_unsigned(digit_val + 3, 4));
                                    end if;
                                else
                                    if cmd_buffer(47 downto 40) = x"31" and  -- '1'
                                       cmd_buffer(55 downto 48) = x"30" then -- '0'
                                        command_code <= std_logic_vector(to_unsigned(13, 4));
                                    end if;
                                end if;
                            end if;
                        else
                            command_code <= (others => '0');
                        end if;
                        
                        search_ready <= '1';
                        search_state <= IDLE;
                        search_counter <= 0;
                        command_found_flag <= '0';
                        
                    when others =>
                        search_state <= IDLE;
                end case;
            end if;
        end if;
    end process;
end architecture;