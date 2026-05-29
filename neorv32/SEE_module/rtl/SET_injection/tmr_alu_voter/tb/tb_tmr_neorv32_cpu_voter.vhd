-- =============================================================================
-- File        : tb_tmr_neorv32_alu_voter.vhd
-- Project     : NEORV32 - Space Radiation Mitigation
-- Description : Testbench for the spatial TMR voter component
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library neorv32;
use neorv32.neorv32_package.all;

entity tb_tmr_neorv32_alu_voter is
-- Testbenches do not have ports
end entity;

architecture tb of tb_tmr_neorv32_alu_voter is

  -- Stimuli signals (initialized with default values)
  signal res_a, res_b, res_c : std_ulogic_vector(DATA_LENGTH-1 downto 0) := (others => '0');
  signal add_a, add_b, add_c : std_ulogic_vector(DATA_LENGTH-1 downto 0) := (others => '0');
  signal csr_a, csr_b, csr_c : std_ulogic_vector(DATA_LENGTH-1 downto 0) := (others => '0');
  signal cmp_a, cmp_b, cmp_c : std_ulogic_vector(1 downto 0)      := (others => '0');
  signal done_a, done_b, done_c : std_ulogic                      := '0';

  -- Monitoring signals
  signal res_voted  : std_ulogic_vector(DATA_LENGTH-1 downto 0);
  signal add_voted  : std_ulogic_vector(DATA_LENGTH-1 downto 0);
  signal csr_voted  : std_ulogic_vector(DATA_LENGTH-1 downto 0);
  signal cmp_voted  : std_ulogic_vector(1 downto 0);
  signal done_voted : std_ulogic;
  signal err_voted  : std_ulogic;

  -- Constants for test patterns
  constant TEST_VAL_1 : std_ulogic_vector(DATA_LENGTH-1 downto 0) := x"12345678";
  constant TEST_VAL_2 : std_ulogic_vector(DATA_LENGTH-1 downto 0) := x"A5A5A5A5";
  constant TEST_VAL_3 : std_ulogic_vector(DATA_LENGTH-1 downto 0) := x"FFFFFFFF";

