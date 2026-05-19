-- ================================================================================ --
-- NEORV32 - Test Setup Using The RISC-V-Compatible On-Chip Debugger                --
-- -------------------------------------------------------------------------------- --
-- The NEORV32 RISC-V Processor - https://github.com/stnolting/neorv32              --
-- Copyright (c) NEORV32 contributors.                                              --
-- Copyright (c) 2020 - 2025 Stephan Nolting. All rights reserved.                  --
-- Licensed under the BSD-3-Clause license, see LICENSE for details.                --
-- SPDX-License-Identifier: BSD-3-Clause                                            --
-- ================================================================================ --

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library neorv32;
use neorv32.neorv32_package.all;

entity neorv32_test_setup_on_chip_debugger is
  generic (
    CLOCK_FREQUENCY : natural := 125000000; -- 125 MHz Zybo Z7
    IMEM_SIZE       : natural := 16*1024;
    DMEM_SIZE       : natural := 8*1024
  );
  port (
    -- Global control --
    clk_i       : in  std_ulogic;
    btn0        : in  std_ulogic;
    btn1        : in  std_ulogic;
    -- JTAG on-chip debugger interface --
    jtag_tck_i  : in  std_ulogic;
    jtag_tdi_i  : in  std_ulogic;
    jtag_tdo_o  : out std_ulogic;
    jtag_tms_i  : in  std_ulogic;
    -- GPIO --
    gpio_o      : out std_ulogic_vector(7 downto 0);
    -- UART0 --
    uart0_txd_o : out std_ulogic;
    uart0_rxd_i : in  std_ulogic

  );
end entity;

architecture neorv32_test_setup_on_chip_debugger_rtl of neorv32_test_setup_on_chip_debugger is

  signal con_gpio_out : std_ulogic_vector(31 downto 0);
  signal rstn_i       : std_ulogic;

  -- **************************************************************************************************************************
  -- VIO component declaration
  -- **************************************************************************************************************************

  component vio_0
    port (
      clk        : in  std_logic;
      probe_out0 : out std_logic_vector(31 downto 0); -- mask
      probe_out1 : out std_logic_vector(0 downto 0);  -- fault_enable
      probe_in0  : in  std_logic_vector(31 downto 0); -- faulted_data
      probe_in1  : in  std_logic_vector(31 downto 0); -- clean_data
      probe_in2  : in  std_logic_vector(31 downto 0); -- faulted_address
      probe_in3  : in  std_logic_vector(4 downto 0)   -- at_bit
    );
  end component;

  -- VIO intermediate signals (VIO probe_out → neorv32_top)
  signal vio_mask          : std_logic_vector(31 downto 0);
  signal vio_fault_enable  : std_logic_vector(0 downto 0);

  -- neorv32_top output signals → VIO probe_in
  signal s_faulted_data    : std_ulogic_vector(31 downto 0);
  signal s_clean_data      : std_ulogic_vector(31 downto 0);
  signal s_faulted_address : std_ulogic_vector(31 downto 0);
  signal s_at_bit          : std_ulogic_vector(4 downto 0);

  -- Debouncer
  signal debounce_cnt  : natural range 0 to 1250000 := 0;
  signal btn1_stable   : std_ulogic := '0';
  signal fault_pulse   : std_ulogic := '0';

begin

  rstn_i <= not btn0;


  ---------------------------------------------------------------------------
  -- Debouncer BTN1 → fault_pulse (1 seul cycle par appui)
  ---------------------------------------------------------------------------

  debouncer : process(clk_i)
  begin

    if rising_edge(clk_i) then

      fault_pulse <= '0';

      if (btn1 = '1' ) then
        if (debounce_cnt < 1_250_000) then  -- 1250000 × 8 ns ~ 10 ms
          debounce_cnt <= debounce_cnt + 1; 

        else   
          if (btn1_stable = '0') then

            fault_pulse <= '1';
            btn1_stable <= '1';
          
          end if;
        end if;
      else 
        
        debounce_cnt <= 0;
        btn1_stable  <= '0'; 
      end if;
    end if;
  end process debouncer;


  -- **************************************************************************************************************************
  -- NEORV32 top instantiation
  -- **************************************************************************************************************************

  neorv32_top_inst: entity neorv32.neorv32_top
  generic map (
    CLOCK_FREQUENCY  => CLOCK_FREQUENCY,
    BOOT_MODE_SELECT => 0,
    OCD_EN           => true,
    RISCV_ISA_C      => true,
    RISCV_ISA_M      => true,
    RISCV_ISA_U      => true,
    RISCV_ISA_Zicntr => true,
    IMEM_EN          => true,
    IMEM_SIZE        => IMEM_SIZE,
    DMEM_EN          => true,
    DMEM_SIZE        => DMEM_SIZE,
    IO_GPIO_NUM      => 8,
    IO_CLINT_EN      => true,
    IO_UART0_EN      => true
  )
  port map (
    -- Global control --
    clk_i           => clk_i,
    rstn_i          => rstn_i,
    -- JTAG --
    jtag_tck_i      => jtag_tck_i,
    jtag_tdi_i      => jtag_tdi_i,
    jtag_tdo_o      => jtag_tdo_o,
    jtag_tms_i      => jtag_tms_i,
    -- GPIO --
    gpio_o          => con_gpio_out,
    -- UART0 --
    uart0_txd_o     => uart0_txd_o,
    uart0_rxd_i     => uart0_rxd_i,
    -- SEU control (driven by VIO probe_out) --
    fault_enable    => std_ulogic(vio_fault_enable(0)),
    fault_trigger   => fault_pulse, -- debounced
    fault_MBU       => '0',
    mask            => std_ulogic_vector(vio_mask),
    -- SEU outputs (read by VIO probe_in) --
    faulted_data    => s_faulted_data,
    clean_data      => s_clean_data,
    faulted_address => s_faulted_address,
    at_bit          => s_at_bit
  );

  gpio_o <= con_gpio_out(7 downto 0);

  -- **************************************************************************************************************************
  -- VIO instantiation
  -- **************************************************************************************************************************

  vio_inst : vio_0
    port map (
      clk        => clk_i,
      -- probe_out: Hardware Manager → neorv32_top --
      probe_out0 => vio_mask,
      probe_out1 => vio_fault_enable,
      -- probe_in: neorv32_top → Hardware Manager --
      probe_in0  => std_logic_vector(s_faulted_data),
      probe_in1  => std_logic_vector(s_clean_data),
      probe_in2  => std_logic_vector(s_faulted_address),
      probe_in3  => std_logic_vector(s_at_bit)
    );

end architecture;