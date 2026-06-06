library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity invadersImg is
   port(
        clock_pix : in std_logic;
        refresh : in std_logic;
        video_on : in std_logic;
		 
		  btn_left : in std_logic;
        btn_right : in std_logic;
        btn_fire : in std_logic;
        btn_start : in std_logic;
        btn_reset : in std_logic;
        pause : in std_logic;
        
        resolution : in std_logic_vector(1 downto 0);  -- "00":640x480, "01":1024x768, "10":1360x768
        wave_speed : in integer range 0 to 10 := 0;
        
        pixel_x : in integer range 0 to 2047;
        pixel_y : in integer range 0 to 1023;
        
        red_out : out std_logic_vector(7 downto 0);
        green_out : out std_logic_vector(7 downto 0);
        blue_out : out std_logic_vector(7 downto 0)
   );
end invadersImg;

architecture behavior of invadersImg is
    type state_type is (MENU, PLAYING, GAME_OVER);
    signal state : state_type := MENU;

    -- Параметры экрана
    signal MAX_X : integer := 640;
    signal MAX_Y : integer := 480;
    signal TANK_Y : integer := 440;
    signal ALIENS_START_X : integer := 50;
    signal ALIENS_START_Y : integer := 40;
    signal HUD_Y_POS : integer := 10;
    signal MENU_TITLE_Y : integer := 120;
    signal MENU_TEXT_Y : integer := 220;
    signal GAME_OVER_Y : integer := 100;
    signal SCORE_Y : integer := 190;
    signal RESTART_Y : integer := 270;
    signal BUTTONS_Y : integer := 360;
	 signal center_x : integer := 320;

    -- Корабль игрока (Tank)
    constant TANK_W : integer := 30;
    constant TANK_H : integer := 16;
    signal tank_x : integer := 305;
    
    -- Пуля игрока
    signal bullet_x : integer := 0;
    signal bullet_y : integer := 0;
    signal bullet_active : std_logic := '0';
    
    -- Пуля пришельцев
    signal e_bullet_x : integer := 0;
    signal e_bullet_y : integer := 0;
    signal e_bullet_active : std_logic := '0';
    
    -- Пришельцы
    constant ALIEN_W : integer := 24;
    constant ALIEN_H : integer := 16;
    constant ALIEN_GAP : integer := 16;
    constant ROWS : integer := 4;
    constant COLS : integer := 8;
    constant MAX_ALIENS_PER_WAVE : integer := ROWS * COLS;
    
    type alien_array is array (0 to ROWS-1, 0 to COLS-1) of std_logic;
    signal aliens_alive : alien_array := (others => (others => '1'));
    
    signal aliens_x_off : integer := 50;
    signal aliens_y_off : integer := 40;
    signal aliens_dir : std_logic := '1';
    signal aliens_move_counter : integer := 0;
    
    -- Скорости
    type speed_array_type is array (0 to 10) of integer;
    constant ALIEN_MOVE_SPEED_FRAMES : speed_array_type := (
        0 => 40, 1 => 40, 2 => 35, 3 => 30, 4 => 25, 5 => 20, 6 => 18, 7 => 16, 8 => 14, 9 => 12, 10 => 10
    );
    constant ALIEN_SHOOT_SPEED_FRAMES : speed_array_type := (
        0 => 60, 1 => 60, 2 => 55, 3 => 50, 4 => 45, 5 => 40, 6 => 35, 7 => 30, 8 => 25, 9 => 20, 10 => 15
    );

    signal alien_timer : integer range 0 to 60 := 0;
    signal shoot_timer : integer range 0 to 120 := 0;
    signal lfsr : std_logic_vector(7 downto 0) := "10101010";

    -- Сигналы отрисовки объектов
    signal tank_on, p_bullet_on, e_bullet_on, alien_on : std_logic;
    signal pause_on : std_logic;
    signal alien_invasion_gameover : std_logic := '0';

    signal score : integer range 0 to 99999 := 0;
    signal lives : integer range 0 to 3 := 3;
    signal wave : integer range 0 to 10 := 0;
    signal aliens_killed_count : integer range 0 to MAX_ALIENS_PER_WAVE := 0;

    -- Сигналы анимаций
    signal blink_reg : unsigned(5 downto 0) := (others => '0');
    signal blink_on : std_logic := '0';
    signal gameover_timer : integer range 0 to 1023 := 0;
    
    -- Сигналы для UART команды wave_speed
    signal pending_wave_speed : integer range 0 to 10 := 0;
    signal wave_speed_processed : std_logic := '0';
	 signal wave_speed_timer : integer range 0 to 50_000_000 := 0; 

    -- Шрифт 5x7
    function is_char_pixel (
        px, py : integer;
        char_val : integer;
        start_x, start_y : integer;
        scale : integer
    ) return std_logic is
        constant CHAR_WIDTH : integer := 5;
        constant CHAR_HEIGHT : integer := 7;
        variable local_x, local_y : integer;
        
        type char_pattern_array is array (0 to 26) of std_logic_vector(34 downto 0);
        constant FONT_5X7 : char_pattern_array := (
            0  => "01110" & "10001" & "10001" & "10001" & "10001" & "10001" & "01110",
            1  => "00100" & "01100" & "00100" & "00100" & "00100" & "00100" & "01110",
            2  => "01110" & "10001" & "00001" & "00110" & "01000" & "10000" & "11111",
            3  => "11111" & "00001" & "01110" & "00001" & "00001" & "10001" & "01110",
            4  => "10001" & "10001" & "10001" & "11111" & "00001" & "00001" & "00001",
            5  => "11111" & "10000" & "10000" & "11111" & "00001" & "00001" & "01110",
            6  => "01110" & "10000" & "10000" & "11111" & "10001" & "10001" & "01110",
            7  => "11111" & "00001" & "00001" & "00001" & "00001" & "00001" & "00001",
            8  => "01110" & "10001" & "10001" & "01110" & "10001" & "10001" & "01110",
            9  => "01110" & "10001" & "10001" & "01110" & "00001" & "00001" & "01110",
            10 => "01110" & "10000" & "10000" & "01110" & "00001" & "00001" & "01110",
            11 => "11110" & "10001" & "10001" & "11110" & "10000" & "10000" & "10000",
            12 => "01110" & "10001" & "10001" & "11111" & "10001" & "10001" & "10001",
            13 => "01110" & "10001" & "10000" & "10000" & "10000" & "10001" & "01110",
            14 => "11111" & "10000" & "10000" & "11110" & "10000" & "10000" & "11111",
            15 => "01110" & "00100" & "00100" & "00100" & "00100" & "00100" & "01110",
            16 => "10001" & "11001" & "10101" & "10101" & "10011" & "10011" & "10001",
            17 => "10001" & "10001" & "10001" & "10001" & "10001" & "01010" & "00100",
            18 => "11110" & "10001" & "10001" & "10001" & "10001" & "10001" & "11110",
            19 => "11110" & "10001" & "10001" & "11110" & "10100" & "10010" & "10001",
            20 => "10001" & "10010" & "10100" & "11000" & "10100" & "10010" & "10001",
            21 => "10001" & "10001" & "01010" & "00100" & "00100" & "00100" & "00100",
            22 => "11111" & "00100" & "00100" & "00100" & "00100" & "00100" & "00100",
            23 => "01110" & "10001" & "10001" & "10001" & "10001" & "10001" & "01110",
            24 => (others => '0'),
            25 => "01110" & "10001" & "10000" & "10111" & "10001" & "10001" & "01110",
            26 => "10001" & "11011" & "10101" & "10001" & "10001" & "10001" & "10001"
        );
    begin
        local_x := (px - start_x) / scale;
        local_y := (py - start_y) / scale;

        if local_x >= 0 and local_x < CHAR_WIDTH and
           local_y >= 0 and local_y < CHAR_HEIGHT then
            return FONT_5X7(char_val)(34 - ((local_y * CHAR_WIDTH) + local_x));
        else
            return '0';
        end if;
    end function;

