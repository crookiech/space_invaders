library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library altera;
use altera.altera_syn_attributes.all;


entity uart_rx is
    port (
        clk : in  std_logic;
        rst : in  std_logic;
        baud_x16_pulse : in  std_logic;
        rx : in  std_logic;
        data_out : out std_logic_vector(7 downto 0);
        valid : out std_logic;
        parity_error : out std_logic;
        framing_error : out std_logic
    );
end entity;

architecture rtl of uart_rx is
    type state_type is (IDLE, START_BIT, DATA_BITS, PARITY_BIT, STOP_BIT);
    signal state : state_type := IDLE;
    signal rx_reg : std_logic_vector(7 downto 0);
    signal bit_cnt : integer range 0 to 7;
    signal ovs_cnt : integer range 0 to 15;
    signal parity_calc: std_logic;
    signal sampled_bit: std_logic;
    signal valid_int : std_logic;
    signal parity_err_int : std_logic;
    signal framing_err_int: std_logic;
begin
    data_out <= rx_reg;
    valid <= valid_int;
    parity_error  <= parity_err_int;
    framing_error <= framing_err_int;

    process(clk, rst)
        variable v_parity_err  : std_logic;
        variable v_framing_err : std_logic;
    begin
        if rst = '0' then
            state <= IDLE;
            rx_reg <= (others => '0');
            bit_cnt <= 0;
            ovs_cnt <= 0;
            parity_calc <= '0';
            valid_int <= '0';
            parity_err_int <= '0';
            framing_err_int <= '0';
            sampled_bit <= '0';

        elsif rising_edge(clk) then
            valid_int <= '0';
            parity_err_int <= '0';
            framing_err_int <= '0';
            v_parity_err  := '0';
            v_framing_err := '0';

            if baud_x16_pulse = '1' then
                case state is
                    when IDLE =>
                        if rx = '0' then
                            state <= START_BIT;
                            ovs_cnt <= 0;
                            parity_calc <= '0';
                        end if;

                    when START_BIT =>
                        if ovs_cnt = 7 then
                            sampled_bit <= rx;
                            if rx = '1' then
                                state <= IDLE;
                            end if;
                        end if;
                        
                        if ovs_cnt = 15 then
                            if sampled_bit = '0' then
                                state   <= DATA_BITS;
                                bit_cnt <= 0;
                            else
                                state <= IDLE;
                            end if;
                            ovs_cnt <= 0;
                        else
                            ovs_cnt <= ovs_cnt + 1;
                        end if;

                    when DATA_BITS =>
                        if ovs_cnt = 7 then
                            sampled_bit <= rx;
                            rx_reg(bit_cnt) <= rx;
                            parity_calc <= parity_calc xor rx;
                        end if;
                        
                        if ovs_cnt = 15 then
                            if bit_cnt = 7 then
                                state   <= PARITY_BIT;
                            else
                                bit_cnt <= bit_cnt + 1;
                            end if;
                            ovs_cnt <= 0;
                        else
                            ovs_cnt <= ovs_cnt + 1;
                        end if;

                    when PARITY_BIT =>
                        if ovs_cnt = 7 then
                            sampled_bit <= rx;
                        end if;
                        
                        if ovs_cnt = 15 then
                            if sampled_bit /= parity_calc then
                                v_parity_err := '1';
                            end if;
                            state <= STOP_BIT;
                            ovs_cnt <= 0;
                        else
                            ovs_cnt <= ovs_cnt + 1;
                        end if;

                    when STOP_BIT =>
                        if ovs_cnt = 7 then
                            sampled_bit <= rx;
                        end if;
                        
                        if ovs_cnt = 15 then
                            if sampled_bit /= '1' then
                                v_framing_err := '1';
                            end if;
                            parity_err_int  <= v_parity_err;
                            framing_err_int <= v_framing_err;
                            if v_parity_err = '0' and v_framing_err = '0' then
                                valid_int <= '1';
                            end if;
                            state <= IDLE;
                            ovs_cnt <= 0;
                        else
                            ovs_cnt <= ovs_cnt + 1;
                        end if;

                    when others =>
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process;
end architecture;