begin

  -- Direct instantiation of the Voter Entity
  uut: entity work.tmr_neorv32_alu_voter
    port map (
      -- Inputs
      res_a_i  => res_a,  add_a_i  => add_a,  csr_a_i  => csr_a,  cmp_a_i  => cmp_a,  done_a_i => done_a,
      res_b_i  => res_b,  add_b_i  => add_b,  csr_b_i  => csr_b,  cmp_b_i  => cmp_b,  done_b_i => done_b,
      res_c_i  => res_c,  add_c_i  => add_c,  csr_c_i  => csr_c,  cmp_c_i  => cmp_c,  done_c_i => done_c,
      -- Outputs
      res_o    => res_voted,
      add_o    => add_voted,
      csr_o    => csr_voted,
      cmp_o    => cmp_voted,
      done_o   => done_voted,
      err_o    => err_voted
    );

  -- Main testing process
  stimuli_process: process
  begin
    report "--- STARTING VOTER TESTBENCH ---";
    wait for 10 ns;

    -- =========================================================================
    -- Scenario 1: Ideal State (All ALUs compute the exact same values)
    -- =========================================================================
    report "Scenario 1: All ALU channels are identical and fault-free.";
    
    res_a <= TEST_VAL_1; res_b <= TEST_VAL_1; res_c <= TEST_VAL_1;
    add_a <= TEST_VAL_2; add_b <= TEST_VAL_2; add_c <= TEST_VAL_2;
    csr_a <= TEST_VAL_3; csr_b <= TEST_VAL_3; csr_c <= TEST_VAL_3;
    cmp_a <= "10";       cmp_b <= "10";       cmp_c <= "10";
    done_a <= '1';       done_b <= '1';       done_c <= '1';
    
    wait for 10 ns; -- Wait for combinational logic propagation
    
    assert (res_voted = TEST_VAL_1) report "Error Scen.1: res_o mismatch" severity error;
    assert (add_voted = TEST_VAL_2) report "Error Scen.1: add_o mismatch" severity error;
    assert (csr_voted = TEST_VAL_3) report "Error Scen.1: csr_o mismatch" severity error;
    assert (cmp_voted = "10")       report "Error Scen.1: cmp_o mismatch" severity error;
    assert (done_voted = '1')       report "Error Scen.1: done_o mismatch" severity error;
    assert (err_voted = '0')        report "Error Scen.1: err_o should be '0' (False Alarm)" severity error;


    -- =========================================================================
    -- Scenario 2: Radiation Strike / SEU on Channel A
    -- =========================================================================
    report "Scenario 2: Channel A is corrupt (bit-flip). B and C hold the majority.";
    
    -- Channel A receives divergent values (e.g., cleared), B and C remain stable
    res_a <= (others => '0');
    add_a <= (others => '0');
    csr_a <= (others => '0');
    cmp_a <= "00";
    done_a <= '0';
    
    wait for 10 ns;
    
    -- The correct result must still be output thanks to B and C!
    assert (res_voted = TEST_VAL_1) report "Error Scen.2: Majority vote failed for res_o" severity error;
    assert (add_voted = TEST_VAL_2) report "Error Scen.2: Majority vote failed for add_o" severity error;
    assert (csr_voted = TEST_VAL_3) report "Error Scen.2: Majority vote failed for csr_o" severity error;
    assert (cmp_voted = "10")       report "Error Scen.2: Majority vote failed for cmp_o" severity error;
    assert (done_voted = '1')       report "Error Scen.2: Majority vote failed for done_o" severity error;
    -- The error output MUST activate now
    assert (err_voted = '1')        report "Error Scen.2: err_o failed to detect fault in Channel A!" severity error;


    -- =========================================================================
    -- Scenario 3: Radiation Strike / SEU on Channel B
    -- =========================================================================
    report "Scenario 3: Channel B is corrupt. A and C hold the majority.";
    
    -- Restore Channel A to valid state
    res_a <= TEST_VAL_1; add_a <= TEST_VAL_2; csr_a <= TEST_VAL_3; cmp_a <= "10"; done_a <= '1';
    -- Corrupt Channel B instead
    res_b <= (others => '1');
    add_b <= (others => '1');
    csr_b <= (others => '1');
    cmp_b <= "11";
    done_b <= '0';
    
    wait for 10 ns;
    
    assert (res_voted = TEST_VAL_1) report "Error Scen.3: Majority vote failed for res_o" severity error;
    assert (add_voted = TEST_VAL_2) report "Error Scen.3: Majority vote failed for add_o" severity error;
    assert (err_voted = '1')        report "Error Scen.3: err_o failed to detect fault in Channel B!" severity error;


    -- =========================================================================
    -- Scenario 4: Worst-Case Failure (All channels completely different)
    -- =========================================================================
    report "Scenario 4: All three channels are different (No majority possible).";
    
    -- Every ALU spits out completely different mismatched data
    res_a <= TEST_VAL_1; res_b <= TEST_VAL_2; res_c <= TEST_VAL_3;
    add_a <= TEST_VAL_1; add_b <= TEST_VAL_2; add_c <= TEST_VAL_3;
    csr_a <= TEST_VAL_1; csr_b <= TEST_VAL_2; csr_c <= TEST_VAL_3;
    cmp_a <= "00";       cmp_b <= "01";       cmp_c <= "11";
    done_a <= '1';       done_b <= '0';       done_c <= '1';
    
    wait for 10 ns;
    
    -- While output values are mathematically broken here due to structural failure,
    -- the critical requirement is that the error flag safely triggers!
    assert (err_voted = '1') report "Error Scen.4: err_o failed to flag total redundancy loss!" severity error;


    -- End of test
    report "--- VOTER TESTBENCH FINISHED SUCCESSFULLY ---";
    wait; -- Halt process permanently
  end process;

end architecture;