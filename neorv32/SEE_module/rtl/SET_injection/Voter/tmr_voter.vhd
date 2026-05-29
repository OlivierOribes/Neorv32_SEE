-- =============================================================================
-- File        : tmr_voter.vhd
-- Project     : NEORV32 - Space Radiation Mitigation
-- Description : Spatial TMR wrapper around a generic module
--
-- Strategy:
--   - Full top level module triplication in neorv32, not here
--   - Results are voted immediately
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library neorv32;
use neorv32.neorv32_package.all;

entity tmr_voter is
  generic(
    DATA_LENGTH : positive
  );
  port (
    -- Module 1 output -> inputs to voter
    y_1  : in  std_ulogic_vector(DATA_LENGTH-1 downto 0);

    -- Module 2 output -> inputs to voter
    y_2  : in  std_ulogic_vector(DATA_LENGTH-1 downto 0);

    -- Module 3 output -> inputs to voter
    y_3  : in  std_ulogic_vector(DATA_LENGTH-1 downto 0);

    -- Voted outputs
    y        : out std_ulogic_vector(DATA_LENGTH-1 downto 0)
    --err_o    : out std_ulogic
  );
end entity;


architecture rtl of tmr_voter is
begin
  y    <= (y_1 and y_2) or (y_1 and y_3) or (y_2 and y_3);
  --err_o   <= '1' when (y_1 /= y_2) or (y_1 /= y_3) or (y_2 /= y_3)
              --else '0';
end architecture rtl;