library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity command_code is
    port (
        clk : in std_logic;
        rst : in std_logic;
        command_found : in std_logic;
        char_buffer : in std_logic_vector(63 downto 0);
        char_count : in integer range 0 to 31;
        command_code : out std_logic_vector(0 to 3)
    );
end entity;

architecture rtl of command_code is
    signal internal_code : std_logic_vector(0 to 3) := (others => '0');
begin
    command_code <= internal_code;
    
    process(clk)
        variable digit_val : integer := 0;
    begin
        if rising_edge(clk) then
            if rst = '0' then
                internal_code <= (others => '0');
            else
                if command_found = '1' then
                    if char_buffer(7 downto 0) = x"72" and -- 'r'
                       char_buffer(15 downto 8) = x"65" and -- 'e'
                       char_buffer(23 downto 16) = x"73" then -- 's'
                        if char_count = 7 then
                            if char_buffer(31 downto 24) = x"31" then -- '1'
                                if char_buffer(39 downto 32) = x"30" and -- '0'
                                   char_buffer(47 downto 40) = x"32" and -- '2'
                                   char_buffer(55 downto 48) = x"34" then -- '4'
                                    internal_code <= std_logic_vector(to_unsigned(1, 4));
                                elsif char_buffer(39 downto 32) = x"33" and -- '3'
                                      char_buffer(47 downto 40) = x"36" and -- '6'
                                      char_buffer(55 downto 48) = x"30" then -- '0'
                                    internal_code <= std_logic_vector(to_unsigned(2, 4));
                                end if;
                            end if;
                        else
                            if char_buffer(31 downto 24) = x"36" and -- '6'
                               char_buffer(39 downto 32) = x"34" and -- '4'
                               char_buffer(47 downto 40) = x"30" then -- '0'
                                internal_code <= std_logic_vector(to_unsigned(3, 4));
                            end if;
                        end if;
                    elsif char_buffer(7 downto 0) = x"73" and -- 's'
                          char_buffer(15 downto 8) = x"70" and -- 'p'
                          char_buffer(23 downto 16) = x"65" and -- 'e'
                          char_buffer(31 downto 24) = x"65" and -- 'e'
                          char_buffer(39 downto 32) = x"64" then -- 'd'
                        if char_count = 6 then
                            if char_buffer(47 downto 40) >= x"31" and char_buffer(47 downto 40) <= x"39" then
                                digit_val := to_integer(unsigned(char_buffer(47 downto 40))) - 48;
                                internal_code <= std_logic_vector(to_unsigned(digit_val + 3, 4));
                            end if;
                        else
                            if char_buffer(47 downto 40) = x"31" and -- '1'
                               char_buffer(55 downto 48) = x"30" then -- '0'
                                internal_code <= std_logic_vector(to_unsigned(13, 4));
                            end if;
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;
end architecture;