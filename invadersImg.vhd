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
        
        pixel_x   : in integer range 0 to 1023;
        pixel_y   : in integer range 0 to 1023;
        
        red_out   : out std_logic_vector(9 downto 0);
        green_out : out std_logic_vector(9 downto 0);
        blue_out  : out std_logic_vector(9 downto 0)
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
    
    -- Скорость движения пришельцев и частота стрельбы
    type speed_array_type is array (0 to 10) of integer; -- 0 is dummy, 1-10 for waves
    constant ALIEN_MOVE_SPEED_FRAMES : speed_array_type := (
        0 => 40,  -- Dummy for wave 0 (menu)
        1 => 40,  -- Wave 1 (slowest)
        2 => 35,
		  3 => 30,
        4 => 25,
        5 => 20,
        6 => 18,
        7 => 16,
        8 => 14,
        9 => 12,
        10 => 10   -- Wave 10 (fastest)
    );
    constant ALIEN_SHOOT_SPEED_FRAMES : speed_array_type := (
        0 => 60, -- Dummy
        1 => 60, -- Wave 1
        2 => 55,
        3 => 50,
        4 => 45,
        5 => 40,
        6 => 35,
        7 => 30,
        8 => 25,
        9 => 20,
        10 => 15  -- Wave 10
    );

    signal alien_timer  : integer range 0 to 60 := 0; -- Таймер для движения пришельцев
    signal shoot_timer  : integer range 0 to 120 := 0; -- Таймер для стрельбы пришельцев

    -- LFSR для псевдорандома (выбор колонки для стрельбы)
    signal lfsr : std_logic_vector(7 downto 0) := "10101010";

    -- Сигналы объектов
    signal tank_on, p_bullet_on, e_bullet_on, alien_on : std_logic;
    signal menu_on, pause_on, gameover_on : std_logic;
    signal alien_invasion_gameover : std_logic := '0'; -- Флаг для типа Game Over

    -- Игровая статистика
    signal score          : integer range 0 to 99999 := 0;
    signal lives          : integer range 0 to 3 := 3; -- Максимум 3 жизни
    signal wave           : integer range 0 to 10 := 0; -- 0: меню, 1-10: раунды
    signal aliens_killed_count : integer range 0 to MAX_ALIENS_PER_WAVE := 0;

    ------------------------------------------------------------------------------------------------
    -- Функция для отрисовки одной цифры (5x7 пиксельный шрифт)
    ------------------------------------------------------------------------------------------------
    function is_digit_pixel (
        px, py : integer;            -- Текущие координаты пикселя
        digit_val : integer;         -- Значение цифры (0-9)
        digit_start_x, digit_start_y : integer -- Верхний левый угол цифры
    ) return std_logic is
        constant DIGIT_WIDTH  : integer := 5;
        constant DIGIT_HEIGHT : integer := 7;
        variable local_x, local_y : integer;
        -- Массив паттернов для цифр (5x7 пикселей = 35 бит на цифру)
        -- Биты идут слева направо, сверху вниз. MSB - верхний левый пиксель.
		          type digit_pattern_array is array (0 to 9) of std_logic_vector(DIGIT_WIDTH*DIGIT_HEIGHT-1 downto 0);
        constant FONT_5X7 : digit_pattern_array := (
            -- 0: .###.
            --    #   #
            --    #   #
            --    #   #
            --    #   #
            --    #   #
            --    .###.
            0 => "01110" & "10001" & "10001" & "10001" & "10001" & "10001" & "01110",
            -- 1: ..#..
            --    .##..
            --    ..#..
            --    ..#..
            --    ..#..
            --    ..#..
            --    .###.
            1 => "00100" & "01100" & "00100" & "00100" & "00100" & "00100" & "01110",
            -- 2: .###.
            --    #   #
            --    .   #
            --    . ##.
            --    #   .
            --    #   .
            --    #####
            2 => "01110" & "10001" & "00001" & "00110" & "01000" & "10000" & "11111",
            -- 3: #####
            --    .   #
            --    .###.
            --    .   #
            --    .   #
            --    #   #
            --    .###.
            3 => "11111" & "00001" & "01110" & "00001" & "00001" & "10001" & "01110",
            -- 4: #   #
            --    #   #
            --    #   #
            --    #####
            --    .   #
            --    .   #
            --    .   #
            4 => "10001" & "10001" & "10001" & "11111" & "00001" & "00001" & "00001",
            -- 5: #####
            --    #   .
            --    #   .
            --    #####
            --    .   #
            --    .   #
            --    .###.
            5 => "11111" & "10000" & "10000" & "11111" & "00001" & "00001" & "01110",
            -- 6: .###.
            --    #   .
            --    #   .
            --    #####
            --    #   #
            --    #   #
            --    .###.
            6 => "01110" & "10000" & "10000" & "11111" & "10001" & "10001" & "01110",
            -- 7: #####
            --    .   #
            --    .   #
            --    .   #
            --    .   #
            --    .   #
            --    .   #
            7 => "11111" & "00001" & "00001" & "00001" & "00001" & "00001" & "00001",
            -- 8: .###.
            --    #   #
            --    #   #
            --    .###.
            --    #   #
            --    #   #
            --    .###.
            8 => "01110" & "10001" & "10001" & "01110" & "10001" & "10001" & "01110",
            -- 9: .###.
            --    #   #
            --    #   #
            --    .###.
            --    .   #
            --    .   #
            --    .###.
            9 => "01110" & "10001" & "10001" & "01110" & "00001" & "00001" & "01110"
        );
    begin
        local_x := px - digit_start_x;
        local_y := py - digit_start_y;

        if local_x >= 0 and local_x < DIGIT_WIDTH and
           local_y >= 0 and local_y < DIGIT_HEIGHT then
            return FONT_5X7(digit_val)( (local_y * DIGIT_WIDTH) + local_x );
        else
            return '0';
        end if;
    end function;

