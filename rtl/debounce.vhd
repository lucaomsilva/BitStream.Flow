library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity debounce is
    generic (
        STABILITY_COUNT : integer := 20000
    );
    port (
        clk     : in  std_logic;
        btn_in  : in  std_logic;
        btn_out : out std_logic
    );
end debounce;

architecture rtl of debounce is
    signal counter : unsigned(15 downto 0) := (others => '0');
    signal internal_state : std_logic := '1';
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if btn_in /= internal_state then
                counter <= (others => '0');
                internal_state <= btn_in;
            elsif counter < STABILITY_COUNT then
                counter <= counter + 1;
            else
                btn_out <= internal_state;
            end if;
        end if;
    end process;
end rtl;
