library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spaceInvadersSync is
    port(
        pixel_clk : in  std_logic;
        reset_n : in  std_logic;
        resolution : in  std_logic_vector(1 downto 0);  -- "00":640x480, "01":1024x768, "10":1360x768

        hsync : out std_logic;
        vsync : out std_logic;
        de : out std_logic;

        pixel_x : out unsigned(10 downto 0);  -- 11 бит для 1360
        pixel_y : out unsigned(9 downto 0);   -- 10 бит для 768

        frame_tick : out std_logic
    );
end spaceInvadersSync;

architecture rtl of spaceInvadersSync is
    constant H_VISIBLE_640 : integer := 640;
    constant H_FRONT_PORCH_640 : integer := 16;
    constant H_SYNC_PULSE_640 : integer := 96;
    constant H_BACK_PORCH_640 : integer := 48;
    constant H_TOTAL_640 : integer := 800;

    constant V_VISIBLE_640 : integer := 480;
    constant V_FRONT_PORCH_640 : integer := 10;
    constant V_SYNC_PULSE_640 : integer := 2;
    constant V_BACK_PORCH_640 : integer := 33;
    constant V_TOTAL_640 : integer := 525;

    constant H_VISIBLE_1024 : integer := 1024;
    constant H_FRONT_PORCH_1024 : integer := 24;
    constant H_SYNC_PULSE_1024 : integer := 136;
    constant H_BACK_PORCH_1024 : integer := 160;
    constant H_TOTAL_1024 : integer := 1344;

    constant V_VISIBLE_1024 : integer := 768;
    constant V_FRONT_PORCH_1024 : integer := 3;
    constant V_SYNC_PULSE_1024 : integer := 6;
    constant V_BACK_PORCH_1024 : integer := 29;
    constant V_TOTAL_1024 : integer := 806;

    constant H_VISIBLE_1360 : integer := 1360;
    constant H_FRONT_PORCH_1360 : integer := 64;
    constant H_SYNC_PULSE_1360 : integer := 112;
    constant H_BACK_PORCH_1360 : integer := 256;
    constant H_TOTAL_1360 : integer := 1792;

    constant V_VISIBLE_1360 : integer := 768;
    constant V_FRONT_PORCH_1360 : integer := 3;
    constant V_SYNC_PULSE_1360 : integer := 6;
    constant V_BACK_PORCH_1360 : integer := 18;
    constant V_TOTAL_1360 : integer := 795;

    signal H_VISIBLE_reg : integer := H_VISIBLE_640;
    signal H_FRONT_PORCH_reg : integer := H_FRONT_PORCH_640;
    signal H_SYNC_PULSE_reg : integer := H_SYNC_PULSE_640;
    signal H_BACK_PORCH_reg : integer := H_BACK_PORCH_640;
    signal H_TOTAL_reg : integer := H_TOTAL_640;
    
    signal V_VISIBLE_reg : integer := V_VISIBLE_640;
    signal V_FRONT_PORCH_reg : integer := V_FRONT_PORCH_640;
    signal V_SYNC_PULSE_reg : integer := V_SYNC_PULSE_640;
    signal V_BACK_PORCH_reg : integer := V_BACK_PORCH_640;
    signal V_TOTAL_reg : integer := V_TOTAL_640;
    
    signal hsync_pol_reg : std_logic := '0'; 
    signal vsync_pol_reg : std_logic := '0';

    signal h_count : unsigned(10 downto 0) := (others => '0');  
    signal v_count : unsigned(9 downto 0) := (others => '0');  

    signal hsync_i : std_logic;
    signal vsync_i : std_logic;
    signal de_i : std_logic;

