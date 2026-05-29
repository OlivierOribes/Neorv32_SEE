-- ==============================================================================
--  Module      : Injection Fault
--  File        : injection_fault_SET.vhd
--
--  Description :
--      Fault injection block used to simulate transient faults (SET - Single
--      Event Transient) and permanent stuck-at faults in a digital system.
--
--      This module modifies an input data bus by conditionally:
--          - forcing a specific bit to a constant value (stuck-at fault)
--          - flipping one or multiple bits using a fault mask (transient fault)
--
--      fault_enable is registered internally (1-cycle pipeline) to cut the
--      critical timing path between the VIO probe and the ALU data path.
--
--  Features:
--      - Probabilistic transient fault injection using external LFSR match signal
--      - Fine-grained control via enable, trigger, and match signals
--      - Deterministic stuck-at fault on a selected bit
--      - Supports SET (transient bit-flip) and stuck-at fault models
--      - fault_enable registered on clk (1-cycle latency) for timing closure
--
--  Behavior:
--      - Default behavior: data_out = data_in (no fault)
--
--      - Fault injection is enabled one cycle after fault_enable = '1'
--
--      - Permanent fault (stuck-at):
--            If permanent_fault = '1', the selected bit is forced to the value
--            defined by stuckatvalue, regardless of its original value
--
--      - Transient fault (SET):
--            If transient_fault = '1' AND match = '1', selected bits are
--            flipped according to fault_mask for the duration of the input pulse
--
--      - Priority:
--            permanent_fault > transient_fault > normal operation
--
--  Author      : Olivier Oribes
--  Created     : 26/04/2026
--  Last update : 28/05/2026
--
--  Version     : 1.2
--
--  Project     : Neorv32_SEU
--  Language    : VHDL
--
--  Dependencies:
--      - External fault controller (LFSR + comparator generating 'match')
--
--  Generics:
--      DATA_LENGTH : Width of input/output data (must be > 0)
--
--  Ports:
--      clk              : input  - System clock (used to register fault_enable)
--      data_in          : input  - Input data bus
--      fault_enable     : input  - Global enable for fault injection (registered internally)
--      transient_fault  : input  - Trigger signal for transient fault (pulse)
--      match            : input  - LFSR-based probabilistic trigger signal
--      permanent_fault  : input  - Enable stuck-at fault
--      stuckatbit       : input  - Index of the affected bit
--      stuckatvalue     : input  - Forced value ('0' or '1') for the selected bit
--      fault_mask       : input  - Bit mask defining flipped bits (1 = flip)
--      data_out         : output - Output data (possibly faulted)
--
--  License     : MIT
-- ==============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity injection_fault is
    generic(
        DATA_LENGTH         : positive  -- Width of input/output data

    );
    port (
        
        clk                 : in  std_ulogic;
        data_in             : in  std_ulogic_vector(DATA_LENGTH-1 downto 0);

        fault_enable        : in  std_ulogic;  -- Global enable for fault injection (block activation)

        transient_fault     : in  std_ulogic;  -- Trigger signal to inject a transient fault
        match               : in  std_ulogic;  -- LFSR match signal (probabilistic fault trigger)
 
        permanent_fault     : in  std_ulogic;  -- Enable permanent stuck-at fault on selected bit
        stuckatbit          : in  natural range 0 to DATA_LENGTH-1;   -- The index of the stuck-at-fault bit
        stuckatvalue        : in  std_ulogic;  -- Selected bit is stuck at value '0' or '1'
        fault_mask          : in  std_ulogic_vector(DATA_LENGTH-1 downto 0); -- Bit mask defining which bits are flipped (1 = flip, 0 = no effect)
        
        data_out            : out std_ulogic_vector(DATA_LENGTH-1 downto 0)  -- Output data (possibly faulted)
    );
end entity injection_fault;


architecture rtl of injection_fault is

    signal fault_enable_r : std_ulogic := '0';

begin

    fault_proc : process(all)
        variable data_fault : std_ulogic_vector(DATA_LENGTH-1 downto 0);

    begin

        -- Default behavior: no fault injection
        data_fault := data_in;

        -- Fault injection enabled
        if fault_enable_r = '1' then

            -- Permanent fault: always active when enabled
            if permanent_fault = '1' then

                data_fault(stuckatbit) := stuckatvalue;
             
            -- Transient fault: occurs only when triggered and matched
            elsif (transient_fault = '1' and match = '1') then

                data_fault := data_fault xor fault_mask;


            end if;

        end if;

        -- Assign final output
        data_out <= data_fault;

    end process fault_proc;


    reg_proc : process(clk)
    begin
        if rising_edge(clk) then
            fault_enable_r <= fault_enable;
        end if;
    end process;
end architecture rtl;