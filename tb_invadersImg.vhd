library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_invadersImg is
end tb_invadersImg;

architecture behavior of tb_invadersImg is

    signal clock_pix   : std_logic := '0';
    signal refresh     : std_logic := '0';
    signal video_on    : std_logic := '0';
    signal btn_left    : std_logic := '0';
    signal btn_right   : std_logic := '0';
    signal btn_fire    : std_logic := '0';
    signal btn_start   : std_logic := '0';
    signal btn_reset   : std_logic := '1';
    signal pause       : std_logic := '0';
    signal resolution  : std_logic_vector(1 downto 0) := "00";
    signal wave_speed  : integer := 0;
    
    signal pixel_x     : integer range 0 to 2047 := 0;
    signal pixel_y     : integer range 0 to 1023 := 0;
    
    signal red_out     : std_logic_vector(7 downto 0);
    signal green_out   : std_logic_vector(7 downto 0);
    signal blue_out    : std_logic_vector(7 downto 0);

    constant CLK_PERIOD : time := 40 ns; -- 25 МГц

    signal sim_max_x : integer := 640;
    signal sim_max_y : integer := 480;

begin

    -- Подключаем тестируемый игровой модуль
    uut: entity work.invadersImg
        port map (
            clock_pix   => clock_pix,
            refresh     => refresh,
            video_on    => video_on,
            btn_left    => btn_left,
            btn_right   => btn_right,
            btn_fire    => btn_fire,
            btn_start   => btn_start,
            btn_reset   => btn_reset,
            pause       => pause,
            resolution  => resolution,
            wave_speed  => wave_speed,
            pixel_x     => pixel_x,
            pixel_y     => pixel_y,
            red_out     => red_out,
            green_out   => green_out,
            blue_out    => blue_out
        );

    -- 1. Стабильный генератор clock_pix
    clk_process : process
    begin
        clock_pix <= '0'; wait for CLK_PERIOD/2;
        clock_pix <= '1'; wait for CLK_PERIOD/2;
    end process;

    -- 2. Автоподстройка под симулируемое разрешение
    process(resolution)
    begin
        if resolution = "00" then
            sim_max_x <= 640; sim_max_y <= 480;
        elsif resolution = "01" then
            sim_max_x <= 1024; sim_max_y <= 768;
        else
            sim_max_x <= 1360; sim_max_y <= 768;
        end if;
    end process;

    -- 3. Легковесный генератор координат луча (без вложенных тяжелых циклов)
    pixel_counter_process : process(clock_pix)
    begin
        if rising_edge(clock_pix) then
            if pixel_x < sim_max_x then
                pixel_x <= pixel_x + 1;
            else
                pixel_x <= 0;
                if pixel_y < sim_max_y then
                    pixel_y <= pixel_y + 1;
                else
                    pixel_y <= 0;
                end if;
            end if;
        end if;
    end process;

    video_on <= '1' when (pixel_x < sim_max_x and pixel_y < sim_max_y) else '0';

    -- 4. СТАБИЛЬНЫЙ ГЕНЕРАТОР REFRESH: выдает импульс строго каждые 10 мс!
    -- Теперь симулятору не нужно считать миллионы пикселей, чтобы дернуть refresh.
    refresh_generator : process
    begin
        refresh <= '0';
        wait for 10 ms; -- Длина кадра в симуляции равна ровно 10 мс (100 Гц)
        refresh <= '1';
        wait for 10 us; -- Длительность импульса
        refresh <= '0';
    end process;

    -- 5. СЦЕНАРИЙ СИМУЛЯЦИИ (Очень быстрый и наглядный)
    stimulus_process : process
    begin
        -- Сброс в начале
        btn_reset <= '1';
        wait for 1 ms;
        btn_reset <= '0';
        wait for 5 ms;
        
        -- Разрешение 640x480 (Ждем 30 мс, чтобы гарантированно прошло 3 кадра по 10 мс)
        resolution <= "00";
        wait for 30 ms; 
        
        -- Разрешение 1024x768 (Ждем 30 мс)
        resolution <= "01";
        wait for 30 ms;
        
        -- Разрешение 1360x768 (Ждем 30 мс)
        resolution <= "10";
        wait for 30 ms;
        
        -- Конец симуляции
        assert false report "Simulation Finished!" severity failure;
        wait;
    end process;

end behavior;
