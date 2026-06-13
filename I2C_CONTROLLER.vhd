library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity I2C_CONTROLLER is
  generic (
    CLK_DIV : positive := 32
  );
  port (
    scl_i : in  std_logic;
    scl_o : out std_logic;
    scl_e : out std_logic;
    
    sda_i : in  std_logic;
    sda_o : out std_logic;
    sda_e : out std_logic;
    
    busy    : out std_logic;
    abort   : out std_logic;
    success : out std_logic;
    
    activate    : in  std_logic;
    read        : in  std_logic;
    address     : in  std_logic_vector(6 downto 0);
    location    : in  std_logic_vector(7 downto 0);
    data        : in  std_logic_vector(7 downto 0);
    
    clk   : in  std_logic;
    reset : in  std_logic;
    
    start_pulse : out std_logic;
    stop_pulse  : out std_logic;
    got_ack     : out std_logic
  );
end I2C_CONTROLLER;

architecture rtl of I2C_CONTROLLER is
  constant CLK_CNT_SZ : integer := integer(ceil(log2(real(CLK_DIV))));
  constant CLK_CNT_MAX : std_logic_vector(CLK_CNT_SZ-1 downto 0) := 
    std_logic_vector(to_unsigned(CLK_DIV - 1, CLK_CNT_SZ));
  
  type state_type is (S_POWERON, S_RESET, S_IDLE, S_START, S_ADDRESS, S_DATA1, S_DATA2, S_STOP);
  signal state : state_type := S_RESET;
  
  signal clk_div_cnt : unsigned(CLK_CNT_SZ-1 downto 0) := (others => '0');
  signal step        : integer range 0 to 3 := 0;
  signal byte_step   : integer range 0 to 15 := 0;
  signal byte_idx    : integer range 0 to 7 := 7;
  signal poweron_counter : integer range 0 to 15 := 0;
  
  signal is_write   : std_logic;
  signal k_address  : std_logic_vector(7 downto 0);
  signal k_location : std_logic_vector(7 downto 0);
  signal k_data     : std_logic_vector(7 downto 0);
  
  signal got_ack_int : std_logic;
  
begin
  got_ack <= got_ack_int;
  
  process(clk, reset)
    variable clk_div_cnt_next : unsigned(CLK_CNT_SZ-1 downto 0);
  begin
  if rising_edge(clk) then
    if reset = '1' then
      state <= S_RESET;
      clk_div_cnt <= (others => '0');
      sda_e <= '0';
      scl_e <= '0';
      scl_o <= '0';
      sda_o <= '0';
      busy <= '0';
      abort <= '0';
      success <= '0';
      start_pulse <= '0';
      stop_pulse <= '0';
      got_ack_int <= '0';
      
      if clk_div_cnt = 0 then
        clk_div_cnt <= (others => '1');
      else
        clk_div_cnt <= clk_div_cnt - 1;
      end if;
      
      if clk_div_cnt = 0 then
        case state is
          when S_RESET =>
            poweron_counter <= 0;
            busy <= '1';
            abort <= '0';
            success <= '0';
            sda_e <= '0';
            scl_e <= '0';
            state <= S_POWERON;
          
          when S_POWERON =>
            if poweron_counter = 15 then
              state <= S_IDLE;
              busy <= '0';
              poweron_counter <= 0;
            else
              busy <= '1';
              poweron_counter <= poweron_counter + 1;
            end if;
          
          when S_IDLE =>
            if activate = '1' then
              k_address(7 downto 1) <= address;
              k_address(0) <= read;
              k_location <= location;
              k_data <= data;
              state <= S_START;
              step <= 0;
              start_pulse <= '1';
              stop_pulse <= '0';
              busy <= '1';
              sda_e <= '1';
              sda_o <= '0';
              scl_e <= '1';
              scl_o <= '0';
            else
              busy <= '0';
              scl_e <= '0';
              sda_e <= '0';
              start_pulse <= '0';
              stop_pulse <= '0';
            end if;
          
          when S_START =>
            case step is
              when 0 =>
                scl_e <= '1';
                scl_o <= '0';
                sda_e <= '1';
                sda_o <= '1';
                start_pulse <= '0';
                step <= 1;
              
              when 1 =>
                scl_o <= '1';
                step <= 2;
              
              when 2 =>
                sda_o <= '0';
                step <= 3;
              
              when 3 =>
                scl_o <= '0';
                step <= 0;
                state <= S_ADDRESS;
                byte_step <= 0;
                byte_idx <= 7;
              
              when others =>
                step <= 0;
            end case;
          
          when S_ADDRESS | S_DATA1 | S_DATA2 =>
            is_write <= '1';
            
            if byte_step = 8 then
              case step is
                when 0 =>
                  scl_e <= '1';
                  scl_o <= '0';
                  sda_e <= '0';
                  got_ack_int <= '0';
                  step <= 1;
                
                when 1 =>
                  scl_o <= '1';
                  step <= 2;
                
                when 2 =>
                  got_ack_int <= not sda_i;
                  step <= 3;
                
                when 3 =>
                  got_ack_int <= got_ack_int or (not sda_i);
                  scl_o <= '0';
                  
                  if sda_i = '0' then
                    sda_o <= '0';
                  elsif got_ack_int = '1' then
                    sda_o <= '0';
                  else
                    sda_o <= '1';
                  end if;
                  
                  step <= 0;
                
                when others =>
                  step <= 0;
              end case;
            else
              got_ack_int <= '0';
              
              if is_write = '1' then
                case step is
                  when 0 =>
                    scl_e <= '1';
                    scl_o <= '0';
                    sda_e <= '1';
                    
                    if state = S_ADDRESS then
                      sda_o <= k_address(byte_idx);
                    elsif state = S_DATA1 then
                      sda_o <= k_location(byte_idx);
                    else
                      sda_o <= k_data(byte_idx);
                    end if;
                    
                    step <= 1;
                  
                  when 1 =>
                    scl_o <= '1';
                    step <= 2;
                  
                  when 2 =>
                    -- Wait
                    step <= 3;
                  
                  when 3 =>
                    scl_o <= '0';
                    step <= 0;
                  
                  when others =>
                    step <= 0;
                end case;
              end if;
            end if;
            if byte_step = 8 and step = 0 then
              if state = S_DATA2 then
                  state <= S_STOP;
                
              else
                if state = S_ADDRESS then
                  state <= S_DATA1;
                else
                  state <= S_DATA2;
                end if;
                byte_step <= 0;
                byte_idx <= 7;
              end if;
            elsif step = 0 then
              byte_step <= byte_step + 1;
              if byte_idx = 0 then
                byte_idx <= 7;
              else
                byte_idx <= byte_idx - 1;
              end if;
            end if;
          
          when S_STOP =>
            case step is
              when 0 =>
                scl_e <= '1';
                scl_o <= '0';
                sda_e <= '1';
                sda_o <= '0';
                step <= 1;
              
              when 1 =>
                scl_o <= '1';
                step <= 2;
              
              when 2 =>
                sda_o <= '1';
                step <= 3;
              
              when 3 =>
                scl_o <= '0';
                step <= 0;
                state <= S_IDLE;
                stop_pulse <= '1';
              
              when others =>
                step <= 0;
            end case;
          
          when others =>
            state <= S_RESET;
        end case;
      end if;
    end if;
	 end if;
  end process;
end rtl;