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

architecture structural of command_controller is
    -- Сигналы для связи между модулями
    signal cmd_buffer : std_logic_vector(63 downto 0);
    signal cmd_length : integer range 0 to 31;
    signal need_search : std_logic;
    signal search_ready : std_logic;
    signal command_found : std_logic;
    signal command_code : std_logic_vector(0 to 3);
    
    -- Сигналы для ROM
    signal rom_address : std_logic_vector(7 downto 0);
    signal rom_data : std_logic_vector(7 downto 0);
    signal rom_clock : std_logic;
    
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
    
begin
    -- Модуль ROM
    rom: entity work.ROM
        port map (
            address => rom_address,
            clock => rom_clock,
            q => rom_data
        );
    
    -- Модуль поиска команд в ROM
    rom_search: entity work.command_search
        port map (
            clk => clk,
            rst => rst,
            cmd_buffer => cmd_buffer,
            cmd_length => cmd_length,
            need_search => need_search,
            search_ready => search_ready,
            command_found => command_found,
            command_code => command_code,
            rom_address => rom_address,
            rom_data => rom_data,
            rom_clock => rom_clock
        );
    
    -- Модуль управления UART
    uart_ctrl: entity work.uart
        port map (
            clk => clk,
            rst => rst,
            rx => rx,
            tx => tx,
            cmd_buffer => cmd_buffer,
            cmd_length => cmd_length,
            need_search => need_search,
            search_ready => search_ready,
            command_found => command_found,
            command_code => command_code,
            line_valid => line_valid,
            right => right,
            led0 => led0,
            led1 => led1,
            led2 => led2,
            led3 => led3,
            command_code_out => command_code_out
        );
        
end architecture;