-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║            NEORV32 — Space Radiation Mitigation (SEE/SET)                    ║
-- ╠══════════════════════════════════════════════════════════════════════════════╣
-- ║  File        : tmr_neorv32_cpu_voter.vhd                                     ║
-- ║  Author      : Teresa Bäurle                                                 ║
-- ║  Date        : 2026-05-28                                                    ║
-- ║  Project     : NEORV32 — Triple Modular Redundancy (TMR) Voter               ║
-- ╠══════════════════════════════════════════════════════════════════════════════╣
-- ║  Description                                                                 ║
-- ║  ───────────                                                                 ║
-- ║  Majority voter for the three replicated NEORV32 CPU ALUs.                   ║ 
-- ║  ALU triplication is performed at the neorv32_cpu top level; this module     ║
-- ║  only receives the three result buses and produces the voted output.         ║
-- ╠══════════════════════════════════════════════════════════════════════════════╣
-- ║  Strategy                                                                    ║
-- ║  ────────                                                                    ║ 
-- ║  • Full spatial TMR: ALUs A, B, C are instantiated in neorv32_cpu            ║
-- ║  • Bit-wise majority vote applied on every output signal                     ║
-- ║  • Single-bit error flag (err_o) raised on any disagreement                  ║
-- ╠══════════════════════════════════════════════════════════════════════════════╣
-- ║  Voted Signals          Width   Description                                  ║
-- ║  ──────────────────────────────────────────────────────────────────────      ║
-- ║  res_o                  32-bit  ALU result                                   ║
-- ║  add_o                  32-bit  Adder result                                 ║
-- ║  cmp_o                   2-bit  Comparator flags                             ║
-- ║  err_o                   1-bit  SEU/SET error detected                       ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library neorv32;
use neorv32.neorv32_package.all;

entity tmr_neorv32_alu_voter is
  generic (
    DATA_LENGTH : integer := 32
  );
  port (
    -- ALU A outputs -> inputs to voter
    res_a_i  : in  std_ulogic_vector(DATA_LENGTH-1 downto 0);
    add_a_i  : in  std_ulogic_vector(DATA_LENGTH-1 downto 0);
    cmp_a_i  : in  std_ulogic_vector(1 downto 0);

    -- ALU B outputs -> inputs to voter
    res_b_i  : in  std_ulogic_vector(DATA_LENGTH-1 downto 0);
    add_b_i  : in  std_ulogic_vector(DATA_LENGTH-1 downto 0);
    cmp_b_i  : in  std_ulogic_vector(1 downto 0);
    -- ALU C outputs -> inputs to voter
    res_c_i  : in  std_ulogic_vector(DATA_LENGTH-1 downto 0);
    add_c_i  : in  std_ulogic_vector(DATA_LENGTH-1 downto 0);
    cmp_c_i  : in  std_ulogic_vector(1 downto 0);
    -- Voted outputs
    res_o    : out std_ulogic_vector(DATA_LENGTH-1 downto 0);
    add_o    : out std_ulogic_vector(DATA_LENGTH-1 downto 0);
    cmp_o    : out std_ulogic_vector(1 downto 0);
    err_o    : out std_ulogic
  );
end entity;


architecture rtl of tmr_neorv32_alu_voter is

begin

  res_o   <= (res_a_i and res_b_i) or (res_a_i and res_c_i) or (res_b_i and res_c_i);
  add_o   <= (add_a_i and add_b_i) or (add_a_i and add_c_i) or (add_b_i and add_c_i);
  cmp_o   <= (cmp_a_i and cmp_b_i) or (cmp_a_i and cmp_c_i) or (cmp_b_i and cmp_c_i);

  err_o   <= '1' when ((res_a_i /= res_b_i) and (res_a_i /= res_c_i)) or ((add_a_i /= add_b_i) and (add_a_i /= add_c_i))
              or ((cmp_a_i /= cmp_b_i) and (cmp_a_i /= cmp_c_i)) else '0';

end architecture rtl;