begin
    -- Адаптация параметров под разрешение
    process(resolution)
    begin
        case resolution is
            when "00" =>   -- 640x480
                MAX_X <= 640;
                MAX_Y <= 480;
					 center_x <= 320;
                TANK_Y <= 440;
                ALIENS_START_X <= 50;
                ALIENS_START_Y <= 40;
                HUD_Y_POS <= 10;
                MENU_TITLE_Y <= 120;
                MENU_TEXT_Y <= 220;
                GAME_OVER_Y <= 100;
                SCORE_Y <= 190;
                RESTART_Y <= 270;
                BUTTONS_Y <= 360;
            when "01" =>   -- 1024x768
                MAX_X <= 1024;
                MAX_Y <= 768;
					 center_x <= 512;
                TANK_Y <= 700;
                ALIENS_START_X <= 100;
                ALIENS_START_Y <= 80;
                HUD_Y_POS <= 20;
                MENU_TITLE_Y <= 200;
                MENU_TEXT_Y <= 350;
                GAME_OVER_Y <= 180;
                SCORE_Y <= 300;
                RESTART_Y <= 430;
                BUTTONS_Y <= 550;
            when "10" =>   -- 1360x768
                MAX_X <= 1360;
                MAX_Y <= 768;
					 center_x <= 680;
                TANK_Y <= 700;
                ALIENS_START_X <= 160;
                ALIENS_START_Y <= 80;
                HUD_Y_POS <= 20;
                MENU_TITLE_Y <= 200;
                MENU_TEXT_Y <= 350;
                GAME_OVER_Y <= 180;
                SCORE_Y <= 300;
                RESTART_Y <= 430;
                BUTTONS_Y <= 550;
            when others =>
                MAX_X <= 640;
                MAX_Y <= 480;
					 center_x <= 320;
                TANK_Y <= 440;
                ALIENS_START_X <= 50;
                ALIENS_START_Y <= 40;
        end case;
    end process;

    -- LFSR генератор
    process(clock_pix)
    begin
        if rising_edge(clock_pix) then
            lfsr <= lfsr(6 downto 0) & (lfsr(7) xnor lfsr(5) xnor lfsr(4) xnor lfsr(3));
        end if;
    end process;

    -- ЛОГИКА ИГРЫ
    process(refresh, btn_reset)
    variable shoot_col : integer range 0 to COLS-1;
    variable found_alien : boolean;
    variable all_aliens_dead : boolean;
    variable temp_aliens_alive : alien_array;
    variable leftmost_alien : integer;
    variable rightmost_alien : integer;
    variable can_move_left : boolean;
    variable can_move_right : boolean;
