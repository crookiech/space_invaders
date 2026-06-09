LIBRARY ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library altera;
use altera.altera_syn_attributes.all;

entity spaceInvaders is
port(
    -- Системные сигналы
    clk_50 : in std_logic;
    KEY : in std_logic_vector(4 downto 0);
    SW : in std_logic_vector(2 downto 0);
    
    -- HDMI выходы
    HDMI_TX_CLK : out std_logic;
    HDMI_TX_HSYNC : out std_logic;
    HDMI_TX_VSYNC : out std_logic;
    HDMI_TX_DE : out std_logic;
    HDMI_TX_D : out std_logic_vector(23 downto 0);
    
	 UART_RX : in  std_logic;
    UART_TX : out std_logic;
	 right : buffer  std_logic;
	 LEDR : out std_logic_vector(3 downto 0);
	 
    -- I2C для ADV7513
    I2C_SCL : out std_logic;
    I2C_SDA : inout std_logic
    
);
end spaceInvaders;

architecture toplevel of spaceInvaders is
    attribute chip_pin of clk_50 : signal is "R20";
    attribute chip_pin of KEY : signal is "P11, P12, Y15, Y16, AB24";
    attribute chip_pin of SW : signal is "AD13, AE10, AC9";
    attribute chip_pin of HDMI_TX_CLK : signal is "T12";
    attribute chip_pin of HDMI_TX_HSYNC : signal is "U26";
    attribute chip_pin of HDMI_TX_VSYNC : signal is "U25";
    attribute chip_pin of HDMI_TX_DE : signal is "Y26";
    attribute chip_pin of HDMI_TX_D : signal is "AD25, AC25, AB25, AA24, AB26, R26, R24, P21, P26, N25, P23, P22, R25, R23, T26, T24, T23, U24, V25, V24, W26, W25, AA26, V23";
    attribute chip_pin of I2C_SCL : signal is "B7";
    attribute chip_pin of I2C_SDA : signal is "G11";
	 attribute chip_pin of UART_RX : signal is "M9";
    attribute chip_pin of UART_TX : signal is "L9";
	 attribute chip_pin of right : signal is "H9";
	 attribute chip_pin of LEDR : signal is "J10, H7, K8, K10";

    
    -- Сигналы
    signal refresh : std_logic;
    signal clock_pixel : std_logic;
    signal video_on : std_logic;
    signal pll_locked : std_logic;
    signal reset_n : std_logic;
    
    -- Координаты
    signal pixel_x_unsigned : unsigned(10 downto 0);
    signal pixel_y_unsigned : unsigned(9 downto 0);
    signal pixel_x_int : integer range 2047 downto 0;
    signal pixel_y_int : integer range 1023 downto 0;
    
    -- Цвета
    signal red_8bit, green_8bit, blue_8bit : std_logic_vector(7 downto 0);
    
    -- I2C инициализация
    signal init_done : std_logic;
    
	 -- Выбор разрешения
	 signal resolution : std_logic_vector(1 downto 0) := "00";
    
    -- Сигналы PLL
    signal clock_25, clock_65, clock_85 : std_logic;
	 
	 signal uart_command_code : std_logic_vector(0 to 3);
    signal uart_line_valid : std_logic;
    signal uart_speed_value : integer range 0 to 10 := 0;
    
    -- Скорость волн
    signal wave_speed : integer range 0 to 10 := 0;
	 signal right_int : std_logic;
    
	 signal current_resolution : std_logic_vector(1 downto 0) := "00";
	 signal current_wave_speed : integer range 0 to 10 := 0;
	 signal uart_resolution_valid : std_logic := '0';
	 signal uart_speed_valid : std_logic := '0';
	 signal last_right_int : std_logic := '0';

    -- Компоненты
    component pll_25 is
        port (
            refclk : in  std_logic;
            rst : in  std_logic;
            outclk_0 : out std_logic;  -- 25 MHz
            outclk_1 : out std_logic;  -- 65 MHz
            outclk_2 : out std_logic;  -- 85.5 MHz
            locked : out std_logic
        );
    end component;
    
    component adv7513_wrapper is
        port(
            clk : in  std_logic;
            reset_n : in  std_logic;
            resolution : in  std_logic_vector(1 downto 0);
            i2c_scl : out std_logic;
            i2c_sda : inout std_logic;
            init_done : out std_logic
        );
    end component;
	 
	 component command_controller is
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
    end component;

