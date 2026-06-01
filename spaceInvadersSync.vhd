library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spaceInvadersSync is
    port(
        pixel_clk  : in  std_logic;
        reset_n    : in  std_logic;

        hsync      : out std_logic;
        vsync      : out std_logic;
        de         : out std_logic;

        pixel_x    : out unsigned(9 downto 0);
        pixel_y    : out unsigned(9 downto 0);

        frame_tick : out std_logic
    );
end spaceInvadersSync;

architecture rtl of spaceInvadersSync is

    --------------------------------------------------------------------
    -- 640x480 @ 60Hz timing
    --------------------------------------------------------------------

    constant H_VISIBLE      : integer := 640;
    constant H_FRONT_PORCH  : integer := 16;
    constant H_SYNC_PULSE   : integer := 96;
    constant H_BACK_PORCH   : integer := 48;
    constant H_TOTAL        : integer := 800;

    constant V_VISIBLE      : integer := 480;
    constant V_FRONT_PORCH  : integer := 10;
    constant V_SYNC_PULSE   : integer := 2;
    constant V_BACK_PORCH   : integer := 33;
    constant V_TOTAL        : integer := 525;

    --------------------------------------------------------------------

    signal h_count : unsigned(9 downto 0) := (others => '0');
    signal v_count : unsigned(9 downto 0) := (others => '0');

    signal hsync_i : std_logic;
    signal vsync_i : std_logic;
    signal de_i    : std_logic;

begin

    --------------------------------------------------------------------
    -- Horizontal / Vertical counters
    --------------------------------------------------------------------

    process(pixel_clk, reset_n)
    begin
        if reset_n = '0' then

            h_count <= (others => '0');
            v_count <= (others => '0');

        elsif rising_edge(pixel_clk) then

            if h_count = H_TOTAL - 1 then

                h_count <= (others => '0');

                if v_count = V_TOTAL - 1 then
                    v_count <= (others => '0');
                else
                    v_count <= v_count + 1;
                end if;

            else
                h_count <= h_count + 1;
            end if;

        end if;
    end process;

    --------------------------------------------------------------------
    -- HSYNC
    -- Active LOW
    --------------------------------------------------------------------

    hsync_i <= '0' when (
                    to_integer(h_count) >= (H_VISIBLE + H_FRONT_PORCH) and
                    to_integer(h_count) <  (H_VISIBLE + H_FRONT_PORCH + H_SYNC_PULSE)
               )
               else '1';

    --------------------------------------------------------------------
    -- VSYNC
    -- Active LOW
    --------------------------------------------------------------------

    vsync_i <= '0' when (
                    to_integer(v_count) >= (V_VISIBLE + V_FRONT_PORCH) and
                    to_integer(v_count) <  (V_VISIBLE + V_FRONT_PORCH + V_SYNC_PULSE)
               )
               else '1';

    --------------------------------------------------------------------
    -- Data Enable (visible area)
    --------------------------------------------------------------------

    de_i <= '1' when (
                to_integer(h_count) < H_VISIBLE and
                to_integer(v_count) < V_VISIBLE
            )
            else '0';

    --------------------------------------------------------------------
    -- Outputs
    --------------------------------------------------------------------

    hsync <= hsync_i;
    vsync <= vsync_i;
    de    <= de_i;

    pixel_x <= h_count;
    pixel_y <= v_count;

    --------------------------------------------------------------------
    -- Frame tick
    -- One pulse per frame
    --------------------------------------------------------------------

    frame_tick <= '1' when (
                        h_count = 0 and
                        v_count = 0
                    )
                    else '0';

end rtl;