begin
    -- Генератор псевдослучайных чисел (LFSR)
    process(clock_25)
    begin
        if rising_edge(clock_25) then
            lfsr <= lfsr(6 downto 0) & (lfsr(7) xnor lfsr(5) xnor lfsr(4) xnor lfsr(3));
        end if;
    end process;

    ------------------------------------------------------------------------------------------------
    -- ЛОГИКА ИГРЫ (Обновляется раз в кадр - 60 Гц)
    ------------------------------------------------------------------------------------------------
    process(refresh, btn_reset)
        variable shoot_col : integer range 0 to COLS-1;
        variable found_alien : boolean;
        variable all_aliens_dead : boolean;
        variable temp_aliens_alive : alien_array; -- Временная копия для определения "все мертвы"
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
            wave <= 0; -- 0 означает "меню"
            aliens_killed_count <= 0;
            alien_timer <= 0;
            shoot_timer <= 0;
            aliens_dir <= '1';
            alien_invasion_gameover <= '0';
        elsif rising_edge(refresh) then
            if pause = '0' then -- Игра не на паузе
                case state is
                    when MENU =>
                        if btn_start = '1' then
                            state <= PLAYING;
                            -- Инициализация для новой игры (первой волны)
                            score <= 0;
                            lives <= 3;
                            wave <= 1; -- Начинаем с первой волны
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
                        -- 1. Проверка на инопланетное вторжение (Game Over)
                        found_alien := false;
                        for r in 0 to ROWS-1 loop
                            for c in 0 to COLS-1 loop
                                if aliens_alive(r,c) = '1' then
                                    -- Если хоть один живой пришелец достиг линии корабля
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
                                bullet_x <= tank_x + 15; -- Центр пушки
                                bullet_y <= TANK_Y - 5;
                            end if;
                        else
                            bullet_y <= bullet_y - 7;
                            if bullet_y < 10 then bullet_active <= '0'; end if; -- Пуля ушла за экран
                        end if;

                        -- 4. Движение пришельцев
                        alien_timer <= alien_timer + 1;
                        if alien_timer = ALIEN_MOVE_SPEED_FRAMES(wave) then -- Скорость зависит от волны
                            alien_timer <= 0;
                            if aliens_dir = '1' then -- Движение вправо
                                if aliens_x_off < (MAX_X - (COLS * (ALIEN_W + ALIEN_GAP)) - 50) then -- Ограничение справа
                                    aliens_x_off <= aliens_x_off + 8;
                                else -- Достигли края, меняем направление и опускаемся
                                    aliens_dir <= '0';
                                    aliens_y_off <= aliens_y_off + 15;
                                end if;
                            else -- Движение влево
                                if aliens_x_off > 30 then -- Ограничение слева
                                    aliens_x_off <= aliens_x_off - 8;
                                else -- Достигли края, меняем направление и опускаемся
                                    aliens_dir <= '1';
                                    aliens_y_off <= aliens_y_off + 15;
                                end if;
                            end if;
                        end if;

                        -- 5. Стрельба пришельцев
                        if e_bullet_active = '0' then
                            shoot_timer <= shoot_timer + 1;
									 if shoot_timer >= ALIEN_SHOOT_SPEED_FRAMES(wave) then -- Скорость стрельбы зависит от волны
                                shoot_timer <= 0;
                                shoot_col := to_integer(unsigned(lfsr(2 downto 0))) mod COLS; -- Случайная колонка
                                found_alien := false;
                                -- Ищем самого нижнего живого пришельца в этой колонке
                                for r_idx in ROWS-1 downto 0 loop
                                    if aliens_alive(r_idx, shoot_col) = '1' then
                                        e_bullet_active <= '1';
                                        e_bullet_x <= aliens_x_off + shoot_col*(ALIEN_W+ALIEN_GAP) + ALIEN_W/2;
                                        e_bullet_y <= aliens_y_off + r_idx*(ALIEN_H+ALIEN_GAP) + ALIEN_H;
                                        found_alien := true;
                                        exit; -- Пришелец найден, выходим из цикла
                                    end if;
                                end loop;
                            end if;
                        else
                            e_bullet_y <= e_bullet_y + 5;
                            if e_bullet_y > MAX_Y then e_bullet_active <= '0'; end if; -- Пуля ушла за экран
                        end if;

                        -- 6. Столкновение: Пуля игрока -> Пришелец
                        all_aliens_dead := true;
                        temp_aliens_alive := aliens_alive; -- Используем копию, чтобы не менять сигнал прямо в цикле проверки
                        for r in 0 to ROWS-1 loop
                            for c in 0 to COLS-1 loop
                                if aliens_alive(r,c) = '1' then
                                    all_aliens_dead := false; -- Есть хотя бы один живой пришелец
                                    if bullet_active = '1' then
                                        if bullet_x >= (aliens_x_off + c*(ALIEN_W+ALIEN_GAP)) and
                                           bullet_x <= (aliens_x_off + c*(ALIEN_W+ALIEN_GAP) + ALIEN_W) and
                                           bullet_y >= (aliens_y_off + r*(ALIEN_H+ALIEN_GAP)) and
                                           bullet_y <= (aliens_y_off + r*(ALIEN_H+ALIEN_GAP) + ALIEN_H) then
                                               temp_aliens_alive(r,c) := '0'; -- Убиваем пришельца
                                               bullet_active <= '0';          -- Пуля исчезает
                                               score <= score + 10;           -- Добавляем очки
                                               aliens_killed_count <= aliens_killed_count + 1;
                                        end if;
                                    end if;
                                end if;
                            end loop;
                        end loop;
                        aliens_alive <= temp_aliens_alive; -- Обновляем состояние пришельцев

                        -- Проверка завершения волны (все пришельцы убиты)
                        if aliens_killed_count = MAX_ALIENS_PER_WAVE then
                            if wave < 10 then -- Если есть следующая волна
                                wave <= wave + 1;
                                if lives < 3 then lives <= lives + 1; end if; -- Добавляем жизнь, не больше 3
                                -- Сброс для новой волны
                                aliens_killed_count <= 0;
                                aliens_alive <= (others => (others => '1'));
                                aliens_x_off <= 50;
                                aliens_y_off <= 40;
                                alien_timer <= 0;
                                shoot_timer <= 0;
                                bullet_active <= '0';
                                e_bullet_active <= '0';
                            else -- Все 10 волн завершены (победа!)
                                -- Можно добавить состояние WIN или просто продолжать играть на максимальной скорости
                                -- Сейчас просто сбросим пришельцев, останемся на 10 волне
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
                        
                        -- 7. Столкновение: Пуля врага -> Корабль игрока
                        if e_bullet_active = '1' and
                           e_bullet_x >= tank_x and e_bullet_x <= tank_x + TANK_W and
                           e_bullet_y >= TANK_Y and e_bullet_y <= TANK_Y + TANK_H then
                            lives <= lives - 1;           -- Уменьшаем жизнь
                            e_bullet_active <= '0';       -- Пуля исчезает
                            if lives = 0 then
                                state <= GAME_OVER;       -- Game Over
                            else
                                -- Корабль временно неуязвим, или мигает, для простоты не делаем сейчас
                            end if;
                        end if;

                    when GAME_OVER =>
                        if btn_start = '1' then state <= MENU; end if;
                end case;
            end if; -- Конец проверки паузы
        end if; -- Конец обновления по кадру
    end process;

    ------------------------------------------------------------------------------------------------
    -- ГРАФИКА (Формирование изображения для каждого пикселя)
    ------------------------------------------------------------------------------------------------
    
    -- 1. Корабль игрока (пушка + основание)
    tank_on <= '1' when (pixel_x >= tank_x and pixel_x <= tank_x + TANK_W and pixel_y >= TANK_Y+5 and pixel_y <= TANK_Y+TANK_H) or
                        (pixel_x >= tank_x+12 and pixel_x <= tank_x+18 and pixel_y >= TANK_Y and pixel_y <= TANK_Y+5)
                   else '0';

    -- 2. Пули
    p_bullet_on <= '1' when bullet_active = '1' and pixel_x >= bullet_x-1 and pixel_x <= bullet_x+1 and pixel_y >= bullet_y and pixel_y <= bullet_y+6 else '0';
    e_bullet_on <= '1' when e_bullet_active = '1' and pixel_x >= e_bullet_x-1 and pixel_x <= e_bullet_x+1 and pixel_y >= e_bullet_y and pixel_y <= e_bullet_y+8 else '0';

    -- 3. Пришельцы
    process(pixel_x, pixel_y, aliens_x_off, aliens_y_off, aliens_alive)
        variable rx, ry : integer;
    begin
        alien_on <= '0';
        for r in 0 to ROWS-1 loop
            for c in 0 to COLS-1 loop
                rx := pixel_x - (aliens_x_off + c*(ALIEN_W+ALIEN_GAP));
                ry := pixel_y - (aliens_y_off + r*(ALIEN_H+ALIEN_GAP));
                if rx >= 0 and rx < ALIEN_W and ry >= 0 and ry < ALIEN_H and aliens_alive(r,c) = '1' then
                    -- Рисуем "рожки" пришельца для красоты, вырезая углы
                    if not ( (ry < 4 and (rx < 4 or rx > ALIEN_W-5)) or (ry > ALIEN_H-5 and (rx < 4 or rx > ALIEN_W-5)) ) then
                        alien_on <= '1';
                    end if;
						  end if;
            end loop;
        end loop;
    end process;

    -- 4. Элементы интерфейса (Меню, Пауза, Game Over)
    -- Пауза: две вертикальные полоски в центре
    pause_on <= '1' when pause = '1' and ((pixel_x >= 310 and pixel_x <= 315) or (pixel_x >= 325 and pixel_x <= 330)) 
                    and (pixel_y >= 220 and pixel_y <= 260) else '0';
    
    -- Меню: "SPACE INVADERS" (прямоугольник) и "PRESS START" (прямоугольник)
    menu_on <= '1' when state = MENU and 
                    ((pixel_x >= 200 and pixel_x <= 440 and pixel_y >= 150 and pixel_y <= 200) or -- Title box
                     (pixel_x >= 240 and pixel_x <= 400 and pixel_y >= 250 and pixel_y <= 270)) -- Press Start box
                   else '0';
    
    -- Game Over: Крест или сообщение об вторжении
    gameover_on <= '1' when state = GAME_OVER and (
                        (
                            -- Левая часть (Крест) полностью в скобках
                            ((abs((pixel_x-320) - (pixel_y-240)) < 5 or abs((pixel_x-320) + (pixel_y-240)) < 5) and
                             pixel_x > 280 and pixel_x < 360 and pixel_y > 200 and pixel_y < 280)
                        ) 
                        or 
                        (
                            -- Правая часть (Сообщение) полностью в скобках
                            (alien_invasion_gameover = '1' and pixel_x >= 180 and pixel_x <= 460 and pixel_y >= 100 and pixel_y <= 130)
                        )
                    ) else '0';

    ------------------------------------------------------------------------------------------------
    -- ЦВЕТОВАЯ СХЕМА (Определение цвета текущего пикселя)
    ------------------------------------------------------------------------------------------------
    process(video_on, tank_on, p_bullet_on, e_bullet_on, alien_on, pause_on, menu_on, gameover_on,
            pixel_x, pixel_y, score, lives, wave, alien_invasion_gameover, state)
        -- Локальные переменные для отрисовки HUD (счета и жизней)
        variable hud_pixel_on : std_logic;
    begin
        -- Если видео выключено, все пиксели черные
        if video_on = '0' then
            red_out <= (others => '0'); green_out <= (others => '0'); blue_out <= (others => '0');
        else
            -- По умолчанию: темно-синий фон
            red_out <= "0000000000"; green_out <= "0000000000"; blue_out <= "0000000000";

            -- Объекты игры (перекрывают фон)
            if tank_on = '1' then
                red_out <= "0000000000"; green_out <= "1111111111"; blue_out <= "0000000000"; -- Зеленый корабль игрока
            elsif p_bullet_on = '1' then
                red_out <= "1111111111"; green_out <= "1111111111"; blue_out <= "1111111111"; -- Белая пуля игрока
            elsif e_bullet_on = '1' then
                red_out <= "1111111111"; green_out <= "0000000000"; blue_out <= "1111111111"; -- Пурпурная пуля врага
            elsif alien_on = '1' then
                red_out <= "1111111111"; green_out <= "1111111111"; blue_out <= "1111111111"; -- Белые пришельцы
            end if;

            -- HUD (Score и Lives) - перекрывают игровые объекты
            hud_pixel_on := '0';
            
            -- SCORE (левый верхний угол)
            -- Отрисовка символа 'S' для "SCORE" (примитивные блоки)
            if (pixel_x >= 10 and pixel_x <= 15 and pixel_y >= 10 and pixel_y <= 12) or -- Top bar
               (pixel_x >= 10 and pixel_x <= 12 and pixel_y >= 12 and pixel_y <= 16) or -- Top left vertical
               (pixel_x >= 10 and pixel_x <= 15 and pixel_y >= 16 and pixel_y <= 18) or -- Middle bar
               (pixel_x >= 13 and pixel_x <= 15 and pixel_y >= 18 and pixel_y <= 22) or -- Bottom right vertical
               (pixel_x >= 10 and pixel_x <= 15 and pixel_y >= 22 and pixel_y <= 24) -- Bottom bar
            then
                hud_pixel_on := '1';
            end if;
            -- Отрисовка двоеточия ':'
            if (pixel_x >= 18 and pixel_x <= 20 and pixel_y >= 16 and pixel_y <= 18) or -- dot 1
               (pixel_x >= 18 and pixel_x <= 20 and pixel_y >= 20 and pixel_y <= 22)    -- dot 2
            then
                hud_pixel_on := '1';
            end if;

            -- Отрисовка цифр счета (Score) - 4 цифры, макс. 99990
            -- Сотни тысяч
            if is_digit_pixel(pixel_x, pixel_y, (score/10000) mod 10, 25, 10) = '1' then hud_pixel_on := '1'; end if;
            -- Тысячи
            if is_digit_pixel(pixel_x, pixel_y, (score/1000) mod 10, 25 + 5 + 1, 10) = '1' then hud_pixel_on := '1'; end if;
            -- Сотни
            if is_digit_pixel(pixel_x, pixel_y, (score/100) mod 10, 25 + 2*(5 + 1), 10) = '1' then hud_pixel_on := '1'; end if;
            -- Десятки
            if is_digit_pixel(pixel_x, pixel_y, (score/10) mod 10, 25 + 3*(5 + 1), 10) = '1' then hud_pixel_on := '1'; end if;
            -- Единицы
            if is_digit_pixel(pixel_x, pixel_y, score mod 10, 25 + 4*(5 + 1), 10) = '1' then hud_pixel_on := '1'; end if;

            -- Если пиксель для Score активен, красим в желтый
            if hud_pixel_on = '1' then
                red_out <= "1111111111"; green_out <= "1111111111"; blue_out <= "0000000000"; -- Желтый
                hud_pixel_on := '0'; -- Сброс для следующих элементов HUD
            end if;

            -- LIVES (правый верхний угол)
            -- Отрисовка символа 'L' для "LIVES" (примитивные блоки)
            if (pixel_x >= (MAX_X - 70) and pixel_x <= (MAX_X - 65) and pixel_y >= 10 and pixel_y <= 24) or -- Vertical bar
               (pixel_x >= (MAX_X - 70) and pixel_x <= (MAX_X - 65) and pixel_y >= 22 and pixel_y <= 24) -- Bottom bar
            then
                hud_pixel_on := '1';
            end if;
            -- Отрисовка двоеточия ':'
            if (pixel_x >= (MAX_X - 62) and pixel_x <= (MAX_X - 60) and pixel_y >= 16 and pixel_y <= 18) or
               (pixel_x >= (MAX_X - 62) and pixel_x <= (MAX_X - 60) and pixel_y >= 20 and pixel_y <= 22)
            then
                hud_pixel_on := '1';
            end if;
            
            -- Отрисовка цифры жизней
            if is_digit_pixel(pixel_x, pixel_y, lives, MAX_X - 55, 10) = '1' then hud_pixel_on := '1'; end if;
            
            -- Если пиксель для Lives активен, красим в зеленый
            if hud_pixel_on = '1' then
                red_out <= "0000000000"; green_out <= "1111111111"; blue_out <= "0000000000"; -- Зеленый
            end if;
            
            -- Элементы интерфейса (самый высокий приоритет, перекрывают всё)
            if pause_on = '1' then
                red_out <= "1111111111"; green_out <= "1111111111"; blue_out <= "0000000000"; -- Желтая пауза
            elsif menu_on = '1' then
                red_out <= "0000000000"; green_out <= "1111111111"; blue_out <= "1111111111"; -- Голубое меню
            elsif gameover_on = '1' then
                if alien_invasion_gameover = '1' then
                    red_out <= "1111111111"; green_out <= "0000000000"; blue_out <= "0000000000"; -- Красное "ALIEN INVASION!"
                else
                    red_out <= "1111111111"; green_out <= "0000000000"; blue_out <= "0000000000"; -- Красное "GAME OVER"
                end if;
            end if;
        end if;
    end process;

end behavior;