begin
    right <= right_int;
	 
	 process(clock_pixel, KEY(4))
	 begin
		if KEY(4) = '0' then  -- reset
			uart_resolution_valid <= '0';
			uart_speed_valid <= '0';
			last_right_int <= '0';
		elsif rising_edge(clock_pixel) then
			-- Определяем фронт right_int
			if right_int = '1' and last_right_int = '0' then
				-- Проверяем код разрешения (0001, 0010, 0011)
				if uart_command_code = "0001" or uart_command_code = "0010" or uart_command_code = "0011" then
					uart_resolution_valid <= '1';
				else
					uart_resolution_valid <= '0';
            end if;
            
            -- Проверяем код скорости
            if uart_command_code = "0100" or uart_command_code = "0101" or uart_command_code = "0110" or uart_command_code = "0111" or uart_command_code = "1000" or
               uart_command_code = "1001" or uart_command_code = "1010" or uart_command_code = "1011" or uart_command_code = "1100" then
					uart_speed_valid <= '1';
            else
                uart_speed_valid <= '0';
            end if;
			end if;
			last_right_int <= right_int;
		end if;
	 end process;
	 
	 process(SW, right_int, uart_resolution_valid)
    begin
        if right_int = '1' and uart_resolution_valid = '1' then
            -- Только если команда от UART корректна, обновляем разрешение
            case uart_command_code is
					when "0001" => current_resolution <= "01";  -- res1024
					when "0010" => current_resolution <= "10";  -- res1360
					when "0011" => current_resolution <= "00";  -- res640
					when others => null;  -- Неверная команда - ничего не меняем
			   end case;
		  elsif right_int = '0' then
			   -- Ручное управление переключателями
			   if SW(2) = '0' and SW(1) = '0' then
				 	 current_resolution <= "00";      -- 640x480
			   elsif SW(2) = '1' and SW(1) = '0' then
					 current_resolution <= "10";      -- 1360x768
			   elsif SW(2) = '0' and SW(1) = '1' then
					 current_resolution <= "01";      -- 1024x768
			   else
					 current_resolution <= "00";
			   end if;
		  end if;
	 end process;
	 
	 process(uart_speed_valid, right_int)
	 begin
		  if right_int = '1' and uart_speed_valid = '1' then
			   -- Только если команда от UART корректна, обновляем скорость
			   case uart_command_code is
					when "0100" => current_wave_speed <= 1;
					when "0101" => current_wave_speed <= 2;
					when "0110" => current_wave_speed <= 3;
					when "0111" => current_wave_speed <= 4;
					when "1000" => current_wave_speed <= 5;
					when "1001" => current_wave_speed <= 6;
					when "1010" => current_wave_speed <= 7;
					when "1011" => current_wave_speed <= 8;
					when "1100" => current_wave_speed <= 9;
					when others => null;  -- Неверная команда - ничего не меняем
			  end case;
		 end if;
    end process;
    
	 resolution <= current_resolution;
	 wave_speed <= current_wave_speed;
	 
    process(resolution, clock_25, clock_65, clock_85, pll_locked)
    begin
        case resolution is
            when "00" =>   -- 640x480
                clock_pixel <= clock_25;
					 reset_n <= pll_locked;
            when "01" =>   -- 1024x768
                clock_pixel <= clock_65;
					 reset_n <= pll_locked;
            when "10" =>   -- 1360x768
                clock_pixel <= clock_85;
					 reset_n <= pll_locked;
            when others =>
                clock_pixel <= clock_25;
					 reset_n <= pll_locked;
        end case;
    end process;
	 
	 -- Преобразование координат
    pixel_x_int <= to_integer(pixel_x_unsigned);
    pixel_y_int <= to_integer(pixel_y_unsigned);
    
    -- PLL
    pll_inst : component pll_25
        port map (
            refclk => clk_50,
            rst => '0',
            outclk_0 => clock_25,
            outclk_1 => clock_65,
            outclk_2 => clock_85,
            locked => pll_locked
        );
    
	 -- I2C инициализация ADV7513
    i2c_init: component adv7513_wrapper
        port map(
            clk => clk_50,
            reset_n => KEY(4),
            resolution => resolution,
            i2c_scl => I2C_SCL,
            i2c_sda => I2C_SDA,
            init_done => init_done
        );
	 
	 uart_inst: component command_controller
        port map(
            clk => clk_50,
            rst => KEY(4),
            rx => UART_RX,
            tx => UART_TX,
            line_valid => uart_line_valid,
            right => right_int,
				led0 => LEDR(0),
            led1 => LEDR(1),
            led2 => LEDR(2),
            led3 => LEDR(3),
            command_code_out => uart_command_code
        );
	 
    -- Генератор синхронизации
    vgasync : entity work.spaceInvadersSync
        port map(
            pixel_clk => clock_pixel,
            reset_n => pll_locked,
            resolution => resolution,
            hsync => HDMI_TX_HSYNC,
            vsync => HDMI_TX_VSYNC,
            de => video_on,
            pixel_x => pixel_x_unsigned,
            pixel_y => pixel_y_unsigned,
            frame_tick => refresh
        );
    
    -- Генератор изображения
    imagegen : entity work.invadersImg
        port map(
            btn_reset => not KEY(4),
            refresh => refresh,
            resolution => resolution,
			   wave_speed => wave_speed,
            clock_pix => clock_pixel,
            video_on => video_on,
            btn_left => not KEY(2),
            btn_right => not KEY(0),
            btn_fire => not KEY(1),
            btn_start => not KEY(3),
            pause => SW(0),
            pixel_x => pixel_x_int,
            pixel_y => pixel_y_int,
            red_out => red_8bit,
            green_out => green_8bit,
            blue_out => blue_8bit
        );
    

    -- Выходы
    HDMI_TX_D <= red_8bit & green_8bit & blue_8bit;
    HDMI_TX_CLK <= clock_pixel;
    HDMI_TX_DE <= video_on;
    
end toplevel;