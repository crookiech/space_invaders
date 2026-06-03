library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adv7513_setup is
  generic (
    CLK_FREQ_MHZ : integer := 50;  -- Частота системного клока в MHz
    DELAY_MS     : integer := 200   -- Задержка после сброса в ms
  );
  port (
    clk   : in std_logic;
    rst   : in std_logic;
    resolution : in std_logic_vector(1 downto 0);  -- "00":640x480, "01":1024x768, "10":1280x720
    
    -- Интерфейс с I2C контроллером
    i2c_activate     : out std_logic;
    i2c_busy         : in  std_logic;
    i2c_address      : out std_logic_vector(6 downto 0);
    i2c_readnotwrite : out std_logic;
    i2c_byte1        : out std_logic_vector(7 downto 0);
    i2c_byte2        : out std_logic_vector(7 downto 0);
    
    -- Сигналы состояния
    active : out std_logic;
    done   : out std_logic;
    
    -- Отладочные сигналы
    debug_state : out std_logic_vector(2 downto 0)
  );
end adv7513_setup;

architecture rtl of adv7513_setup is
  -- Константы
  constant DELAY_CYCLES : integer := CLK_FREQ_MHZ * DELAY_MS * 1000;
  
  -- Тип состояния
  type state_type is (S_RESET, S_WAIT, S_SEND, S_BUSYWAIT, S_DONE);
  signal state : state_type := S_RESET;
  
  -- Сигналы
  signal rom_step    : unsigned(7 downto 0) := (others => '0');
  signal rom_length  : std_logic_vector(7 downto 0);
  signal rom_data    : std_logic_vector(23 downto 0);
  signal delay_cnt   : unsigned(31 downto 0) := (others => '0');
  signal busy_seen   : std_logic := '0';
  signal active_int  : std_logic := '0';
  signal done_int    : std_logic := '0';
  
  -- Компонент ROM с поддержкой разрешений
  component setup_rom is
    port (
      address    : in  std_logic_vector(7 downto 0);
      resolution : in  std_logic_vector(1 downto 0);
      data       : out std_logic_vector(23 downto 0);
      rom_length : out std_logic_vector(7 downto 0)
    );
  end component;
  
begin
  -- Инстанцирование ROM
  rom_inst: setup_rom
    port map (
      address    => std_logic_vector(rom_step),
      resolution => resolution,
      data       => rom_data,
      rom_length => rom_length
    );
  
  -- Выходные сигналы
  active <= active_int;
  done   <= done_int;
  debug_state <= std_logic_vector(to_unsigned(state_type'pos(state), 3));
  
  -- Основной процесс
  process(clk, rst)
  begin
    if rst = '1' then
      state <= S_RESET;
      active_int <= '0';
      done_int <= '0';
      rom_step <= (others => '0');
      delay_cnt <= (others => '0');
      busy_seen <= '0';
      i2c_activate <= '0';
      
    elsif rising_edge(clk) then
      case state is
        
        when S_RESET =>
          rom_step <= (others => '0');
          delay_cnt <= (others => '0');
          state <= S_WAIT;
          i2c_activate <= '0';
          busy_seen <= '0';
          active_int <= '1';
          done_int <= '0';
        
        when S_WAIT =>
          if delay_cnt >= to_unsigned(DELAY_CYCLES - 1, 32) then
            state <= S_SEND;
            busy_seen <= '0';
            rom_step <= (others => '0');
            delay_cnt <= (others => '0');
          else
            delay_cnt <= delay_cnt + 1;
            i2c_activate <= '0';
            busy_seen <= '0';
          end if;
        
        when S_SEND =>
          if rom_step = unsigned(rom_length) then
            state <= S_DONE;
          else
            busy_seen <= '0';
            state <= S_BUSYWAIT;
            i2c_activate <= '1';
            -- Распаковка данных: [23:17] = address, [16] = rw, [15:8] = byte1, [7:0] = byte2
            i2c_address <= rom_data(23 downto 17);
            i2c_readnotwrite <= rom_data(16);
            i2c_byte1 <= rom_data(15 downto 8);
            i2c_byte2 <= rom_data(7 downto 0);
          end if;
        
        when S_BUSYWAIT =>
          if busy_seen = '0' then
            if i2c_busy = '1' then
              busy_seen <= '1';
              i2c_activate <= '0';
              rom_step <= rom_step + 1;
            end if;
          elsif i2c_busy = '0' then
            busy_seen <= '0';
            i2c_activate <= '0';
            state <= S_SEND;
          end if;
        
        when S_DONE =>
          active_int <= '0';
          done_int <= '1';
          i2c_activate <= '0';
        
        when others =>
          state <= S_RESET;
          
      end case;
    end if;
  end process;
  
end rtl;