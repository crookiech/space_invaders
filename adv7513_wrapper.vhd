LIBRARY ieee;
use ieee.std_logic_1164.all;

entity adv7513_wrapper is
    port(
        clk       : in  std_logic;
        reset_n   : in  std_logic;
        i2c_scl   : out std_logic;
        i2c_sda   : inout std_logic;
        init_done : out std_logic
    );
end adv7513_wrapper;

architecture structural of adv7513_wrapper is

    signal i2c_scl_e, i2c_scl_o : std_logic;
    signal i2c_sda_e, i2c_sda_o : std_logic;
    signal i2c_sda_i : std_logic;
    
    signal i2c_activate   : std_logic;
    signal i2c_busy       : std_logic;
    signal i2c_address    : std_logic_vector(6 downto 0);
    signal i2c_readnotwrite : std_logic;
    signal i2c_byte1      : std_logic_vector(7 downto 0);
    signal i2c_byte2      : std_logic_vector(7 downto 0);
    signal setup_done     : std_logic;
    
    -- Векторные сигналы для ALTIOBUF
    signal scl_oe_vec     : std_logic_vector(0 downto 0);
    signal scl_datain_vec : std_logic_vector(0 downto 0);
    signal scl_dataio_vec : std_logic_vector(0 downto 0);
    
    signal sda_oe_vec     : std_logic_vector(0 downto 0);
    signal sda_datain_vec : std_logic_vector(0 downto 0);
    signal sda_dataout_vec : std_logic_vector(0 downto 0);

    component I2C_CONTROLLER is
        port(
            clk         : in  std_logic;
            reset       : in  std_logic;
            scl_i       : in  std_logic;
            scl_o       : out std_logic;
            scl_e       : out std_logic;
            sda_i       : in  std_logic;
            sda_o       : out std_logic;
            sda_e       : out std_logic;
            busy        : out std_logic;
            abort       : out std_logic;
            success     : out std_logic;
            activate    : in  std_logic;
            read        : in  std_logic;
            address     : in  std_logic_vector(6 downto 0);
            location    : in  std_logic_vector(7 downto 0);
            data        : in  std_logic_vector(7 downto 0);
            data_repeat : in  std_logic_vector(2 downto 0);
            start_pulse : out std_logic;
            stop_pulse  : out std_logic;
            got_ack     : out std_logic
        );
    end component;
    
    component adv7513_setup is
        port(
            clk             : in  std_logic;
            rst             : in  std_logic;
            i2c_activate    : out std_logic;
            i2c_busy        : in  std_logic;
            i2c_address     : out std_logic_vector(6 downto 0);
            i2c_readnotwrite: out std_logic;
            i2c_byte1       : out std_logic_vector(7 downto 0);
            i2c_byte2       : out std_logic_vector(7 downto 0);
            active          : out std_logic;
            done            : out std_logic;
            is_busywait     : out std_logic;
            is_busyseen     : out std_logic
        );
    end component;
    
    component i2ciobuf is
        port(
            datain  : in  std_logic_vector(0 downto 0);
            oe      : in  std_logic_vector(0 downto 0);
            dataio  : inout std_logic_vector(0 downto 0);
            dataout : out std_logic_vector(0 downto 0)
        );
    end component;

begin

    --------------------------------------------------------------------
    -- ПОДГОТОВКА СИГНАЛОВ
    --------------------------------------------------------------------
    scl_datain_vec(0) <= i2c_scl_o;
    scl_oe_vec(0)     <= i2c_scl_e;
    
    sda_datain_vec(0) <= i2c_sda_o;
    sda_oe_vec(0)     <= i2c_sda_e;
    
    -- Читаем значение с пина
    i2c_sda_i <= sda_dataout_vec(0);
    
    -- Выход SCL
    i2c_scl <= scl_dataio_vec(0);

    --------------------------------------------------------------------
    -- SCL BUFFER
    --------------------------------------------------------------------
    scl_buf: i2ciobuf
        port map(
            datain  => scl_datain_vec,
            oe      => scl_oe_vec,
            dataio  => scl_dataio_vec,
            dataout => open
        );
    
    --------------------------------------------------------------------
    -- SDA BUFFER (ПРЯМОЕ ПОДКЛЮЧЕНИЕ К ПИНУ)
    --------------------------------------------------------------------
    sda_buf: i2ciobuf
        port map(
            datain  => sda_datain_vec,
            oe      => sda_oe_vec,
            dataio(0) => i2c_sda,
            dataout => sda_dataout_vec
        );

    --------------------------------------------------------------------
    -- I2C CONTROLLER
    --------------------------------------------------------------------
    i2c_inst: I2C_CONTROLLER
        port map(
            clk         => clk,
            reset       => not reset_n,
            scl_i       => '0',
            scl_o       => i2c_scl_o,
            scl_e       => i2c_scl_e,
            sda_i       => i2c_sda_i,
            sda_o       => i2c_sda_o,
            sda_e       => i2c_sda_e,
            busy        => i2c_busy,
            abort       => open,
            success     => open,
            activate    => i2c_activate,
            read        => i2c_readnotwrite,
            address     => i2c_address,
            location    => i2c_byte1,
            data        => i2c_byte2,
            data_repeat => "000",
            start_pulse => open,
            stop_pulse  => open,
            got_ack     => open
        );
    
    --------------------------------------------------------------------
    -- ADV7513 SETUP
    --------------------------------------------------------------------
    setup_inst: adv7513_setup
        port map(
            clk             => clk,
            rst             => not reset_n,
            i2c_activate    => i2c_activate,
            i2c_busy        => i2c_busy,
            i2c_address     => i2c_address,
            i2c_readnotwrite=> i2c_readnotwrite,
            i2c_byte1       => i2c_byte1,
            i2c_byte2       => i2c_byte2,
            active          => open,
            done            => setup_done,
            is_busywait     => open,
            is_busyseen     => open
        );
    
    --------------------------------------------------------------------
    -- INIT DONE
    --------------------------------------------------------------------
    init_done <= setup_done;

end structural;