begin
    process(resolution)
    begin
        case resolution is
            when "00" =>  -- 640x480
                H_VISIBLE_reg <= H_VISIBLE_640;
                H_FRONT_PORCH_reg <= H_FRONT_PORCH_640;
                H_SYNC_PULSE_reg <= H_SYNC_PULSE_640;
                H_BACK_PORCH_reg <= H_BACK_PORCH_640;
                H_TOTAL_reg <= H_TOTAL_640;
                
                V_VISIBLE_reg <= V_VISIBLE_640;
                V_FRONT_PORCH_reg <= V_FRONT_PORCH_640;
                V_SYNC_PULSE_reg <= V_SYNC_PULSE_640;
                V_BACK_PORCH_reg <= V_BACK_PORCH_640;
                V_TOTAL_reg <= V_TOTAL_640;
                
                hsync_pol_reg <= '0';  
                vsync_pol_reg <= '0';
                
            when "01" =>  -- 1024x768
                H_VISIBLE_reg <= H_VISIBLE_1024;
                H_FRONT_PORCH_reg <= H_FRONT_PORCH_1024;
                H_SYNC_PULSE_reg <= H_SYNC_PULSE_1024;
                H_BACK_PORCH_reg <= H_BACK_PORCH_1024;
                H_TOTAL_reg <= H_TOTAL_1024;
                
                V_VISIBLE_reg <= V_VISIBLE_1024;
                V_FRONT_PORCH_reg <= V_FRONT_PORCH_1024;
                V_SYNC_PULSE_reg <= V_SYNC_PULSE_1024;
                V_BACK_PORCH_reg <= V_BACK_PORCH_1024;
                V_TOTAL_reg <= V_TOTAL_1024;
                
                hsync_pol_reg <= '0';  
                vsync_pol_reg <= '0';
                
            when "10" =>  -- 1360x768
                H_VISIBLE_reg <= H_VISIBLE_1360;
                H_FRONT_PORCH_reg <= H_FRONT_PORCH_1360;
                H_SYNC_PULSE_reg <= H_SYNC_PULSE_1360;
                H_BACK_PORCH_reg <= H_BACK_PORCH_1360;
                H_TOTAL_reg <= H_TOTAL_1360;
                
                V_VISIBLE_reg <= V_VISIBLE_1360;
                V_FRONT_PORCH_reg <= V_FRONT_PORCH_1360;
                V_SYNC_PULSE_reg <= V_SYNC_PULSE_1360;
                V_BACK_PORCH_reg <= V_BACK_PORCH_1360;
                V_TOTAL_reg <= V_TOTAL_1360;
                
                hsync_pol_reg <= '1'; 
                vsync_pol_reg <= '1';
                
            when others =>
                H_VISIBLE_reg <= H_VISIBLE_640;
                H_FRONT_PORCH_reg <= H_FRONT_PORCH_640;
                H_SYNC_PULSE_reg <= H_SYNC_PULSE_640;
                H_BACK_PORCH_reg <= H_BACK_PORCH_640;
                H_TOTAL_reg <= H_TOTAL_640;
                
                V_VISIBLE_reg <= V_VISIBLE_640;
                V_FRONT_PORCH_reg <= V_FRONT_PORCH_640;
                V_SYNC_PULSE_reg <= V_SYNC_PULSE_640;
                V_BACK_PORCH_reg <= V_BACK_PORCH_640;
                V_TOTAL_reg <= V_TOTAL_640;
                
                hsync_pol_reg <= '0';
                vsync_pol_reg <= '0';
        end case;
    end process;

    process(pixel_clk, reset_n)
    begin
        if reset_n = '0' then
            h_count <= (others => '0');
            v_count <= (others => '0');
        elsif rising_edge(pixel_clk) then
            if h_count = H_TOTAL_reg - 1 then
                h_count <= (others => '0');
                if v_count = V_TOTAL_reg - 1 then
                    v_count <= (others => '0');
                else
                    v_count <= v_count + 1;
                end if;
            else
                h_count <= h_count + 1;
            end if;
        end if;
    end process;

    process(pixel_clk)
    begin
        if rising_edge(pixel_clk) then
            if (to_integer(h_count) >= (H_VISIBLE_reg + H_FRONT_PORCH_reg) and
                to_integer(h_count) <  (H_VISIBLE_reg + H_FRONT_PORCH_reg + H_SYNC_PULSE_reg)) then
                hsync_i <= hsync_pol_reg;  
            else
                hsync_i <= not hsync_pol_reg;  
            end if;
        end if;
    end process;
	 
    process(pixel_clk)
    begin
        if rising_edge(pixel_clk) then
            if (to_integer(v_count) >= (V_VISIBLE_reg + V_FRONT_PORCH_reg) and
                to_integer(v_count) <  (V_VISIBLE_reg + V_FRONT_PORCH_reg + V_SYNC_PULSE_reg)) then
                vsync_i <= vsync_pol_reg; 
            else
                vsync_i <= not vsync_pol_reg;  
            end if;
        end if;
    end process;

    de_i <= '1' when (to_integer(h_count) < H_VISIBLE_reg and to_integer(v_count) < V_VISIBLE_reg) else '0';

    hsync <= hsync_i;
    vsync <= vsync_i;
    de <= de_i;

    pixel_x <= h_count;
    pixel_y <= v_count;

    frame_tick <= '1' when (h_count = 0 and v_count = 0) else '0';

end rtl;