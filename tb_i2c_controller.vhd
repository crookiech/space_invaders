library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_i2c_controller is
end tb_i2c_controller;

architecture sim of tb_i2c_controller is
    -- Константы
    constant CLK_PERIOD : time := 20 ns; 
    constant CLK_DIV    : integer := 4;   
    
    -- Сигналы тестбенча
    signal clk      : std_logic := '0';
    signal reset    : std_logic := '1';
    
    -- Сигналы для i2ciobuf
    signal i2c_scl  : std_logic := 'H';
    signal i2c_sda  : std_logic := 'H';
    
    -- Сигналы для подключения к I2C_CONTROLLER
    signal i2c_scl_i : std_logic;
    signal i2c_scl_o : std_logic;
    signal i2c_scl_e : std_logic;
    signal i2c_sda_i : std_logic;
    signal i2c_sda_o : std_logic;
    signal i2c_sda_e : std_logic;
    
    signal busy     : std_logic;
    signal abort_s  : std_logic;
    signal success  : std_logic;
    signal activate : std_logic := '0';
    signal read_cmd : std_logic := '0';
    signal address  : std_logic_vector(6 downto 0) := (others => '0');
    signal location : std_logic_vector(7 downto 0) := (others => '0');
    signal data_wr  : std_logic_vector(7 downto 0) := (others => '0');
    signal start_pulse : std_logic;
    signal stop_pulse  : std_logic;
    signal got_ack     : std_logic;
    
    -- Модель ведомого устройства
    signal slave_sda_out : std_logic := 'H';
    
begin
    clk <= not clk after CLK_PERIOD/2;
    
    -- Сброс
    process
    begin
        reset <= '1';
        wait for 100 ns;
        reset <= '0';
        wait;
    end process;
    
    scl_buf: entity work.i2ciobuf
        port map(
            datain(0) => i2c_scl_o,
            oe(0)     => i2c_scl_e,
            dataio(0) => i2c_scl,
            dataout(0) => i2c_scl_i
        );
    
    sda_buf: entity work.i2ciobuf
        port map(
            datain(0) => i2c_sda_o,
            oe(0)     => i2c_sda_e,
            dataio(0) => i2c_sda,
            dataout(0) => i2c_sda_i
        );
    
    dut: entity work.I2C_CONTROLLER
        generic map (CLK_DIV => CLK_DIV)
        port map (
            clk => clk,
            reset => reset,
            scl_i => i2c_scl_i,
            scl_o => i2c_scl_o,
            scl_e => i2c_scl_e,
            sda_i => i2c_sda_i,
            sda_o => i2c_sda_o,
            sda_e => i2c_sda_e,
            busy => busy,
            abort => abort_s,
            success => success,
            activate => activate,
            read => read_cmd,
            address => address,
            location => location,
            data => data_wr,
            start_pulse => start_pulse,
            stop_pulse => stop_pulse,
            got_ack => got_ack
        );
    
    -- Управление линией SDA от ведомого
    i2c_sda <= '0' when slave_sda_out = '0' else 'H';
    
    process(i2c_scl, i2c_sda)
        variable state : integer := 0;
        variable bit_cnt : integer := 0;
        variable byte_cnt : integer := 0;
        variable addr_recv : std_logic_vector(7 downto 0);
    begin
        -- Детектируем передний фронт SCL
        if rising_edge(i2c_scl) then
            case state is
                when 0 => -- IDLE - ждём START
                    if i2c_sda = '0' then
                        state := 1;
                        bit_cnt := 0;
                        byte_cnt := 0;
                        slave_sda_out <= 'H';
                    end if;
                
                when 1 => -- Получение адреса
                    addr_recv(7 - bit_cnt) := i2c_sda;
                    bit_cnt := bit_cnt + 1;
                    if bit_cnt = 8 then
                        bit_cnt := 0;
                        state := 2;
                        -- Проверяем адрес 0x72
                        if addr_recv(7 downto 1) = "1110010" then
                            slave_sda_out <= '0';  -- ACK
                        else
                            slave_sda_out <= 'H';  -- NACK
                            state := 0;
                        end if;
                    end if;
                
                when 2 => -- Получение регистра
                    bit_cnt := bit_cnt + 1;
                    if bit_cnt = 8 then
                        bit_cnt := 0;
                        state := 3;
                        slave_sda_out <= '0';  -- ACK for register
                    end if;
                
                when 3 => -- Получение данных
                    bit_cnt := bit_cnt + 1;
                    if bit_cnt = 8 then
                        state := 0;
                        slave_sda_out <= 'H';
                    end if;
                
                when others =>
                    state := 0;
            end case;
        end if;
        
        -- Детектируем STOP
        if i2c_scl = '1' and i2c_sda'event and i2c_sda = '1' then
            state := 0;
            slave_sda_out <= 'H';
        end if;
    end process;
    
    test_process: process
    begin
        wait until reset = '0';
        wait for 1 us;
        
        
        address <= "1110010";
        read_cmd <= '0';
        location <= x"41";
        data_wr <= x"10";
        
        activate <= '1';
        wait for CLK_PERIOD * 2;
        activate <= '0';
        
        wait until busy = '0';
        wait for 100 ns;
       
        
        address <= "1110010";
        read_cmd <= '0';
        location <= x"42";
        data_wr <= x"10";
        
        activate <= '1';
        wait for CLK_PERIOD * 2;
        activate <= '0';
        
        wait until busy = '0';
        wait for 100 ns;
        wait;
    end process;
    
end architecture;