library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity invadersImg is
   port(
        clock_25  : in std_logic;
        refresh   : in std_logic;
        video_on  : in std_logic;
        -- Управление
        btn_left  : in std_logic;
        btn_right : in std_logic;
        btn_fire  : in std_logic;
        btn_start : in std_logic;
        btn_reset : in std_logic;
        pause     : in std_logic;
        
        pixel_x   : in integer range 0 to 2047;
        pixel_y   : in integer range 0 to 1023;
        
        red_out   : out std_logic_vector(7 downto 0);
        green_out : out std_logic_vector(7 downto 0);
        blue_out  : out std_logic_vector(7 downto 0)
   );
end invadersImg;

architecture behavior of invadersImg is
    -- Состояния игры
    type state_type is (MENU, PLAYING, GAME_OVER);
    signal state : state_type := MENU;

    -- Параметры экрана
    constant MAX_X : integer := 640;
    constant MAX_Y : integer := 480;

    -- Корабль игрока (Tank)
    constant TANK_W : integer := 30;
    constant TANK_H : integer := 16;
    constant TANK_Y : integer := 440;
    signal tank_x   : integer range 0 to MAX_X := 305;
    
    -- Пуля игрока
    signal bullet_x      : integer range 0 to MAX_X := 0;
    signal bullet_y      : integer range 0 to MAX_Y := 0;
    signal bullet_active : std_logic := '0';
    
    -- Пуля пришельцев
    signal e_bullet_x      : integer range 0 to MAX_X := 0;
    signal e_bullet_y      : integer range 0 to MAX_Y := 0;
    signal e_bullet_active : std_logic := '0';
    
    -- Пришельцы
    constant ALIEN_W    : integer := 24;
    constant ALIEN_H    : integer := 16;
    constant ALIEN_GAP  : integer := 16;
    constant ROWS       : integer := 4;
    constant COLS       : integer := 8;
    constant MAX_ALIENS_PER_WAVE : integer := ROWS * COLS;
    
    type alien_array is array (0 to ROWS-1, 0 to COLS-1) of std_logic;
    signal aliens_alive : alien_array := (others => (others => '1'));
    
    signal aliens_x_off : integer range 0 to MAX_X := 50;
    signal aliens_y_off : integer range 0 to MAX_Y := 40;
    signal aliens_dir   : std_logic := '1'; -- 1: вправо, 0: влево
    
    -- Скорости
