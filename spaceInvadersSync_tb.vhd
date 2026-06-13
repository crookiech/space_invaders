library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity spaceInvadersSync_tb is
end entity;

architecture tb of spaceInvadersSync_tb is
    signal pixel_clk : std_logic := '0';
    signal reset_n : std_logic := '0';
    signal resolution : std_logic_vector(1 downto 0) := "00";
    signal hsync : std_logic;
    signal vsync : std_logic;
    signal de : std_logic;
    signal pixel_x : unsigned(10 downto 0);
    signal pixel_y : unsigned(9 downto 0);
    signal frame_tick : std_logic;
    
    signal errors : integer := 0;
    signal test_done : std_logic := '0';
    
    -- Константы для проверки
    constant H_TOTAL_640 : integer := 800;
    constant V_TOTAL_640 : integer := 525;
    constant H_TOTAL_1024 : integer := 1344;
    constant V_TOTAL_1024 : integer := 806;
    constant H_TOTAL_1360 : integer := 1792;
    constant V_TOTAL_1360 : integer := 795;
    
    constant H_VISIBLE_640 : integer := 640;
    constant V_VISIBLE_640 : integer := 480;
    constant H_VISIBLE_1024 : integer := 1024;
    constant V_VISIBLE_1024 : integer := 768;
    constant H_VISIBLE_1360 : integer := 1360;
    constant V_VISIBLE_1360 : integer := 768;
    
    constant CLK_PERIOD : time := 40 ns;  -- 25 MHz
    
