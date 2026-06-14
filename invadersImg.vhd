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

    attribute syn_encoding : string;
    attribute syn_encoding of state : signal is "safe, one-hot";

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
	 
	 -- Параметры кнопок для разных разрешений
    signal btn_key3_x : integer := 230;
    signal btn_key2_x : integer := 290;
    signal btn_key1_x : integer := 350;
    signal btn_key0_x : integer := 410;
    signal btn_y : integer := 360;
    signal btn_radius_sq : integer := 144;  -- 12^2

    -- Корабль игрока (Tank)
    constant TANK_W : integer := 30;
    constant TANK_H : integer := 16;
    signal tank_x : integer := 305;
    
    -- Регистры для синхронного CDC отслеживания переключения разрешения
    signal r_tank_y : integer := 440;
    
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
    constant ALIEN_GAP : integer := 8;
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
    
    -- Сигналы для UART детектора изменения скорости (без прожорливых таймеров!)
    signal pending_wave_speed : integer range 0 to 10 := 0;
    signal r_wave_speed       : integer range 0 to 10 := 0;
	 
	 -- Детектор фронта сигнала refresh для синхронизации CDC
    signal refresh_r1 : std_logic := '0';
    signal refresh_r2 : std_logic := '0';

	 signal refresh_pulse : std_logic := '0';

    -- Промежуточные сигналы управления автоматом (декаплинг)
    signal start_game   : std_logic := '0';
    signal restart_game : std_logic := '0';
    signal game_lost    : std_logic := '0';

    -- Шрифт 5x7 (Расширен до 27 индексов для полноценных букв L и F)
    function is_char_pixel (
        px, py : integer;
        char_val : integer;
        start_x, start_y : integer;
        scale : integer
    ) return std_logic is
        constant CHAR_WIDTH : integer := 5;
        constant CHAR_HEIGHT : integer := 7;
        variable local_x, local_y : integer;
        
        type char_pattern_array is array (0 to 27) of std_logic_vector(34 downto 0);
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
            24 => "10000" & "10000" & "10000" & "10000" & "10000" & "10000" & "11111", -- 'L'
            25 => "01110" & "10001" & "10000" & "10111" & "10001" & "10001" & "01110",
            26 => "10001" & "11011" & "10101" & "10001" & "10001" & "10001" & "10001",
            27 => "11111" & "10000" & "10000" & "11110" & "10000" & "10000" & "10000"  -- 'F'
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
    start_game   <= '1' when (state = MENU and btn_start = '1') else '0';
    restart_game <= '1' when (state = GAME_OVER and btn_start = '1') else '0';

    FSM_STATE_PROC: process(refresh, btn_reset)
    begin
        if btn_reset = '1' then
            state <= MENU;
        elsif rising_edge(refresh) then
            case state is
                when MENU =>
                    if start_game = '1' then
                        state <= PLAYING;
                    end if;
                when PLAYING =>
                    if game_lost = '1' then
                        state <= GAME_OVER;
                    end if;
                when GAME_OVER =>
                    if restart_game = '1' then
                        state <= MENU;
                    end if;
            end case;
        end if;
    end process;


    GAME_DATAPATH_PROC: process(refresh, btn_reset)
        variable shoot_col : integer range 0 to COLS-1;
        variable found_alien : boolean;
        variable all_aliens_dead : boolean;
        variable temp_aliens_alive : alien_array;
        variable leftmost_alien : integer;
        variable rightmost_alien : integer;
        variable can_move_left : boolean;
        variable can_move_right : boolean;
        variable any_alive : boolean;
    begin
        if btn_reset = '1' then
            tank_x <= 305;
            bullet_active <= '0';
            e_bullet_active <= '0';
            aliens_alive <= (others => (others => '1'));
            aliens_x_off <= 50;
            aliens_y_off <= 40;
            r_tank_y <= 440;
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
            game_lost <= '0';
            
            r_wave_speed <= wave_speed;
            pending_wave_speed <= 0;
        elsif rising_edge(refresh) then
	 
            if TANK_Y /= r_tank_y then
                if (aliens_y_off + (TANK_Y - r_tank_y)) < ALIENS_START_Y then
                    aliens_y_off <= ALIENS_START_Y; 
                else
                    aliens_y_off <= aliens_y_off + (TANK_Y - r_tank_y);
                end if;
                r_tank_y <= TANK_Y;
            end if;

            if state = MENU then
                tank_x <= center_x - 15;
                aliens_x_off <= ALIENS_START_X;
                aliens_y_off <= ALIENS_START_Y;
                game_lost <= '0'; -- Сброс флага поражения
            else
                if tank_x < 10 then
                    tank_x <= 10;
                elsif tank_x > (MAX_X - TANK_W - 10) then
                    tank_x <= MAX_X - TANK_W - 10;
                end if;

                any_alive := false;
                leftmost_alien := COLS - 1;
                rightmost_alien := 0;
                for r in 0 to ROWS-1 loop
                    for c in 0 to COLS-1 loop
                        if aliens_alive(r,c) = '1' then
                            any_alive := true;
                            if c < leftmost_alien then leftmost_alien := c; end if;
                            if c > rightmost_alien then rightmost_alien := c; end if;
                        end if;
                    end loop;
                end loop;

                if any_alive then
                    if (aliens_x_off + leftmost_alien * 32) < 20 then
                        aliens_x_off <= 20 - (leftmost_alien * 32);
                    elsif (aliens_x_off + rightmost_alien * 32 + ALIEN_W) > (MAX_X - 20) then
                        aliens_x_off <= MAX_X - 20 - ALIEN_W - (rightmost_alien * 32);
                    end if;
                end if;
            end if;

            if bullet_active = '1' and (bullet_x > MAX_X or bullet_y > TANK_Y + TANK_H) then
                bullet_active <= '0';
            end if;
            if e_bullet_active = '1' and (e_bullet_x > MAX_X or e_bullet_y > TANK_Y + TANK_H) then
                e_bullet_active <= '0';
            end if;
            
            if wave_speed /= r_wave_speed then
                r_wave_speed <= wave_speed;
                if wave_speed >= 1 and wave_speed <= 10 then
                    wave <= wave_speed;
                    pending_wave_speed <= wave_speed;
                    alien_timer <= 0;
                    shoot_timer <= 0;
                end if;
            end if;
            
            if blink_reg = 29 then
                blink_reg <= (others => '0');
                blink_on <= not blink_on;
            else
                blink_reg <= blink_reg + 1;
            end if;

            if pause = '0' then
                
                if start_game = '1' then
                    score <= 0;
                    lives <= 3;
                    
                    if pending_wave_speed >= 1 and pending_wave_speed <= 10 then
                        wave <= pending_wave_speed;
                    else
                        wave <= 1;
                    end if;
                    
                    aliens_killed_count <= 0;
                    aliens_alive <= (others => (others => '1'));
                    aliens_x_off <= ALIENS_START_X;
                    aliens_y_off <= ALIENS_START_Y;
                    tank_x <= center_x - 15;
                    bullet_active <= '0';
                    e_bullet_active <= '0';
                    alien_timer <= 0;
                    shoot_timer <= 0;
                    aliens_dir <= '1';
                    alien_invasion_gameover <= '0';
                    game_lost <= '0';
                    
                elsif state = PLAYING then
                    gameover_timer <= 0;
                    
                    if wave < 1 then wave <= 1; end if;
                    if wave > 10 then wave <= 10; end if;
                    
                    -- Проверка вторжения пришельцев на высоту танка
                    found_alien := false;
                    for r in 0 to ROWS-1 loop
                        for c in 0 to COLS-1 loop
                            if aliens_alive(r,c) = '1' then
                                if (aliens_y_off + r*32 + ALIEN_H) >= TANK_Y then 
                                     found_alien := true;
                                end if;
                            end if;
                        end loop;
                    end loop;

                    if found_alien then
                        alien_invasion_gameover <= '1';
                        game_lost <= '1'; 
                        pending_wave_speed <= 0; 
                    end if;

                    -- Обработка перемещения танка
                    if btn_left = '1' and tank_x > 10 then
                        tank_x <= tank_x - 3;
                    elsif btn_right = '1' and tank_x < (MAX_X - TANK_W - 10) then
                        tank_x <= tank_x + 3;
                    end if;

                    -- Выстрел игрока
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

                    -- Шаг сетки пришельцев
                    alien_timer <= alien_timer + 1;
                    if alien_timer >= ALIEN_MOVE_SPEED_FRAMES(wave) then
                        alien_timer <= 0;
                        
                        can_move_left := (aliens_x_off + leftmost_alien*32 > 20);
                        can_move_right := (aliens_x_off + rightmost_alien*32 + ALIEN_W < MAX_X - 20);
                        
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

                    -- Выстрел пришельца
                    if e_bullet_active = '0' then
                        shoot_timer <= shoot_timer + 1;
                        if shoot_timer >= ALIEN_SHOOT_SPEED_FRAMES(wave) then
                            shoot_timer <= 0;
                            shoot_col := to_integer(unsigned(lfsr(2 downto 0))) mod COLS;
                            found_alien := false;
                            for r_idx in ROWS-1 downto 0 loop
                                if aliens_alive(r_idx, shoot_col) = '1' then
                                    e_bullet_active <= '1';
                                    e_bullet_x <= aliens_x_off + shoot_col*32 + ALIEN_W/2;
                                    e_bullet_y <= aliens_y_off + r_idx*32 + ALIEN_H;
                                    found_alien := true;
                                    exit;
                                end if;
                            end loop;
                        end if;
                    else
                        e_bullet_y <= e_bullet_y + 5;
                        if e_bullet_y > MAX_Y then e_bullet_active <= '0'; end if;
                    end if;

                    -- Обработка коллизий (попадание игрока)
                    all_aliens_dead := true;
                    temp_aliens_alive := aliens_alive;
                    for r in 0 to ROWS-1 loop
                        for c in 0 to COLS-1 loop
                            if aliens_alive(r,c) = '1' then
                                if bullet_active = '1' then
                                     if bullet_x >= (aliens_x_off + c*32) and
                                         bullet_x <= (aliens_x_off + c*32 + ALIEN_W) and
                                         bullet_y >= (aliens_y_off + r*32) and
                                         bullet_y <= (aliens_y_off + r*32 + ALIEN_H) then
                                              temp_aliens_alive(r,c) := '0';
                                              bullet_active <= '0';
                                              score <= score + 10;
                                     else
                                          all_aliens_dead := false;
                                     end if;
                                else
                                     all_aliens_dead := false;
                                end if;
                            end if;
                        end loop;
                    end loop;
                    aliens_alive <= temp_aliens_alive;

                    if all_aliens_dead then
                        if wave < 10 then
                            wave <= wave + 1;
                            if lives < 3 then lives <= lives + 1; end if;
                        end if;
                        aliens_alive <= (others => (others => '1'));
                        aliens_x_off <= ALIENS_START_X;
                        aliens_y_off <= ALIENS_START_Y;
                        alien_timer <= 0;
                        shoot_timer <= 0;
                        bullet_active <= '0';
                        e_bullet_active <= '0';
                        aliens_dir <= '1';
                    end if;
                    
                    -- Обработка попадания пришельца в игрока
                    if e_bullet_active = '1' and
                       e_bullet_x >= tank_x and e_bullet_x <= tank_x + TANK_W and
                       e_bullet_y >= TANK_Y and e_bullet_y <= TANK_Y + TANK_H then
                        e_bullet_active <= '0';
                        if lives = 1 then
                            lives <= 0;
                            game_lost <= '1'; 
                            pending_wave_speed <= 0; 
                        else
                            lives <= lives - 1;
                        end if;
                    end if;

                elsif state = GAME_OVER then
                    if gameover_timer < 1023 then
                        gameover_timer <= gameover_timer + 3; 
                    end if;
                end if;
            end if;
        end if;
    end process;


    -- ГРАФИКА
    
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
						 
						 if rel_x >= 0 and rel_x < (COLS * 32) and rel_y >= 0 and rel_y < (ROWS * 32) then
							  col_idx := rel_x / 32; 
							  row_idx := rel_y / 32;
							  
							  alien_pixel_x := rel_x mod 32; 
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

    process(clock_pix)
        variable hud_pixel_on : std_logic;
        variable menu_char_on : std_logic;
        variable dist3, dist2, dist1, dist0 : integer;
		  
		  variable title_start_x   : integer;
        variable press_start_x   : integer;
        variable game_over_start_x : integer;
        variable score_start_x   : integer;
        variable restart_start_x : integer;

    begin
        if rising_edge(clock_pix) then
            red_out <= (others => '0');
            green_out <= (others => '0');
            blue_out <= (others => '0');

            if video_on = '1' then
                -- 1. ЛОГИКА МЕНЮ
                if state = MENU then
                    menu_char_on := '0';
						  
						  title_start_x := center_x - 166;
                    if pixel_y >= MENU_TITLE_Y and pixel_y < MENU_TITLE_Y + 28 then
                    if is_char_pixel(pixel_x, pixel_y, 10, title_start_x + 0*24,  MENU_TITLE_Y, 4) = '1' then menu_char_on := '1'; end if; -- S
                    if is_char_pixel(pixel_x, pixel_y, 11, title_start_x + 1*24,  MENU_TITLE_Y, 4) = '1' then menu_char_on := '1'; end if; -- P
                    if is_char_pixel(pixel_x, pixel_y, 12, title_start_x + 2*24,  MENU_TITLE_Y, 4) = '1' then menu_char_on := '1'; end if; -- A
						  if is_char_pixel(pixel_x, pixel_y, 13, title_start_x + 3*24,  MENU_TITLE_Y, 4) = '1' then menu_char_on := '1'; end if; -- C
                    if is_char_pixel(pixel_x, pixel_y, 14, title_start_x + 4*24,  MENU_TITLE_Y, 4) = '1' then menu_char_on := '1'; end if; -- E
                    if is_char_pixel(pixel_x, pixel_y, 15, title_start_x + 6*24,  MENU_TITLE_Y, 4) = '1' then menu_char_on := '1'; end if; -- I
                    if is_char_pixel(pixel_x, pixel_y, 16, title_start_x + 7*24,  MENU_TITLE_Y, 4) = '1' then menu_char_on := '1'; end if; -- N
                    if is_char_pixel(pixel_x, pixel_y, 17, title_start_x + 8*24,  MENU_TITLE_Y, 4) = '1' then menu_char_on := '1'; end if; -- V
                    if is_char_pixel(pixel_x, pixel_y, 12, title_start_x + 9*24,  MENU_TITLE_Y, 4) = '1' then menu_char_on := '1'; end if; -- A
                    if is_char_pixel(pixel_x, pixel_y, 18, title_start_x + 10*24, MENU_TITLE_Y, 4) = '1' then menu_char_on := '1'; end if; -- D
                    if is_char_pixel(pixel_x, pixel_y, 14, title_start_x + 11*24, MENU_TITLE_Y, 4) = '1' then menu_char_on := '1'; end if; -- E
                    if is_char_pixel(pixel_x, pixel_y, 19, title_start_x + 12*24, MENU_TITLE_Y, 4) = '1' then menu_char_on := '1'; end if; -- R
                    if is_char_pixel(pixel_x, pixel_y, 10, title_start_x + 13*24, MENU_TITLE_Y, 4) = '1' then menu_char_on := '1'; end if; -- S

                    end if;
                    
                press_start_x := center_x - 113;
                if pixel_y >= MENU_TEXT_Y and pixel_y < MENU_TEXT_Y + 14 then
                    if is_char_pixel(pixel_x, pixel_y, 11, press_start_x + 0*12,  MENU_TEXT_Y, 2) = '1' then menu_char_on := '1'; end if; -- P
                    if is_char_pixel(pixel_x, pixel_y, 19, press_start_x + 1*12,  MENU_TEXT_Y, 2) = '1' then menu_char_on := '1'; end if; -- R
                    if is_char_pixel(pixel_x, pixel_y, 14, press_start_x + 2*12,  MENU_TEXT_Y, 2) = '1' then menu_char_on := '1'; end if; -- E
                    if is_char_pixel(pixel_x, pixel_y, 10, press_start_x + 3*12,  MENU_TEXT_Y, 2) = '1' then menu_char_on := '1'; end if; -- S
                    if is_char_pixel(pixel_x, pixel_y, 10, press_start_x + 4*12,  MENU_TEXT_Y, 2) = '1' then menu_char_on := '1'; end if; -- S
                    if is_char_pixel(pixel_x, pixel_y, 20, press_start_x + 6*12,  MENU_TEXT_Y, 2) = '1' then menu_char_on := '1'; end if; -- K
                    if is_char_pixel(pixel_x, pixel_y, 14, press_start_x + 7*12,  MENU_TEXT_Y, 2) = '1' then menu_char_on := '1'; end if; -- E
                    if is_char_pixel(pixel_x, pixel_y, 21, press_start_x + 8*12,  MENU_TEXT_Y, 2) = '1' then menu_char_on := '1'; end if; -- Y
                    if is_char_pixel(pixel_x, pixel_y, 3,  press_start_x + 9*12,  MENU_TEXT_Y, 2) = '1' then menu_char_on := '1'; end if; -- 3
                    if is_char_pixel(pixel_x, pixel_y, 22, press_start_x + 11*12, MENU_TEXT_Y, 2) = '1' then menu_char_on := '1'; end if; -- T
                    if is_char_pixel(pixel_x, pixel_y, 23, press_start_x + 12*12, MENU_TEXT_Y, 2) = '1' then menu_char_on := '1'; end if; -- O
                    if is_char_pixel(pixel_x, pixel_y, 10, press_start_x + 14*12, MENU_TEXT_Y, 2) = '1' then menu_char_on := '1'; end if; -- S
                    if is_char_pixel(pixel_x, pixel_y, 22, press_start_x + 15*12, MENU_TEXT_Y, 2) = '1' then menu_char_on := '1'; end if; -- T
                    if is_char_pixel(pixel_x, pixel_y, 12, press_start_x + 16*12, MENU_TEXT_Y, 2) = '1' then menu_char_on := '1'; end if; -- A
                    if is_char_pixel(pixel_x, pixel_y, 19, press_start_x + 17*12, MENU_TEXT_Y, 2) = '1' then menu_char_on := '1'; end if; -- R
                    if is_char_pixel(pixel_x, pixel_y, 22, press_start_x + 18*12, MENU_TEXT_Y, 2) = '1' then menu_char_on := '1'; end if; -- T
                end if;

                if menu_char_on = '1' then
                    red_out <= "11111111"; green_out <= "11111111"; blue_out <= "11111111";
                end if;

                    dist3 := (pixel_x - btn_key3_x)*(pixel_x - btn_key3_x) + (pixel_y - btn_y)*(pixel_y - btn_y);
						 dist2 := (pixel_x - btn_key2_x)*(pixel_x - btn_key2_x) + (pixel_y - btn_y)*(pixel_y - btn_y);
						 dist1 := (pixel_x - btn_key1_x)*(pixel_x - btn_key1_x) + (pixel_y - btn_y)*(pixel_y - btn_y);
						 dist0 := (pixel_x - btn_key0_x)*(pixel_x - btn_key0_x) + (pixel_y - btn_y)*(pixel_y - btn_y);

                    if menu_char_on = '1' then
                        green_out <= "11111111"; -- Текст меню
                    elsif dist3 <= btn_radius_sq then
                        if blink_on = '1' then green_out <= "11111111"; else green_out <= "01000000"; end if;
                    elsif dist2 <= btn_radius_sq or dist1 <= btn_radius_sq or dist0 <= btn_radius_sq then red_out <= "01000000"; green_out <= "01000000"; blue_out <= "01000000";
                    end if;

                -- 2. ЛОГИКА GAME OVER
                elsif state = GAME_OVER then
						  game_over_start_x := center_x - 106;
                    if pixel_y >= GAME_OVER_Y and pixel_y < GAME_OVER_Y + 28 and 
                   (gameover_timer >= 300 or pixel_x < game_over_start_x + gameover_timer * 2) then
                       if is_char_pixel(pixel_x, pixel_y, 25, game_over_start_x + 0*24, GAME_OVER_Y, 4) = '1' then red_out <= "11111111"; end if;
								if is_char_pixel(pixel_x, pixel_y, 12, game_over_start_x + 1*24, GAME_OVER_Y, 4) = '1' then red_out <= "11111111"; end if;
								if is_char_pixel(pixel_x, pixel_y, 26, game_over_start_x + 2*24, GAME_OVER_Y, 4) = '1' then red_out <= "11111111"; end if;
								if is_char_pixel(pixel_x, pixel_y, 14, game_over_start_x + 3*24, GAME_OVER_Y, 4) = '1' then red_out <= "11111111"; end if;
								if is_char_pixel(pixel_x, pixel_y, 23, game_over_start_x + 5*24, GAME_OVER_Y, 4) = '1' then red_out <= "11111111"; end if;
								if is_char_pixel(pixel_x, pixel_y, 17, game_over_start_x + 6*24, GAME_OVER_Y, 4) = '1' then red_out <= "11111111"; end if;
								if is_char_pixel(pixel_x, pixel_y, 14, game_over_start_x + 7*24, GAME_OVER_Y, 4) = '1' then red_out <= "11111111"; end if;
								if is_char_pixel(pixel_x, pixel_y, 19, game_over_start_x + 8*24, GAME_OVER_Y, 4) = '1' then red_out <= "11111111"; end if;
                    end if;
                    
                    score_start_x := center_x - 66;
                if gameover_timer > 300 and pixel_y >= SCORE_Y and pixel_y < SCORE_Y + 14 and 
                   (gameover_timer >= 600 or pixel_x < score_start_x + (gameover_timer - 300) * 2) then
                    if is_char_pixel(pixel_x, pixel_y, 10, score_start_x + 0*12, SCORE_Y, 2) = '1' then menu_char_on := '1'; end if; -- S
                    if is_char_pixel(pixel_x, pixel_y, 13, score_start_x + 1*12, SCORE_Y, 2) = '1' then menu_char_on := '1'; end if; -- C
                    if is_char_pixel(pixel_x, pixel_y, 23, score_start_x + 2*12, SCORE_Y, 2) = '1' then menu_char_on := '1'; end if; -- O
                    if is_char_pixel(pixel_x, pixel_y, 19, score_start_x + 3*12, SCORE_Y, 2) = '1' then menu_char_on := '1'; end if; -- R
                    if is_char_pixel(pixel_x, pixel_y, 14, score_start_x + 4*12, SCORE_Y, 2) = '1' then menu_char_on := '1'; end if; -- E
                    if (pixel_x >= score_start_x + 62 and pixel_x <= score_start_x + 64 and pixel_y >= SCORE_Y + 2 and pixel_y <= SCORE_Y + 4) or
                       (pixel_x >= score_start_x + 62 and pixel_x <= score_start_x + 64 and pixel_y >= SCORE_Y + 8 and pixel_y <= SCORE_Y + 10) then
                        menu_char_on := '1';
                    end if;
                    if is_char_pixel(pixel_x, pixel_y, (score/10000) mod 10, score_start_x + 74,  SCORE_Y, 2) = '1' then menu_char_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, (score/1000) mod 10,  score_start_x + 86,  SCORE_Y, 2) = '1' then menu_char_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, (score/100) mod 10,   score_start_x + 98,  SCORE_Y, 2) = '1' then menu_char_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, (score/10) mod 10,    score_start_x + 110, SCORE_Y, 2) = '1' then menu_char_on := '1'; end if;
                    if is_char_pixel(pixel_x, pixel_y, score mod 10,         score_start_x + 122, SCORE_Y, 2) = '1' then menu_char_on := '1'; end if;
                end if;

                if menu_char_on = '1' then
                    red_out <= "11111111"; green_out <= "11111111"; blue_out <= "11111111";
                    menu_char_on := '0';
                end if;
                
                restart_start_x := center_x - 125;
                if gameover_timer > 500 and pixel_y >= RESTART_Y and pixel_y < RESTART_Y + 14 and 
                   (gameover_timer >= 800 or pixel_x < restart_start_x + (gameover_timer - 500) * 2) then
                    if is_char_pixel(pixel_x, pixel_y, 11, restart_start_x + 0*12,  RESTART_Y, 2) = '1' then menu_char_on := '1'; end if; -- P
                    if is_char_pixel(pixel_x, pixel_y, 19, restart_start_x + 1*12,  RESTART_Y, 2) = '1' then menu_char_on := '1'; end if; -- R
                    if is_char_pixel(pixel_x, pixel_y, 14, restart_start_x + 2*12,  RESTART_Y, 2) = '1' then menu_char_on := '1'; end if; -- E
                    if is_char_pixel(pixel_x, pixel_y, 10, restart_start_x + 3*12,  RESTART_Y, 2) = '1' then menu_char_on := '1'; end if; -- S
                    if is_char_pixel(pixel_x, pixel_y, 10, restart_start_x + 4*12,  RESTART_Y, 2) = '1' then menu_char_on := '1'; end if; -- S
                    if is_char_pixel(pixel_x, pixel_y, 20, restart_start_x + 6*12,  RESTART_Y, 2) = '1' then menu_char_on := '1'; end if; -- K
                    if is_char_pixel(pixel_x, pixel_y, 14, restart_start_x + 7*12,  RESTART_Y, 2) = '1' then menu_char_on := '1'; end if; -- E
                    if is_char_pixel(pixel_x, pixel_y, 21, restart_start_x + 8*12,  RESTART_Y, 2) = '1' then menu_char_on := '1'; end if; -- Y
                    if is_char_pixel(pixel_x, pixel_y, 3,  restart_start_x + 9*12,  RESTART_Y, 2) = '1' then menu_char_on := '1'; end if; -- 3
                    if is_char_pixel(pixel_x, pixel_y, 22, restart_start_x + 11*12, RESTART_Y, 2) = '1' then menu_char_on := '1'; end if; -- T
                    if is_char_pixel(pixel_x, pixel_y, 23, restart_start_x + 12*12, RESTART_Y, 2) = '1' then menu_char_on := '1'; end if; -- O
                    if is_char_pixel(pixel_x, pixel_y, 19, restart_start_x + 14*12, RESTART_Y, 2) = '1' then menu_char_on := '1'; end if; -- R
                    if is_char_pixel(pixel_x, pixel_y, 14, restart_start_x + 15*12, RESTART_Y, 2) = '1' then menu_char_on := '1'; end if; -- E
                    if is_char_pixel(pixel_x, pixel_y, 10, restart_start_x + 16*12, RESTART_Y, 2) = '1' then menu_char_on := '1'; end if; -- S
                    if is_char_pixel(pixel_x, pixel_y, 22, restart_start_x + 17*12, RESTART_Y, 2) = '1' then menu_char_on := '1'; end if; -- T
                    if is_char_pixel(pixel_x, pixel_y, 12, restart_start_x + 18*12, RESTART_Y, 2) = '1' then menu_char_on := '1'; end if; -- A
                    if is_char_pixel(pixel_x, pixel_y, 19, restart_start_x + 19*12, RESTART_Y, 2) = '1' then menu_char_on := '1'; end if; -- R
                    if is_char_pixel(pixel_x, pixel_y, 22, restart_start_x + 20*12, RESTART_Y, 2) = '1' then menu_char_on := '1'; end if; -- T
                end if;

                if menu_char_on = '1' then
                    red_out <= "11111111"; green_out <= "11111111"; blue_out <= "11111111";
                end if;

                -- Кнопки в GAME OVER
                if gameover_timer > 700 then
                    dist3 := (pixel_x - btn_key3_x)*(pixel_x - btn_key3_x) + (pixel_y - btn_y)*(pixel_y - btn_y);
                    dist2 := (pixel_x - btn_key2_x)*(pixel_x - btn_key2_x) + (pixel_y - btn_y)*(pixel_y - btn_y);
                    dist1 := (pixel_x - btn_key1_x)*(pixel_x - btn_key1_x) + (pixel_y - btn_y)*(pixel_y - btn_y);
                    dist0 := (pixel_x - btn_key0_x)*(pixel_x - btn_key0_x) + (pixel_y - btn_y)*(pixel_y - btn_y);

                    if dist3 <= btn_radius_sq then
                        if blink_on = '1' then
                            red_out <= "00000000"; green_out <= "11111111"; blue_out <= "00000000";
                        else
                            red_out <= "00000000"; green_out <= "01000000"; blue_out <= "00000000";
                        end if;
                    elsif dist2 <= btn_radius_sq or dist1 <= btn_radius_sq or dist0 <= btn_radius_sq then
                        red_out <= "01000000"; green_out <= "01000000"; blue_out <= "01000000";
                    end if;
                end if;

                -- 3. ИГРОВОЙ ПРОЦЕСС
                else
                    if tank_on = '1' then
                        green_out <= "11111111";
                    elsif p_bullet_on = '1' then
                        red_out <= "11111111"; green_out <= "11111111"; blue_out <= "11111111";
                    elsif e_bullet_on = '1' then
                        red_out <= "11111111"; blue_out <= "11111111";
                    elsif alien_on = '1' then
                        red_out <= "11111111"; green_out <= "11111111"; blue_out <= "11111111";
                    end if;

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
	                    
	                    -- Вывод надписи L I F E S (Индексы: 24='L', 15='I', 27='F', 14='E', 10='S')
	                    if is_char_pixel(pixel_x, pixel_y, 24, MAX_X - 70, HUD_Y_POS, 1) = '1' then hud_pixel_on := '1'; end if;
					        if is_char_pixel(pixel_x, pixel_y, 15, MAX_X - 64, HUD_Y_POS, 1) = '1' then hud_pixel_on := '1'; end if;
	                    if is_char_pixel(pixel_x, pixel_y, 27, MAX_X - 58, HUD_Y_POS, 1) = '1' then hud_pixel_on := '1'; end if;
	                    if is_char_pixel(pixel_x, pixel_y, 14, MAX_X - 52, HUD_Y_POS, 1) = '1' then hud_pixel_on := '1'; end if;
	                    if is_char_pixel(pixel_x, pixel_y, 10, MAX_X - 46, HUD_Y_POS, 1) = '1' then hud_pixel_on := '1'; end if;
	                    if is_char_pixel(pixel_x, pixel_y, lives, MAX_X - 35, HUD_Y_POS, 1) = '1' then hud_pixel_on := '1'; end if;
                    end if;
                    
                    if hud_pixel_on = '1' or pause_on = '1' then
                        red_out <= "11111111"; green_out <= "11111111"; -- Желтый
                    end if;
                end if;
            end if;
        end if;
    end process;

end behavior;