type speed_array_type is array (0 to 10) of integer;
    constant ALIEN_MOVE_SPEED_FRAMES : speed_array_type := (
        0 => 40, 1 => 40, 2 => 35, 3 => 30, 4 => 25, 5 => 20, 6 => 18, 7 => 16, 8 => 14, 9 => 12, 10 => 10
    );
    constant ALIEN_SHOOT_SPEED_FRAMES : speed_array_type := (
        0 => 60, 1 => 60, 2 => 55, 3 => 50, 4 => 45, 5 =>	 40, 6 => 35, 7 => 30, 8 => 25, 9 => 20, 10 => 15
    );

    signal alien_timer  : integer range 0 to 60 := 0;
    signal shoot_timer  : integer range 0 to 120 := 0;
    signal lfsr         : std_logic_vector(7 downto 0) := "10101010";

    -- Сигналы отрисовки объектов
    signal tank_on, p_bullet_on, e_bullet_on, alien_on : std_logic;
    signal pause_on : std_logic;
    signal alien_invasion_gameover : std_logic := '0';

    -- Статистика
    signal score               : integer range 0 to 99999 := 0;
    signal lives               : integer range 0 to 3 := 3;
    signal wave                : integer range 0 to 10 := 0;
    signal aliens_killed_count : integer range 0 to MAX_ALIENS_PER_WAVE := 0;

    -- Сигналы анимаций (мигание кнопок и плавное появление текста)
    signal blink_reg      : unsigned(5 downto 0) := (others => '0');
    signal blink_on       : std_logic := '0';
    signal gameover_timer : integer range 0 to 1023 := 0;

    ------------------------------------------------------------------------------------------------
    -- Шрифт 5x7 для Цифр и Букв (Добавлены буквы G и M)
    ------------------------------------------------------------------------------------------------
    function is_char_pixel (
        px, py : integer;
        char_val : integer; -- 0..9: цифры, 10: S, 11: P, 12: A, 13: C, 14: E, 15: I, 16: N, 17: V, 18: D, 19: R, 20: K, 21: Y, 22: T, 23: O, 24: пробел, 25: G, 26: M
        start_x, start_y : integer;
        scale : integer
    ) return std_logic is
        constant CHAR_WIDTH  : integer := 5;
        constant CHAR_HEIGHT : integer := 7;
        variable local_x, local_y : integer;
        
        type char_pattern_array is array (0 to 26) of std_logic_vector(34 downto 0);
        constant FONT_5X7 : char_pattern_array := (
            -- Цифры 0-9
            0  => "01110" & "10001" & "10001" & "10001" & "10001" & "10001" & "01110", -- 0
            1  => "00100" & "01100" & "00100" & "00100" & "00100" & "00100" & "01110", -- 1
            2  => "01110" & "10001" & "00001" & "00110" & "01000" & "10000" & "11111", -- 2
            3  => "11111" & "00001" & "01110" & "00001" & "00001" & "10001" & "01110", -- 3
            4  => "10001" & "10001" & "10001" & "11111" & "00001" & "00001" & "00001", -- 4
            5  => "11111" & "10000" & "10000" & "11111" & "00001" & "00001" & "01110", -- 5
            6  => "01110" & "10000" & "10000" & "11111" & "10001" & "10001" & "01110", -- 6
            7  => "11111" & "00001" & "00001" & "00001" & "00001" & "00001" & "00001", -- 7
            8  => "01110" & "10001" & "10001" & "01110" & "10001" & "10001" & "01110", -- 8
            9  => "01110" & "10001" & "10001" & "01110" & "00001" & "00001" & "01110", -- 9
            -- Буквы
            10 => "01110" & "10000" & "10000" & "01110" & "00001" & "00001" & "01110", -- S
            11 => "11110" & "10001" & "10001" & "11110" & "10000" & "10000" & "10000", -- P
            12 => "01110" & "10001" & "10001" & "11111" & "10001" & "10001" & "10001", -- A
            13 => "01110" & "10001" & "10000" & "10000" & "10000" & "10001" & "01110", -- C
            14 => "11111" & "10000" & "10000" & "11110" & "10000" & "10000" & "11111", -- E
            15 => "01110" & "00100" & "00100" & "00100" & "00100" & "00100" & "01110", -- I
            16 => "10001" & "11001" & "10101" & "10101" & "10011" & "10011" & "10001", -- N
            17 => "10001" & "10001" & "10001" & "10001" & "10001" & "01010" & "00100", -- V
            18 => "11110" & "10001" & "10001" & "10001" & "10001" & "10001" & "11110", -- D
            19 => "11110" & "10001" & "10001" & "11110" & "10100" & "10010" & "10001", -- R
            20 => "10001" & "10010" & "10100" & "11000" & "10100" & "10010" & "10001", -- K
            21 => "10001" & "10001" & "01010" & "00100" & "00100" & "00100" & "00100", -- Y
            22 => "11111" & "00100" & "00100" & "00100" & "00100" & "00100" & "00100", -- T
            23 => "01110" & "10001" & "10001" & "10001" & "10001" & "10001" & "01110", -- O
            24 => (others => '0'),                                                      -- Пробел
            25 => "01110" & "10001" & "10000" & "10111" & "10001" & "10001" & "01110", -- G
            26 => "10001" & "11011" & "10101" & "10001" & "10001" & "10001" & "10001"  -- M
        );
    begin
        local_x := (px - start_x) / scale;
        local_y := (py - start_y) / scale;

        if local_x >= 0 and local_x < CHAR_WIDTH and
           local_y >= 0 and local_y < CHAR_HEIGHT then
            -- 34 - (...) исправляет отражение по горизонтали и вертикали
            return FONT_5X7(char_val)(34 - ((local_y * CHAR_WIDTH) + local_x));
        else
            return '0';
        end if;
    end function;

