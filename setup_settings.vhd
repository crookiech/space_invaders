library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity setup_settings is
  port (
    address : in  std_logic_vector(7 downto 0);
    resolution : in  std_logic_vector(1 downto 0);  -- "00":640x480, "01":1024x768, "10":1360x768
    data : out std_logic_vector(23 downto 0);
    settings_length : out std_logic_vector(7 downto 0)
  );
end setup_settings;

architecture rtl of setup_settings is
  type settings_array is array (0 to 60) of std_logic_vector(23 downto 0);
  
  -- Базовая конфигурация (общая для всех разрешений)
  constant settings_BASE : settings_array := (
    0 => x"724110",  -- Power-down mode ON
    1 => x"724100",  -- Power-down OFF
    2 => x"729803",  -- ADI required (0x98 = 0x03)
    3 => x"729AE0",  -- ADI required (0x9A[7:1] = 0b1110000)
    4 => x"729C30",  -- ADI required (0x9C = 0x30)
    5 => x"729D01",  -- ADI required (0x9D[1:0] = 0b01)
    6 => x"72A2A4",  -- ADI required (0xA2 = 0xA4)
    7 => x"72A3A4",  -- ADI required (0xA3 = 0xA4)
    8 => x"72E0D0",  -- ADI required (0xE0 = 0xD0)
    9 => x"72F900",  -- ADI required (0xF9 = 0x00)
    10 => x"721500",  -- 24-bit RGB, separate syncs
    11 => x"721660",  -- 24-bit input, style 1, rising edge
    12 => x"721846",  -- CSC disabled
    13 => x"724808",  -- 24-bit output, RGB
    14 => x"724C06",  -- 12-bit output mode
	 15 => x"724D00",  -- Output color depth (12-bit)
    16 => x"725500",  -- RGB in AV Info Frame
    17 => x"725608",  -- Active format aspect
    18 => x"72AF16",  -- Set HDMI Mode, no HDCP (0xAF[7:0] = 0x16)
    19 => x"72D6C0",  -- HPD Override (0xD6[7:6] = 0b11)
    others => x"000000"
  );
  
  -- Конфигурация для 640x480 @ 60Hz
  constant settings_640x480 : settings_array := (
    0 => x"72358F",  -- DE H placement low byte (0x8F)
    1 => x"723602",  -- DE H placement high byte (0x02)
    2 => x"72377F",  -- DE H duration low byte (0x7F)
    3 => x"723802",  -- DE H duration high byte (0x02)
    4 => x"7239E9",  -- DE V placement low byte (0xE9)
    5 => x"723A01",  -- DE V placement high byte (0x01)
    6 => x"723CDF",  -- DE V duration low byte (0xDF)
    7 => x"723D01",  -- DE V duration high byte (0x01)
    8 => x"723E01",  -- VIC 1: 640x480p
    others => x"000000"
  );
  
  -- Конфигурация для 1024x768 @ 60Hz
  constant settings_1024x768 : settings_array := (
    0 => x"72352F",  -- DE H placement low byte (0x2F)
    1 => x"723604",  -- DE H placement high byte (0x04)
    2 => x"723F7F",  -- DE H duration low byte (0x7F)
    3 => x"723804",  -- DE H duration high byte (0x04)
    4 => x"7239E9",  -- DE V placement low byte (0xE9)
    5 => x"723A03",  -- DE V placement high byte (0x03)
    6 => x"723CDF",  -- DE V duration low byte (0xDF)
    7 => x"723D03",  -- DE V duration high byte (0x03)
    8 => x"723E10",  -- VIC 16: 1024x768p @ 60Hz
    others => x"000000"
  );
  
  -- Конфигурация для 1360x768 @ 60Hz
  constant settings_1360x768 : settings_array := (
    0 => x"723536",  -- DE H placement low byte (0x36)
    1 => x"723600",  -- DE H placement high byte (0x00)
    2 => x"7237AA",  -- DE H duration low byte (0xAA)
    3 => x"723800",  -- DE H duration high byte (0x00)
    4 => x"72391B",  -- DE V placement low byte (0x1B)
    5 => x"723A00",  -- DE V placement high byte (0x00)
    6 => x"723C00",  -- DE V duration low byte (0x00)
    7 => x"723D03",  -- DE V duration high byte (0x03)
    8 => x"723E00",  -- VIC 0 (нет стандартного VIC)
    others => x"000000"
  );
  
  signal settings_data : std_logic_vector(23 downto 0);
  signal settings_len : std_logic_vector(7 downto 0);
  
begin
  process(address, resolution)
    variable addr_int : integer;
    variable base_offset : integer;
    variable settings_offset : integer;
  begin
    addr_int := to_integer(unsigned(address));
    settings_data <= (others => '0');
    settings_len <= (others => '0');
    
    -- первые 19 команд
    if addr_int <= 19 then
      settings_data <= settings_BASE(addr_int);
      settings_len <= std_logic_vector(to_unsigned(20 + 9, 8));  -- 19 базовых + до 9 специфичных
      
    -- Специфичная часть для каждого разрешения
    else
      settings_offset := addr_int - 19;
      case resolution is
        when "00" =>  -- 640x480
          if settings_offset <= 8 then
            settings_data <= settings_640x480(settings_offset);
          end if;
          
        when "01" =>  -- 1024x768
          if settings_offset <= 8 then
            settings_data <= settings_1024x768(settings_offset);
          end if;
          
        when "10" =>  -- 1360x768
          if settings_offset <= 8 then
            settings_data <= settings_1360x768(settings_offset);
          end if;
          
        when others =>
          null;
      end case;
    end if;
  end process;
  
  data <= settings_data;
  settings_length <= settings_len;
  
end rtl;