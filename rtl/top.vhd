library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top is
    port (
        clk    : in  std_logic;
        btn_in : in  std_logic;
        led    : out std_logic_vector(5 downto 0)
    );
end top;

architecture rtl of top is
    constant WAIT_TIME : integer := 13500000;
    signal ledCounter : unsigned(5 downto 0) := (others => '0');
    signal clockCounter : unsigned(23 downto 0) := (others => '0');
    signal debounced_btn : std_logic;

    component debounce is
        port (
            clk     : in  std_logic;
            btn_in  : in  std_logic;
            btn_out : out std_logic
        );
    end component;
begin
    u_debounce: debounce
        port map (
            clk     => clk,
            btn_in  => btn_in,
            btn_out => debounced_btn
        );

    process(clk)
    begin
        if rising_edge(clk) then
            if debounced_btn = '1' then
                clockCounter <= clockCounter + 1;
                if clockCounter = WAIT_TIME then
                    clockCounter <= (others => '0');
                    ledCounter <= ledCounter + 1;
                end if;
            end if;
        end if;
    end process;

    led <= std_logic_vector(not ledCounter);
end rtl;