begin
    -- LFSR генератор (шум)
    process(clock_25)
    begin
        if rising_edge(clock_25) then
            lfsr <= lfsr(6 downto 0) & (lfsr(7) xnor lfsr(5) xnor lfsr(4) xnor lfsr(3));
        end if;
    end process;


    ------------------------------------------------------------------------------------------------
    -- ЛОГИКА ИГРЫ (60 Гц)
    ------------------------------------------------------------------------------------------------
    process(refresh, btn_reset)
        variable shoot_col : integer range 0 to COLS-1;
        variable found_alien : boolean;
        variable all_aliens_dead : boolean;
        variable temp_aliens_alive : alien_array;
    begin
        if btn_reset = '1' then
            state <= MENU;
            tank_x <= 305;
            bullet_active <= '0';
            e_bullet_active <= '0';
            aliens_alive <= (others => (others => '1'));
            aliens_x_off <= 50;
            aliens_y_off <= 40;
            score <= 0;
            lives <= 3;
            wave <= 0;
            aliens_killed_count <= 0;
            alien_timer <= 0;
            shoot_timer <= 0;
            aliens_dir <= '1';
            alien_invasion_gameover <= '0';
            blink_reg <= (others => '0');
            blink_on <= '0';
            gameover_timer <= 0;
        elsif rising_edge(refresh) then
            -- Генератор мигания
            if blink_reg = 29 then
                blink_reg <= (others => '0');
                blink_on <= not blink_on;
            else
                blink_reg <= blink_reg + 1;
            end if;

            if pause = '0' then
                case state is
                    when MENU =>
                        gameover_timer <= 0; -- Сброс таймера анимации смерти
                        if btn_start = '1' then
                            state <= PLAYING;
                            score <= 0;
                            lives <= 3;
                            wave <= 1;
                            aliens_killed_count <= 0;
                            aliens_alive <= (others => (others => '1'));
                            aliens_x_off <= 50;
					aliens_y_off <= 40;
                            bullet_active <= '0';
                            e_bullet_active <= '0';
                            alien_timer <= 0;
                            shoot_timer <= 0;
                            aliens_dir <= '1';
                            alien_invasion_gameover <= '0';
                        end if;
                        
                    when PLAYING =>
                        -- ВАЖНО: Принудительно удерживаем таймер в 0 во время игры.
                        -- Это гарантирует, что при смерти анимация ВСЕГДА начнется с самого начала.
                        gameover_timer <= 0; 
                        
                        -- 1. Проверка Game Over по вторжению
                        found_alien := false;
                        for r in 0 to ROWS-1 loop
                            for c in 0 to COLS-1 loop
                                if aliens_alive(r,c) = '1' then
                                    if (aliens_y_off + r*(ALIEN_H+ALIEN_GAP) + ALIEN_H) >= TANK_Y then
                                        found_alien := true;
                                    end if;
                                end if;
                            end loop;
                        end loop;

                        if found_alien then
                            alien_invasion_gameover <= '1';
                            state <= GAME_OVER;
                        end if;

                        -- 2. Движение корабля игрока
                        if btn_left = '1' and tank_x > 10 then
                            tank_x <= tank_x - 3;
                        elsif btn_right = '1' and tank_x < (MAX_X - TANK_W - 10) then
                            tank_x <= tank_x + 3;
                        end if;

                        -- 3. Пуля игрока
                        if bullet_active = '0' then
                            if btn_fire = '1' then
                                bullet_active <= '1';
                                bullet_x <= tank_x + 15;
                                bullet_y <= TANK_Y - 5;
                            end if;
                        else
                            bullet_y <= bullet_y - 7;
                            if bullet_y < 10 then bullet_active <= '0'; end if;
                        end if;

                        -- 4. Движение пришельцев
                        alien_timer <= alien_timer + 1;
                        if alien_timer = ALIEN_MOVE_SPEED_FRAMES(wave) then
                            alien_timer <= 0;
                            if aliens_dir = '1' then
                                if aliens_x_off < (MAX_X - (COLS * (ALIEN_W + ALIEN_GAP)) - 50) then
                                    aliens_x_off <= aliens_x_off + 8;
                                else
                                    aliens_dir <= '0';
                                    aliens_y_off <= aliens_y_off + 15;
                                end if;
                            else
                                if aliens_x_off > 30 then
                                    aliens_x_off <= aliens_x_off - 8;
                                else
                                    aliens_dir <= '1';
                                    aliens_y_off <= aliens_y_off + 15;
                                end if;
                            end if;
                        end if;

                        -- 5. Стрельба пришельцев
                        if e_bullet_active = '0' then
                            shoot_timer <= shoot_timer + 1;
                            if shoot_timer >= ALIEN_SHOOT_SPEED_FRAMES(wave) then
                                shoot_timer <= 0;
                                shoot_col := to_integer(unsigned(lfsr(2 downto 0))) mod COLS;
                                found_alien := false;
                                for r_idx in ROWS-1 downto 0 loop
                                    if aliens_alive(r_idx, shoot_col) = '1' then
                                        e_bullet_active <= '1';
                                        e_bullet_x <= aliens_x_off + shoot_col*(ALIEN_W+ALIEN_GAP) + ALIEN_W/2;
                                        e_bullet_y <= aliens_y_off + r_idx*(ALIEN_H+ALIEN_GAP) + ALIEN_H;
                                        found_alien := true;
                                        exit;
                                    end if;
                                end loop;
                            end if;
                        else
                            e_bullet_y <= e_bullet_y + 5;
                            if e_bullet_y > MAX_Y then e_bullet_active <= '0'; end if;
                        end if;

                        -- 6. Коллизия: Пуля игрока -> Пришелец
                        all_aliens_dead := true;
                        temp_aliens_alive := aliens_alive;
                        for r in 0 to ROWS-1 loop
                            for c in 0 to COLS-1 loop
                                if aliens_alive(r,c) = '1' then
                                    all_aliens_dead := false;
                                    if bullet_active = '1' then
                                        if bullet_x >= (aliens_x_off + c*(ALIEN_W+ALIEN_GAP)) and
                                           bullet_x <= (aliens_x_off + c*(ALIEN_W+ALIEN_GAP) + ALIEN_W) and
                                           bullet_y >= (aliens_y_off + r*(ALIEN_H+ALIEN_GAP)) and
                                           bullet_y <= (aliens_y_off + r*(ALIEN_H+ALIEN_GAP) + ALIEN_H) then
                                               temp_aliens_alive(r,c) := '0';
                                               bullet_active <= '0';
                                               score <= score + 10;
                                               aliens_killed_count <= aliens_killed_count + 1;
                                        end if;
                                    end if;
                                end if;
                            end loop;
                        end loop;
                        aliens_alive <= temp_aliens_alive;

                        -- Конец волны
                        if aliens_killed_count = MAX_ALIENS_PER_WAVE then
                            if wave < 10 then
                                wave <= wave + 1;
                                if lives < 3 then lives <= lives + 1; end if;
                                aliens_killed_count <= 0;
                                aliens_alive <= (others => (others => '1'));
                                aliens_x_off <= 50;
                                aliens_y_off <= 40;
                                alien_timer <= 0;
                                shoot_timer <= 0;
                                bullet_active <= '0';
                                e_bullet_active <= '0';
                            end if;
                        end if;
                        
                        -- 7. Коллизия: Пуля врага -> Игрок
                        if e_bullet_active = '1' and
                           e_bullet_x >= tank_x and e_bullet_x <= tank_x + TANK_W and
                           e_bullet_y >= TANK_Y and e_bullet_y <= TANK_Y + TANK_H then
                            lives <= lives - 1;
                            e_bullet_active <= '0';
                            if lives = 0 then
                                state <= GAME_OVER;
                            end if;
                        end if;

                    when GAME_OVER =>
                        if gameover_timer < 1023 then
                            gameover_timer <= gameover_timer + 3; 
                        end if;

                        if btn_start = '1' then 
                            state <= MENU; 
                        end if;
                end case;
            end if;
        end if;
    end process;





    ------------------------------------------------------------------------------------------------
    -- ГРАФИКА
    ------------------------------------------------------------------------------------------------
    
    -- Синхронная отрисовка объектов во время PLAYING
    process(clock_25)
    begin
        if rising_edge(clock_25) then
            -- Танк (Корабль)
            if state = PLAYING and (
                (pixel_x >= tank_x and pixel_x <= tank_x + TANK_W and pixel_y >= TANK_Y+5 and pixel_y <= TANK_Y+TANK_H) or
                (pixel_x >= tank_x+12 and pixel_x <= tank_x+18 and pixel_y >= TANK_Y and pixel_y <= TANK_Y+5)
            ) then
                tank_on <= '1';
            else 
                tank_on <= '0';
            end if;

            -- Пуля игрока
            if state = PLAYING and bullet_active = '1' and pixel_x >= bullet_x-1 and pixel_x <= bullet_x+1 and pixel_y >= bullet_y and pixel_y <= bullet_y+6 then 
                p_bullet_on <= '1';
            else 
                p_bullet_on <= '0';
            end if;
             
            -- Пуля врага
            if state = PLAYING and e_bullet_active = '1' and pixel_x >= e_bullet_x-1 and pixel_x <= e_bullet_x+1 and pixel_y >= e_bullet_y and pixel_y <= e_bullet_y+8 then 
                e_bullet_on <= '1';
            else 
                e_bullet_on <= '0';
            end if;
        end if;
    end process;

    -- Пришельцы
    process(clock_25)
        variable rel_x : integer;
        variable rel_y : integer;
        variable col_idx : integer;
        variable row_idx : integer;
        variable alien_pixel_x : integer;
        variable alien_pixel_y : integer;
    begin
        if rising_edge(clock_25) then
            alien_on <= '0';
            if state = PLAYING then
                rel_x := pixel_x - aliens_x_off;
                rel_y := pixel_y - aliens_y_off;
                
                if rel_x >= 0 and rel_x < (COLS * 40) and rel_y >= 0 and rel_y < (ROWS * 32) then
                    col_idx := rel_x / 40; 
                    row_idx := rel_y / 32;
                    
                    alien_pixel_x := rel_x mod 40;
                    alien_pixel_y := rel_y mod 32;
                    
                    if aliens_alive(row_idx, col_idx) = '1' and alien_pixel_x < ALIEN_W and alien_pixel_y < ALIEN_H then
                        if not ((alien_pixel_y < 4 and (alien_pixel_x < 4 or alien_pixel_x > ALIEN_W-5)) or 
                                (alien_pixel_y > ALIEN_H-5 and (alien_pixel_x < 4 or alien_pixel_x > ALIEN_W-5))) then
                            alien_on <= '1';
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- Пауза
    pause_on <= '1' when pause = '1' and ((pixel_x >= 310 and pixel_x <= 315) or (pixel_x >= 325 and pixel_x <= 330)) 
                    and (pixel_y >= 220 and pixel_y <= 260) else '0';

    ------------------------------------------------------------------------------------------------
    -- ЦВЕТОВАЯ СХЕМА
    ------------------------------------------------------------------------------------------------
    process(video_on, tank_on, p_bullet_on, e_bullet_on, alien_on, pause_on,
            pixel_x, pixel_y, score, lives, state, blink_on, gameover_timer)

        variable hud_pixel_on : std_logic;
        variable menu_char_on : std_logic;
        
        -- Расстояния до центров 4 кнопок платы
        variable dist3, dist2, dist1, dist0 : integer;
    begin
        if video_on = '0' then
            red_out <= (others => '0'); green_out <= (others => '0'); blue_out <= (others => '0');
        else
            -- Фон по умолчанию: черный
            red_out <= (others => '0'); green_out <= (others => '0'); blue_out <= (others => '0');

            -- 1. СЦЕНА МЕНЮ (Все остальное закрыто черным)
            if state = MENU then
                menu_char_on := '0';
                
                -- Текст "SPACE INVADERS" (Масштаб = 4, Y = 120, Шаг = 24 пикселя)
                if pixel_y >= 120 and pixel_y < 148 then
                    if is_char_pixel(pixel_x, pixel_y, 10, 152 + 0*24, 120, 4) = '1' then menu_char_on := '1'; end if; -- S
                    if is_char_pixel(pixel_x, pixel_y, 11, 152 + 1*24, 120, 4) = '1' then menu_char_on := '1'; end if; -- P
                    if is_char_pixel(pixel_x, pixel_y, 12, 152 + 2*24, 120, 4) = '1' then menu_char_on := '1'; end if; -- A
                    if is_char_pixel(pixel_x, pixel_y, 13, 152 + 3*24, 120, 4) = '1' then menu_char_on := '1'; end if; -- C
                    if is_char_pixel(pixel_x, pixel_y, 14, 152 + 4*24, 120, 4) = '1' then menu_char_on := '1'; end if; -- E
                    -- Пробел (индекс 24)
                    if is_char_pixel(pixel_x, pixel_y, 15, 152 + 6*24, 120, 4) = '1' then menu_char_on := '1'; end if; -- I
                    if is_char_pixel(pixel_x, pixel_y, 16, 152 + 7*24, 120, 4) = '1' then menu_char_on := '1'; end if; -- N
                    if is_char_pixel(pixel_x, pixel_y, 17, 152 + 8*24, 120, 4) = '1' then menu_char_on := '1'; end if; -- V
                    if is_char_pixel(pixel_x, pixel_y, 12, 152 + 9*24, 120, 4) = '1' then menu_char_on := '1'; end if; -- A
                    if is_char_pixel(pixel_x, pixel_y, 18, 152 + 10*24, 120, 4) = '1' then menu_char_on := '1'; end if; -- D
                    if is_char_pixel(pixel_x, pixel_y, 14, 152 + 11*24, 120, 4) = '1' then menu_char_on := '1'; end if; -- E
                    if is_char_pixel(pixel_x, pixel_y, 19, 152 + 12*24, 120, 4) = '1' then menu_char_on := '1'; end if; -- R
                    if is_char_pixel(pixel_x, pixel_y, 10, 152 + 13*24, 120, 4) = '1' then menu_char_on := '1'; end if; -- S
                end if;
                
                if menu_char_on = '1' then
                    red_out <= "00000000"; green_out <= "11111111"; blue_out <= "00000000"; -- Зеленый заголовок
                    menu_char_on := '0';
                end if;

                -- Текст "PRESS KEY3 TO START" (Масштаб = 2, Y = 220, Шаг = 12 пикселей)
                if pixel_y >= 220 and pixel_y < 234 then
                    -- PRESS
                    if is_char_pixel(pixel_x, pixel_y, 11, 208 + 0*12, 220, 2) = '1' then menu_char_on := '1'; end if; -- P
                    if is_char_pixel(pixel_x, pixel_y, 19, 208 + 1*12, 220, 2) = '1' then menu_char_on := '1'; end if; -- R
                    if is_char_pixel(pixel_x, pixel_y, 14, 208 + 2*12, 220, 2) = '1' then menu_char_on := '1'; end if; -- E
                    if is_char_pixel(pixel_x, pixel_y, 10, 208 + 3*12, 220, 2) = '1' then menu_char_on := '1'; end if; -- S
                    if is_char_pixel(pixel_x, pixel_y, 10, 208 + 4*12, 220, 2) = '1' then menu_char_on := '1'; end if; -- S
                    -- KEY3
                    if is_char_pixel(pixel_x, pixel_y, 20, 208 + 6*12, 220, 2) = '1' then menu_char_on := '1'; end if; -- K
                    if is_char_pixel(pixel_x, pixel_y, 14, 208 + 7*12, 220, 2) = '1' then menu_char_on := '1'; end if; -- E
                    if is_char_pixel(pixel_x, pixel_y, 21, 208 + 8*12, 220, 2) = '1' then menu_char_on := '1'; end if; -- Y
                    if is_char_pixel(pixel_x, pixel_y, 3,  208 + 9*12, 220, 2) = '1' then menu_char_on := '1'; end if; -- 3
                    -- TO
                    if is_char_pixel(pixel_x, pixel_y, 22, 208 + 11*12, 220, 2) = '1' then menu_char_on := '1'; end if; -- T
                    if is_char_pixel(pixel_x, pixel_y, 23, 208 + 12*12, 220, 2) = '1' then menu_char_on := '1'; end if; -- O
                    -- START
                    if is_char_pixel(pixel_x, pixel_y, 10, 208 + 14*12, 220, 2) = '1' then menu_char_on := '1'; end if; -- S
                    if is_char_pixel(pixel_x, pixel_y, 22, 208 + 15*12, 220, 2) = '1' then menu_char_on := '1'; end if; -- T
                    if is_char_pixel(pixel_x, pixel_y, 12, 208 + 16*12, 220, 2) = '1' then menu_char_on := '1'; end if; -- A
                    if is_char_pixel(pixel_x, pixel_y, 19, 208 + 17*12, 220, 2) = '1' then menu_char_on := '1'; end if; -- R
                    if is_char_pixel(pixel_x, pixel_y, 22, 208 + 18*12, 220, 2) = '1' then menu_char_on := '1'; end if; -- T
                end if;

                if menu_char_on = '1' then
                      red_out <= "11111111"; green_out <= "11111111"; blue_out <= "11111111"; -- Белые буквы
                end if;

                -- Рисуем 4 кнопки (KEY3, KEY2, KEY1, KEY0) на Y = 360, Радиус = 12 пикселей
                dist3 := (pixel_x - 230)*(pixel_x - 230) + (pixel_y - 360)*(pixel_y - 360);
                dist2 := (pixel_x - 290)*(pixel_x - 290) + (pixel_y - 360)*(pixel_y - 360);
                dist1 := (pixel_x - 350)*(pixel_x - 350) + (pixel_y - 360)*(pixel_y - 360);
                dist0 := (pixel_x - 410)*(pixel_x - 410) + (pixel_y - 360)*(pixel_y - 360);

                if dist3 <= 144 then -- KEY3 (левая, мигающая)
                    if blink_on = '1' then
                        red_out <= "00000000"; green_out <= "11111111"; blue_out <= "00000000"; -- Ярко-зеленый
                    else
                        red_out <= "00000000"; green_out <= "01000000"; blue_out <= "00000000"; -- Темно-зеленый
                    end if;
                elsif dist2 <= 144 or dist1 <= 144 or dist0 <= 144 then -- Другие кнопки
                    red_out <= "01000000"; green_out <= "01000000"; blue_out <= "01000000"; -- Серые
                end if;

            -- =====================================================================================
            -- 2. СЦЕНА СМЕРТИ (GAME_OVER) — Экран полностью анимирован
            -- =====================================================================================
            elsif state = GAME_OVER then
                menu_char_on := '0';
                
                -- СТРОКА 1: Плавное проявление красного "GAME OVER" (Масштаб = 4, Y = 100, Шаг = 24)

                if pixel_y >= 100 and pixel_y < 128 and pixel_x < gameover_timer then
                    if is_char_pixel(pixel_x, pixel_y, 25, 212 + 0*24, 100, 4) = '1' then menu_char_on := '1'; end if; -- G
                    if is_char_pixel(pixel_x, pixel_y, 12, 212 + 1*24, 100, 4) = '1' then menu_char_on := '1'; end if; -- A
                    if is_char_pixel(pixel_x, pixel_y, 26, 212 + 2*24, 100, 4) = '1' then menu_char_on := '1'; end if; -- M
                    if is_char_pixel(pixel_x, pixel_y, 14, 212 + 3*24, 100, 4) = '1' then menu_char_on := '1'; end if; -- E
                    -- Пробел
                    if is_char_pixel(pixel_x, pixel_y, 23, 212 + 5*24, 100, 4) = '1' then menu_char_on := '1'; end if; -- O
                    if is_char_pixel(pixel_x, pixel_y, 17, 212 + 6*24, 100, 4) = '1' then menu_char_on := '1'; end if; -- V
                    if is_char_pixel(pixel_x, pixel_y, 14, 212 + 7*24, 100, 4) = '1' then menu_char_on := '1'; end if; -- E
                    if is_char_pixel(pixel_x, pixel_y, 19, 212 + 8*24, 100, 4) = '1' then menu_char_on := '1'; end if; -- R
                end if;
                
                if menu_char_on = '1' then
                    red_out <= "11111111"; green_out <= "00000000"; blue_out <= "00000000"; -- Красный GAME OVER
                    menu_char_on := '0';
                end if;

                -- СТРОКА 2: Плавное проявление "SCORE: XXXXX" с задержкой (Масштаб = 2, Y = 190, Шаг = 12)
                -- Начинает проявляться, когда таймер анимации переходит за отметку 300
                if gameover_timer > 300 and pixel_y >= 190 and pixel_y < 204 and pixel_x < (gameover_timer - 100) then
                    if is_char_pixel(pixel_x, pixel_y, 10, 240 + 0*12, 190, 2) = '1' then menu_char_on := '1'; end if; -- S
                    if is_char_pixel(pixel_x, pixel_y, 13, 240 + 1*12, 190, 2) = '1' then menu_char_on := '1'; end if; -- C
                    if is_char_pixel(pixel_x, pixel_y, 23, 240 + 2*12, 190, 2) = '1' then menu_char_on := '1'; end if; -- O
                    if is_char_pixel(pixel_x, pixel_y, 19, 240 + 3*12, 190, 2) = '1' then menu_char_on := '1'; end if; -- R
                    if is_char_pixel(pixel_x, pixel_y, 14, 240 + 4*12, 190, 2) = '1' then menu_char_on := '1'; end if; -- E
                    -- Двоеточие ":"
                    if (pixel_x >= 301 and pixel_x <= 303 and pixel_y >= 192 and pixel_y <= 194) or
                       (pixel_x >= 301 and pixel_x <= 303 and pixel_y >= 198 and pixel_y <= 200) then
                        menu_char_on := '1';
                    end if;
                    -- Цифры счета за раунд
                    if is_char_pixel(pixel_x, pixel_y, (score/10000) mod 10, 310, 190, 2) = '1' then menu_char_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, (score/1000) mod 10,  322, 190, 2) = '1' then menu_char_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, (score/100) mod 10,   334, 190, 2) = '1' then menu_char_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, (score/10) mod 10,    346, 190, 2) = '1' then menu_char_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, score mod 10,         358, 190, 2) = '1' then menu_char_on := '1'; end if;
                end if;

                if menu_char_on = '1' then
                    red_out <= "11111111"; green_out <= "11111111"; blue_out <= "11111111"; -- Белый SCORE
                    menu_char_on := '0';
                end if;

                -- СТРОКА 3: Плавное проявление "PRESS KEY3 TO RESTART" с задержкой (Масштаб = 2, Y = 270, Шаг = 12)
                -- Начинает проявляться после прохождения отметки таймера 500
                if gameover_timer > 500 and pixel_y >= 270 and pixel_y < 284 and pixel_x < (gameover_timer - 300) then
                    -- PRESS
                    if is_char_pixel(pixel_x, pixel_y, 11, 194 + 0*12, 270, 2) = '1' then menu_char_on := '1'; end if; -- P
                    if is_char_pixel(pixel_x, pixel_y, 19, 194 + 1*12, 270, 2) = '1' then menu_char_on := '1'; end if; -- R
                    if is_char_pixel(pixel_x, pixel_y, 14, 194 + 2*12, 270, 2) = '1' then menu_char_on := '1'; end if; -- E
                    if is_char_pixel(pixel_x, pixel_y, 10, 194 + 3*12, 270, 2) = '1' then menu_char_on := '1'; end if; -- S
                    if is_char_pixel(pixel_x, pixel_y, 10, 194 + 4*12, 270, 2) = '1' then menu_char_on := '1'; end if; -- S
                    -- KEY3
                    if is_char_pixel(pixel_x, pixel_y, 20, 194 + 6*12, 270, 2) = '1' then menu_char_on := '1'; end if; -- K
                    if is_char_pixel(pixel_x, pixel_y, 14, 194 + 7*12, 270, 2) = '1' then menu_char_on := '1'; end if; -- E
                    if is_char_pixel(pixel_x, pixel_y, 21, 194 + 8*12, 270, 2) = '1' then menu_char_on := '1'; end if; -- Y
                    if is_char_pixel(pixel_x, pixel_y, 3,  194 + 9*12, 270, 2) = '1' then menu_char_on := '1'; end if; -- 3
                    -- TO
                    if is_char_pixel(pixel_x, pixel_y, 22, 194 + 11*12, 270, 2) = '1' then menu_char_on := '1'; end if; -- T
                    if is_char_pixel(pixel_x, pixel_y, 23, 194 + 12*12, 270, 2) = '1' then menu_char_on := '1'; end if; -- O
                    -- RESTART
                    if is_char_pixel(pixel_x, pixel_y, 19, 194 + 14*12, 270, 2) = '1' then menu_char_on := '1'; end if; -- R
                    if is_char_pixel(pixel_x, pixel_y, 14, 194 + 15*12, 270, 2) = '1' then menu_char_on := '1'; end if; -- E
                    if is_char_pixel(pixel_x, pixel_y, 10, 194 + 16*12, 270, 2) = '1' then menu_char_on := '1'; end if; -- S
                    if is_char_pixel(pixel_x, pixel_y, 22, 194 + 17*12, 270, 2) = '1' then menu_char_on := '1'; end if; -- T
                    if is_char_pixel(pixel_x, pixel_y, 12, 194 + 18*12, 270, 2) = '1' then menu_char_on := '1'; end if; -- A
                    if is_char_pixel(pixel_x, pixel_y, 19, 194 + 19*12, 270, 2) = '1' then menu_char_on := '1'; end if; -- R
                    if is_char_pixel(pixel_x, pixel_y, 22, 194 + 20*12, 270, 2) = '1' then menu_char_on := '1'; end if; -- T
                end if;

                if menu_char_on = '1' then
                    red_out <= "11111111"; green_out <= "11111111"; blue_out <= "11111111"; -- Белые буквы
                end if;

                -- СТРОКА 4: Появление 4 кнопок платы (Y = 360) в самом конце анимации
                if gameover_timer > 700 then
                    dist3 := (pixel_x - 230)*(pixel_x - 230) + (pixel_y - 360)*(pixel_y - 360);
                    dist2 := (pixel_x - 290)*(pixel_x - 290) + (pixel_y - 360)*(pixel_y - 360);
                    dist1 := (pixel_x - 350)*(pixel_x - 350) + (pixel_y - 360)*(pixel_y - 360);
                    dist0 := (pixel_x - 410)*(pixel_x - 410) + (pixel_y - 360)*(pixel_y - 360);

                    if dist3 <= 144 then -- KEY3 (Мигает зеленым)
                        if blink_on = '1' then
                            red_out <= "00000000"; green_out <= "11111111"; blue_out <= "00000000";
                        else
                            red_out <= "00000000"; green_out <= "01000000"; blue_out <= "00000000";
                        end if;
					elsif dist2 <= 144 or dist1 <= 144 or dist0 <= 144 then -- Остальные
                        red_out <= "01000000"; green_out <= "01000000"; blue_out <= "01000000"; -- Серые
                    end if;
                end if;

            -- =====================================================================================
            -- 3. ИГРОВОЙ ЭКРАН (PLAYING / PAUSE)
            -- =====================================================================================
            else
                -- Отрисовка игровых элементов
                if tank_on = '1' then
                    red_out <= "00000000"; green_out <= "11111111"; blue_out <= "00000000"; -- Зеленый танк
                elsif p_bullet_on = '1' then
                    red_out <= "11111111"; green_out <= "11111111"; blue_out <= "11111111"; -- Белая пуля
                elsif e_bullet_on = '1' then
                    red_out <= "11111111"; green_out <= "00000000"; blue_out <= "11111111"; -- Вражеская пуля
                elsif alien_on = '1' then
                    red_out <= "11111111"; green_out <= "11111111"; blue_out <= "11111111"; -- Белые пришельцы
                end if;

                -- HUD (Интерфейс в игре)
                hud_pixel_on := '0';
                
                -- Слово "SCORE:" в углу
                if pixel_y >= 10 and pixel_y < 17 then
                    if is_char_pixel(pixel_x, pixel_y, 10, 10, 10, 1) = '1' then hud_pixel_on := '1'; end if; -- S
                    if is_char_pixel(pixel_x, pixel_y, 13, 16, 10, 1) = '1' then hud_pixel_on := '1'; end if; -- C
                    if is_char_pixel(pixel_x, pixel_y, 23, 22, 10, 1) = '1' then hud_pixel_on := '1'; end if; -- O
                    if is_char_pixel(pixel_x, pixel_y, 19, 28, 10, 1) = '1' then hud_pixel_on := '1'; end if; -- R
                    if is_char_pixel(pixel_x, pixel_y, 14, 34, 10, 1) = '1' then hud_pixel_on := '1'; end if; -- E
                end if;
                
                -- Двоеточие ":"
                if (pixel_x >= 41 and pixel_x <= 42 and pixel_y >= 11 and pixel_y <= 12) or
                   (pixel_x >= 41 and pixel_x <= 42 and pixel_y >= 14 and pixel_y <= 15) then
                    hud_pixel_on := '1';
                end if;

                -- Отрисовка цифр очков (Исправлено отзеркаливание!)
                if is_char_pixel(pixel_x, pixel_y, (score/10000) mod 10, 46, 10, 1) = '1' then hud_pixel_on := '1'; end if;
                if is_char_pixel(pixel_x, pixel_y, (score/1000) mod 10,  52, 10, 1) = '1' then hud_pixel_on := '1'; end if;
                if is_char_pixel(pixel_x, pixel_y, (score/100) mod 10,   58, 10, 1) = '1' then hud_pixel_on := '1'; end if;
                if is_char_pixel(pixel_x, pixel_y, (score/10) mod 10,    64, 10, 1) = '1' then hud_pixel_on := '1'; end if;
                if is_char_pixel(pixel_x, pixel_y, score mod 10,         70, 10, 1) = '1' then hud_pixel_on := '1'; end if;

                if hud_pixel_on = '1' then
                    red_out <= "11111111"; green_out <= "11111111"; blue_out <= "00000000"; -- Желтый HUD
                    hud_pixel_on := '0';
                end if;

                -- Отрисовка слова "LIVES"
                if pixel_y >= 10 and pixel_y < 17 then
                    if is_char_pixel(pixel_x, pixel_y, 15, MAX_X - 70, 10, 1) = '1' then hud_pixel_on := '1'; end if; -- L (как I)
                    if is_char_pixel(pixel_x, pixel_y, 15, MAX_X - 64, 10, 1) = '1' then hud_pixel_on := '1'; end if; -- I
                    if is_char_pixel(pixel_x, pixel_y, 17, MAX_X - 58, 10, 1) = '1' then hud_pixel_on := '1'; end if; -- V
                    if is_char_pixel(pixel_x, pixel_y, 14, MAX_X - 52, 10, 1) = '1' then hud_pixel_on := '1'; end if; -- E
                    if is_char_pixel(pixel_x, pixel_y, 10, MAX_X - 46, 10, 1) = '1' then hud_pixel_on := '1'; end if; -- S
                end if;

                -- Количество оставшихся жизней
                if is_char_pixel(pixel_x, pixel_y, lives, MAX_X - 35, 10, 1) = '1' then hud_pixel_on := '1'; end if;

                if hud_pixel_on = '1' then
                    red_out <= "00000000"; green_out <= "11111111"; blue_out <= "00000000"; -- Зеленый LIVES
                end if;

                -- Оверлей паузы (если активен)
                if pause_on = '1' then
                    red_out <= "11111111"; green_out <= "11111111"; blue_out <= "00000000"; -- Желтая пауза
                end if;
            end if;
        end if;
    end process;

end behavior;