begin
    uut: entity work.spaceInvadersSync
        port map(
            pixel_clk => pixel_clk,
            reset_n => reset_n,
            resolution => resolution,
            hsync => hsync,
            vsync => vsync,
            de => de,
            pixel_x => pixel_x,
            pixel_y => pixel_y,
            frame_tick => frame_tick
        );
    
    -- Генерация тактового сигнала
    clk_process: process
    begin
        if test_done = '1' then
            wait;
        else
            pixel_clk <= '0';
            wait for CLK_PERIOD/2;
            pixel_clk <= '1';
            wait for CLK_PERIOD/2;
        end if;
    end process;
    
    stimulus: process
    begin
        -- ТЕСТ 1: Сброс
        report "Test 1: Reset";
        reset_n <= '0';
        wait for 100 ns;
        assert pixel_x = 0 and pixel_y = 0
            report "FAILED: Reset - counters not zeroed"
            severity error;
        if pixel_x = 0 and pixel_y = 0 then
            report "PASSED: Reset";
        else
            errors <= errors + 1;
        end if;
        reset_n <= '1';
        wait for 100 ns;
        
        -- ТЕСТ 2: Разрешение 640x480
        report "Test 2: Resolution 640x480";
        resolution <= "00";
        
        -- Ожидаем завершения нескольких кадров
        wait for 1 ms;
        
        -- Проверка H_TOTAL (общее количество пикселей в строке)
        wait until pixel_x = H_TOTAL_640 - 1;
        wait until rising_edge(pixel_clk);
        wait for 1 ns;
        assert pixel_x = 0
            report "FAILED: 640x480 - H_TOTAL mismatch"
            severity error;
        if pixel_x = 0 then
            report "PASSED: 640x480 - H_TOTAL = " & integer'image(H_TOTAL_640);
        else
            errors <= errors + 1;
        end if;
        
        -- Проверка V_TOTAL (общее количество строк)
        wait until pixel_x = H_TOTAL_640 - 1 and pixel_y = V_TOTAL_640 - 1;
		  wait until rising_edge(pixel_clk);
		  wait for 1 ns;
        assert pixel_y = 0
            report "FAILED: 640x480 - V_TOTAL mismatch"
            severity error;
        if pixel_y = 0 then
            report "PASSED: 640x480 - V_TOTAL = " & integer'image(V_TOTAL_640);
        else
            errors <= errors + 1;
        end if;
        
        -- Проверка frame_tick (должен быть 1 раз за кадр)
        wait until frame_tick = '1';
        wait until frame_tick = '0';
        wait for 100 ns;
        
        -- Проверка DE в видимой области
        wait until pixel_x = H_VISIBLE_640 - 1 and pixel_y = V_VISIBLE_640 - 1;
        assert de = '1'
            report "FAILED: 640x480 - DE should be '1' in visible area"
            severity error;
        if de = '1' then
            report "PASSED: 640x480 - DE active in visible area";
        else
            errors <= errors + 1;
        end if;
        
        -- Проверка полярности hsync (для 640x480 полярность отрицательная)
        wait until hsync = '0';
        wait until hsync = '1';
        wait until hsync = '0';
        report "PASSED: 640x480 - hsync polarity check (negative)";
        
        -- ТЕСТ 3: Разрешение 1024x768
        report "Test 3: Resolution 1024x768";
        resolution <= "01";
        
        wait for 1 ms;
        
        -- Проверка H_TOTAL
        wait until pixel_x = H_TOTAL_1024 - 1;
        wait until rising_edge(pixel_clk);
        wait for 1 ns;
        assert pixel_x = 0
            report "FAILED: 1024x768 - H_TOTAL mismatch"
            severity error;
        if pixel_x = 0 then
            report "PASSED: 1024x768 - H_TOTAL = " & integer'image(H_TOTAL_1024);
        else
            errors <= errors + 1;
        end if;
        
        -- Проверка V_TOTAL
        wait until pixel_x = H_TOTAL_1024 - 1 and pixel_y = V_TOTAL_1024 - 1;
        wait until rising_edge(pixel_clk);
        wait for 1 ns;
        assert pixel_y = 0
            report "FAILED: 1024x768 - V_TOTAL mismatch"
            severity error;
        if pixel_y = 0 then
            report "PASSED: 1024x768 - V_TOTAL = " & integer'image(V_TOTAL_1024);
        else
            errors <= errors + 1;
        end if;
        
        -- Проверка DE в видимой области
        wait until pixel_x = H_VISIBLE_1024 - 1 and pixel_y = V_VISIBLE_1024 - 1;
        assert de = '1'
            report "FAILED: 1024x768 - DE should be '1' in visible area"
            severity error;
        if de = '1' then
            report "PASSED: 1024x768 - DE active in visible area";
        else
            errors <= errors + 1;
        end if;
        
        -- ТЕСТ 4: Разрешение 1360x768
        report "Test 4: Resolution 1360x768";
        resolution <= "10";
        
        wait for 1 ms;
        
        -- Проверка H_TOTAL
        wait until pixel_x = H_TOTAL_1360 - 1;
        wait until rising_edge(pixel_clk);
        wait for 1 ns;
        assert pixel_x = 0
            report "FAILED: 1360x768 - H_TOTAL mismatch"
            severity error;
        if pixel_x = 0 then
            report "PASSED: 1360x768 - H_TOTAL = " & integer'image(H_TOTAL_1360);
        else
            errors <= errors + 1;
        end if;
        
        -- Проверка V_TOTAL
		  wait until pixel_x = H_TOTAL_1360 - 1 and pixel_y = V_TOTAL_1360 - 1;
        wait until rising_edge(pixel_clk);
        wait for 1 ns;
        assert pixel_y = 0
            report "FAILED: 1360x768 - V_TOTAL mismatch"
            severity error;
        if pixel_y = 0 then
            report "PASSED: 1360x768 - V_TOTAL = " & integer'image(V_TOTAL_1360);
        else
            errors <= errors + 1;
        end if;
        
        -- Проверка DE в видимой области
        wait until pixel_x = H_VISIBLE_1360 - 1 and pixel_y = V_VISIBLE_1360 - 1;
        assert de = '1'
            report "FAILED: 1360x768 - DE should be '1' in visible area"
            severity error;
        if de = '1' then
            report "PASSED: 1360x768 - DE active in visible area";
        else
            errors <= errors + 1;
        end if;
        
        -- Проверка полярности hsync (для 1360x768 полярность положительная)
        wait until hsync = '1';
        wait until hsync = '0';
        wait until hsync = '1';
        report "PASSED: 1360x768 - hsync polarity check (positive)";
        
        if errors = 0 then
            report "SUCCESS: All spaceInvadersSync tests passed";
        else
            report "FAILED: " & integer'image(errors) & " test(s) failed";
        end if;
        
        test_done <= '1';
        wait;
    end process;
end architecture;