begin
    if btn_reset = '1' then
        state <= MENU;
        tank_x <= (MAX_X - TANK_W) / 2;
        bullet_active <= '0';
        e_bullet_active <= '0';
        aliens_alive <= (others => (others => '1'));
        aliens_x_off <= ALIENS_START_X;
        aliens_y_off <= ALIENS_START_Y;
        score <= 0;
        lives <= 3;
        wave <= 1;
        aliens_killed_count <= 0;
        alien_timer <= 0;
        shoot_timer <= 0;
        aliens_dir <= '1';
        alien_invasion_gameover <= '0';
        blink_reg <= (others => '0');
        blink_on <= '0';
        gameover_timer <= 0;
        wave_speed_processed <= '0';
        pending_wave_speed <= 0;
    elsif rising_edge(refresh) then
        if wave_speed /= 0 and wave_speed_processed = '0' then
            if wave_speed >= 1 and wave_speed <= 10 then
                wave <= wave_speed;
                -- Сбрасываем таймеры, чтобы движение и стрельба обновились сразу
                alien_timer <= 0;
                shoot_timer <= 0;
            end if;
            wave_speed_processed <= '1';
            pending_wave_speed <= wave_speed;
				wave_speed_timer <= 25_000_000; 
        end if;
        
        -- Таймер сброса флага (через полсекунды после получения команды)
        if wave_speed_timer > 0 then
            wave_speed_timer <= wave_speed_timer - 1;
            if wave_speed_timer = 1 then
                wave_speed_processed <= '0';
                wave_speed_timer <= 0;
            end if;
        end if;
        
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
                    gameover_timer <= 0;
                    if btn_start = '1' then
                        state <= PLAYING;
                        score <= 0;
                        lives <= 3;
                        -- Устанавливаем уровень из UART команды при старте
                        if pending_wave_speed >= 1 and pending_wave_speed <= 10 then
                            wave <= pending_wave_speed;
                        else
                            wave <= 1;
                        end if;
                        aliens_killed_count <= 0;
                        aliens_alive <= (others => (others => '1'));
                        aliens_x_off <= ALIENS_START_X;
                        aliens_y_off <= ALIENS_START_Y;
                        bullet_active <= '0';
                        e_bullet_active <= '0';
                        alien_timer <= 0;
                        shoot_timer <= 0;
                        aliens_dir <= '1';
                        alien_invasion_gameover <= '0';
                    end if;
                    
                when PLAYING =>
                    gameover_timer <= 0;
                    
                    -- Ограничиваем wave
                    if wave < 1 then wave <= 1; end if;
                    if wave > 10 then wave <= 10; end if;
                    
                    -- Проверка Game Over по вторжению
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

                    -- Движение корабля игрока
                    if btn_left = '1' and tank_x > 10 then
                        tank_x <= tank_x - 3;
                    elsif btn_right = '1' and tank_x < (MAX_X - TANK_W - 10) then
                        tank_x <= tank_x + 3;
                    end if;

                    -- Пуля игрока
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

                    -- Движение пришельцев
                    alien_timer <= alien_timer + 1;
                    if alien_timer >= ALIEN_MOVE_SPEED_FRAMES(wave) then
                        alien_timer <= 0;
                        
                        -- Находим крайних живых пришельцев
                        leftmost_alien := COLS-1;
                        rightmost_alien := 0;
                        for r in 0 to ROWS-1 loop
                            for c in 0 to COLS-1 loop
                                if aliens_alive(r,c) = '1' then
                                    if c < leftmost_alien then leftmost_alien := c; end if;
                                    if c > rightmost_alien then rightmost_alien := c; end if;
                                end if;
                            end loop;
                        end loop;
                        
                        -- Определяем, можно ли двигаться влево/вправо
                        can_move_left := (aliens_x_off + leftmost_alien*(ALIEN_W+ALIEN_GAP) > 20);
                        can_move_right := (aliens_x_off + rightmost_alien*(ALIEN_W+ALIEN_GAP) + ALIEN_W < MAX_X - 20);
                        
                        if aliens_dir = '1' then
                            if can_move_right then
                                aliens_x_off <= aliens_x_off + 8;
                            else
                                aliens_dir <= '0';
                                aliens_y_off <= aliens_y_off + 15;
                            end if;
                        else
                            if can_move_left then
                                aliens_x_off <= aliens_x_off - 8;
                            else
                                aliens_dir <= '1';
                                aliens_y_off <= aliens_y_off + 15;
                            end if;
                        end if;
                    end if;

                    -- Стрельба пришельцев
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

                    -- Коллизия: Пуля игрока -> Пришелец
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
                        end if;
                        aliens_killed_count <= 0;
                        aliens_alive <= (others => (others => '1'));
                        aliens_x_off <= ALIENS_START_X;
                        aliens_y_off <= ALIENS_START_Y;
                        alien_timer <= 0;
                        shoot_timer <= 0;
                        bullet_active <= '0';
                        e_bullet_active <= '0';
                        aliens_dir <= '1';
                    end if;
                    
                    -- Коллизия: Пуля врага -> Игрок
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

    -- ГРАФИКА (адаптирована под разрешение)
    
    -- Синхронная отрисовка объектов
    process(clock_pix)
    begin
        if rising_edge(clock_pix) then            
            -- Танк
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
    process(clock_pix)
        variable rel_x : integer;
        variable rel_y : integer;
        variable col_idx : integer;
        variable row_idx : integer;
        variable alien_pixel_x : integer;
        variable alien_pixel_y : integer;
    begin
        if rising_edge(clock_pix) then
            alien_on <= '0';
            if state = PLAYING then
                rel_x := pixel_x - aliens_x_off;
                rel_y := pixel_y - aliens_y_off;
                
                if rel_x >= 0 and rel_x < (COLS * 40) and rel_y >= 0 and rel_y < (ROWS * 32) then
                    col_idx := rel_x / 40; 
                    row_idx := rel_y / 32;
                    
                    alien_pixel_x := rel_x mod 40;
                    alien_pixel_y := rel_y mod 32;
                    
                    if row_idx < ROWS and col_idx < COLS then
                        if aliens_alive(row_idx, col_idx) = '1' and alien_pixel_x < ALIEN_W and alien_pixel_y < ALIEN_H then
                            if not ((alien_pixel_y < 4 and (alien_pixel_x < 4 or alien_pixel_x > ALIEN_W-5)) or 
                                    (alien_pixel_y > ALIEN_H-5 and (alien_pixel_x < 4 or alien_pixel_x > ALIEN_W-5))) then
                                alien_on <= '1';
                            end if;
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- Пауза
    pause_on <= '1' when pause = '1' and ((pixel_x >= center_x - 10 and pixel_x <= center_x - 5) or 
                                          (pixel_x >= center_x + 5 and pixel_x <= center_x + 10)) 
                    and (pixel_y >= MAX_Y/2 - 20 and pixel_y <= MAX_Y/2 + 20) else '0';


    process(video_on, tank_on, p_bullet_on, e_bullet_on, alien_on, pause_on,
            pixel_x, pixel_y, score, lives, state, blink_on, gameover_timer,
            MAX_X, MAX_Y, HUD_Y_POS, MENU_TITLE_Y, MENU_TEXT_Y, GAME_OVER_Y, SCORE_Y, RESTART_Y, BUTTONS_Y)

        variable hud_pixel_on : std_logic;
        variable menu_char_on : std_logic;
        variable dist3, dist2, dist1, dist0 : integer;
    begin        
        if video_on = '0' then
            red_out <= (others => '0'); green_out <= (others => '0'); blue_out <= (others => '0');
        else
            red_out <= (others => '0'); green_out <= (others => '0'); blue_out <= (others => '0');

            if state = MENU then
                menu_char_on := '0';
                
                -- Заголовок "SPACE INVADERS"
                if pixel_y >= MENU_TITLE_Y and pixel_y < MENU_TITLE_Y + 28 then
                    if is_char_pixel(pixel_x, pixel_y, 10, center_x - 156, MENU_TITLE_Y, 4) = '1' then menu_char_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, 11, center_x - 132, MENU_TITLE_Y, 4) = '1' then menu_char_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, 12, center_x - 108, MENU_TITLE_Y, 4) = '1' then menu_char_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, 13, center_x - 84, MENU_TITLE_Y, 4) = '1' then menu_char_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, 14, center_x - 60, MENU_TITLE_Y, 4) = '1' then menu_char_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, 15, center_x - 12, MENU_TITLE_Y, 4) = '1' then menu_char_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, 16, center_x + 12, MENU_TITLE_Y, 4) = '1' then menu_char_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, 17, center_x + 36, MENU_TITLE_Y, 4) = '1' then menu_char_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, 12, center_x + 60, MENU_TITLE_Y, 4) = '1' then menu_char_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, 18, center_x + 84, MENU_TITLE_Y, 4) = '1' then menu_char_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, 14, center_x + 108, MENU_TITLE_Y, 4) = '1' then menu_char_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, 19, center_x + 132, MENU_TITLE_Y, 4) = '1' then menu_char_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, 10, center_x + 156, MENU_TITLE_Y, 4) = '1' then menu_char_on := '1'; end if;
                end if;
                
                if menu_char_on = '1' then
                    red_out <= "00000000"; green_out <= "11111111"; blue_out <= "00000000";
                    menu_char_on := '0';
                end if;

                -- Текст "PRESS KEY3 TO START"
                if pixel_y >= MENU_TEXT_Y and pixel_y < MENU_TEXT_Y + 14 then
                    if is_char_pixel(pixel_x, pixel_y, 11, center_x - 120, MENU_TEXT_Y, 2) = '1' then menu_char_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, 19, center_x - 108, MENU_TEXT_Y, 2) = '1' then menu_char_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, 14, center_x - 96, MENU_TEXT_Y, 2) = '1' then menu_char_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, 10, center_x - 84, MENU_TEXT_Y, 2) = '1' then menu_char_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, 10, center_x - 72, MENU_TEXT_Y, 2) = '1' then menu_char_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, 20, center_x - 48, MENU_TEXT_Y, 2) = '1' then menu_char_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, 14, center_x - 36, MENU_TEXT_Y, 2) = '1' then menu_char_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, 21, center_x - 24, MENU_TEXT_Y, 2) = '1' then menu_char_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, 3,  center_x - 12, MENU_TEXT_Y, 2) = '1' then menu_char_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, 22, center_x + 12, MENU_TEXT_Y, 2) = '1' then menu_char_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, 23, center_x + 24, MENU_TEXT_Y, 2) = '1' then menu_char_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, 10, center_x + 48, MENU_TEXT_Y, 2) = '1' then menu_char_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, 22, center_x + 60, MENU_TEXT_Y, 2) = '1' then menu_char_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, 12, center_x + 72, MENU_TEXT_Y, 2) = '1' then menu_char_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, 19, center_x + 84, MENU_TEXT_Y, 2) = '1' then menu_char_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, 22, center_x + 96, MENU_TEXT_Y, 2) = '1' then menu_char_on := '1'; end if;
                end if;

                if menu_char_on = '1' then
                    red_out <= "11111111"; green_out <= "11111111"; blue_out <= "11111111";
                end if;

            elsif state = GAME_OVER then
                menu_char_on := '0';
                
                -- "GAME OVER"
                if pixel_y >= GAME_OVER_Y and pixel_y < GAME_OVER_Y + 28 and pixel_x < gameover_timer then
                    if is_char_pixel(pixel_x, pixel_y, 25, center_x - 108, GAME_OVER_Y, 4) = '1' then menu_char_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, 12, center_x - 84, GAME_OVER_Y, 4) = '1' then menu_char_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, 26, center_x - 60, GAME_OVER_Y, 4) = '1' then menu_char_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, 14, center_x - 36, GAME_OVER_Y, 4) = '1' then menu_char_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, 23, center_x + 12, GAME_OVER_Y, 4) = '1' then menu_char_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, 17, center_x + 36, GAME_OVER_Y, 4) = '1' then menu_char_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, 14, center_x + 60, GAME_OVER_Y, 4) = '1' then menu_char_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, 19, center_x + 84, GAME_OVER_Y, 4) = '1' then menu_char_on := '1'; end if;
                end if;
                
                if menu_char_on = '1' then
                    red_out <= "11111111"; green_out <= "00000000"; blue_out <= "00000000";
                end if;

            else
                -- Игровой экран
                if tank_on = '1' then
                    red_out <= "00000000"; green_out <= "11111111"; blue_out <= "00000000";
                elsif p_bullet_on = '1' then
                    red_out <= "11111111"; green_out <= "11111111"; blue_out <= "11111111";
                elsif e_bullet_on = '1' then
                    red_out <= "11111111"; green_out <= "00000000"; blue_out <= "11111111";
                elsif alien_on = '1' then
                    red_out <= "11111111"; green_out <= "11111111"; blue_out <= "11111111";
                end if;

                -- HUD
                hud_pixel_on := '0';
                
                if pixel_y >= HUD_Y_POS and pixel_y < HUD_Y_POS + 7 then
                    if is_char_pixel(pixel_x, pixel_y, 10, HUD_Y_POS, HUD_Y_POS, 1) = '1' then hud_pixel_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, 13, HUD_Y_POS + 6, HUD_Y_POS, 1) = '1' then hud_pixel_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, 23, HUD_Y_POS + 12, HUD_Y_POS, 1) = '1' then hud_pixel_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, 19, HUD_Y_POS + 18, HUD_Y_POS, 1) = '1' then hud_pixel_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, 14, HUD_Y_POS + 24, HUD_Y_POS, 1) = '1' then hud_pixel_on := '1'; end if;
                    
                    if is_char_pixel(pixel_x, pixel_y, (score/10000) mod 10, HUD_Y_POS + 40, HUD_Y_POS, 1) = '1' then hud_pixel_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, (score/1000) mod 10,  HUD_Y_POS + 46, HUD_Y_POS, 1) = '1' then hud_pixel_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, (score/100) mod 10,   HUD_Y_POS + 52, HUD_Y_POS, 1) = '1' then hud_pixel_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, (score/10) mod 10,    HUD_Y_POS + 58, HUD_Y_POS, 1) = '1' then hud_pixel_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, score mod 10,         HUD_Y_POS + 64, HUD_Y_POS, 1) = '1' then hud_pixel_on := '1'; end if;
                    
                    if is_char_pixel(pixel_x, pixel_y, 15, MAX_X - 70, HUD_Y_POS, 1) = '1' then hud_pixel_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, 17, MAX_X - 58, HUD_Y_POS, 1) = '1' then hud_pixel_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, 14, MAX_X - 52, HUD_Y_POS, 1) = '1' then hud_pixel_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, 10, MAX_X - 46, HUD_Y_POS, 1) = '1' then hud_pixel_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, lives, MAX_X - 35, HUD_Y_POS, 1) = '1' then hud_pixel_on := '1'; end if;
                end if;

                if hud_pixel_on = '1' then
                    red_out <= "11111111"; green_out <= "11111111"; blue_out <= "00000000";
                end if;

                if pause_on = '1' then
                    red_out <= "11111111"; green_out <= "11111111"; blue_out <= "00000000";
                end if;
            end if;
        end if;
    end process;

end behavior;