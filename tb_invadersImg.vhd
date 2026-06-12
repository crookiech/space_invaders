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
    signal resolution  : std_logic_vector(1 downto 0) := "00"; -- Свитчи разрешения
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

    -- Подключаем игру
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

    -- Генератор clock_pix (25 MHz)
    clk_process : process
    begin
        clock_pix <= '0'; wait for CLK_PERIOD/2;
        clock_pix <= '1'; wait for CLK_PERIOD/2;
    end process;

    -- Автоподстройка границ кадра под симулируемое разрешение
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

    -- Упрощенный симулятор развертки монитора (без гашения, для скорости симуляции)
    video_simulator : process
    begin
        wait for 100 ns;
        while true loop
            for y in 0 to sim_max_y loop
                pixel_y <= y;
                for x in 0 to sim_max_x loop
                    pixel_x <= x;
                    if x < sim_max_x and y < sim_max_y then
                        video_on <= '1';
                    else
                        video_on <= '0';
                    end if;
                    wait until rising_edge(clock_pix);
                end loop;
            end loop;
            
            -- Конец кадра: формируем импульс refresh
            refresh <= '1';  wait for 200 ns;
            refresh <= '0';  wait for 200 ns;
        end loop;
    end process;

    stimulus_process : process
    begin
        btn_reset <= '1';
        wait for 500 ns;
        btn_reset <= '0';
        wait for 500 ns;
        
        resolution <= "00";
        wait for 60 ms; 
        
        resolution <= "01";
        wait for 60 ms;
        
        -- Конец теста
        assert false report "Simulation Finished!" severity failure;
        wait;
    end process;

end behavior;
