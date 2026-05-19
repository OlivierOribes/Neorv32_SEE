-- ================================================================================ --
-- NEORV32 Primitives - Generic Single-Clock FIFO (FIFO)                            --
-- -------------------------------------------------------------------------------- --
-- The FIFO operates in "first-word-fall-through" (FWFT) mode: the first written    --
-- word appears directly at the output (after the synchronous-read delay) without   --
-- any explicit read access.                                                        --
--                                                                                  --
-- The status signals "free space left" (free_o) and "data available" (avail_o)     --
-- are synchronized to the according port:                                          --
-- - free_o  -> write port                                                          --
-- - avail_o -> read port                                                           --
-- -------------------------------------------------------------------------------- --
-- The NEORV32 RISC-V Processor - https://github.com/stnolting/neorv32              --
-- Copyright (c) NEORV32 contributors.                                              --
-- Copyright (c) 2020 - 2026 Stephan Nolting. All rights reserved.                  --
-- Licensed under the BSD-3-Clause license, see LICENSE for details.                --
-- SPDX-License-Identifier: BSD-3-Clause                                            --
-- ================================================================================ --

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity neorv32_prim_fifo is
  generic (
    AWIDTH  : natural; -- address width (= log2(number of FIFO entries))
    DWIDTH  : natural; -- size of data elements in FIFO
    OUTGATE : boolean  -- true = output zero if no data available
  );
  port (
    -- global control --
    clk_i   : in  std_ulogic;                           -- clock, rising edge
    rstn_i  : in  std_ulogic;                           -- async reset, low-active
    clear_i : in  std_ulogic;                           -- sync reset, high-active
    -- write port --
    wdata_i : in  std_ulogic_vector(DWIDTH-1 downto 0); -- write data
    we_i    : in  std_ulogic;                           -- write enable
    free_o  : out std_ulogic;                           -- at least one entry is free when set
    -- read port --
    re_i    : in  std_ulogic;                           -- read enable
    rdata_o : out std_ulogic_vector(DWIDTH-1 downto 0); -- read data
    avail_o : out std_ulogic                            -- data available when set


  );
end neorv32_prim_fifo;

architecture neorv32_prim_fifo_rtl of neorv32_prim_fifo is

  -- memory core --
  type ram_t is array ((2**AWIDTH)-1 downto 0) of std_ulogic_vector(DWIDTH-1 downto 0);
  signal fifo : ram_t;

  -- local signals --
  signal rdata : std_ulogic_vector(DWIDTH-1 downto 0);
  signal we, re, match, full, empty, avail : std_ulogic;
  signal w_pnt, w_nxt, r_pnt, r_nxt : std_ulogic_vector(AWIDTH downto 0);

begin

  -- Pointers -------------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  pointer_reg: process(rstn_i, clk_i)
  begin
    if (rstn_i = '0') then
      w_pnt <= (others => '0');
      r_pnt <= (others => '0');
    elsif rising_edge(clk_i) then
      w_pnt <= w_nxt;
      r_pnt <= r_nxt;
    end if;
  end process pointer_reg;

  -- access control --
  re <= re_i and (not empty); -- read only if data available
  we <= we_i and (not full);  -- write only if free space available

  -- pointer update --
  w_nxt <= (others => '0') when (clear_i = '1') else std_ulogic_vector(unsigned(w_pnt) + 1) when (we = '1') else w_pnt;
  r_nxt <= (others => '0') when (clear_i = '1') else std_ulogic_vector(unsigned(r_pnt) + 1) when (re = '1') else r_pnt;

  -- Status ---------------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  -- more than 1 FIFO entry --
  status_large:
  if (AWIDTH > 0) generate
    match <= '1' when (r_pnt(AWIDTH-1 downto 0) = w_pnt(AWIDTH-1 downto 0)) else '0';
    full  <= '1' when (r_pnt(AWIDTH) /= w_pnt(AWIDTH)) and (match = '1') else '0';
    empty <= '1' when (r_pnt(AWIDTH)  = w_pnt(AWIDTH)) and (match = '1') else '0';
    -- [important] 'avail' is synchronized to the read port --
    status_reg: process(rstn_i, clk_i)
    begin
      if (rstn_i = '0') then
        avail <= '0';
      elsif rising_edge(clk_i) then
        avail <= not empty;
      end if;
    end process status_reg;
  end generate;

  -- just 1 FIFO entry --
  status_small:
  if (AWIDTH = 0) generate
    match <= '1' when (r_pnt(0) = w_pnt(0)) else '0';
    full  <= not match;
    empty <= match;
    avail <= not empty;
  end generate;

  -- status output --
  free_o  <= not full;
  avail_o <= avail;


  -- Memory ---------------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  -- more than 1 FIFO entry --
  memory_large:
  if (AWIDTH > 0) generate
    memory_core: process(clk_i) -- simple dual-port RAM
    begin
      if rising_edge(clk_i) then
        if (we = '1') then
          fifo(to_integer(unsigned(w_pnt(AWIDTH-1 downto 0)))) <= wdata_i;
        end if;
        rdata <= fifo(to_integer(unsigned(r_pnt(AWIDTH-1 downto 0))));
      end if;
    end process memory_core;
  end generate;

  -- just 1 FIFO entry --
  memory_small:
  if (AWIDTH = 0) generate
    memory_core: process(rstn_i, clk_i) -- single register
    begin
      if (rstn_i = '0') then
        fifo(0) <= (others => '0');
      elsif rising_edge(clk_i) then
        if (we = '1') then
          fifo(0) <= wdata_i;
        end if;
      end if;
    end process memory_core;
    rdata <= fifo(0);
  end generate;

  -- output gate: output zero if no data available --
  rdata_o <= (others => '0') when OUTGATE and (avail = '0') else rdata;

end neorv32_prim_fifo_rtl;


-- ================================================================================ --
-- NEORV32 Primitives - True Dual-Port RAM (SPRAM + SEU Injection)                  --
-- -------------------------------------------------------------------------------- --
-- Port A : CPU normal read/write access (never stalled by SEU).                    --
-- Port B : SEU fault injection FSM — 3-cycle read-modify-write, runs in parallel.  --
-- Both ports share a single BRAM TDP inferred by Vivado via shared variable.       --
-- -------------------------------------------------------------------------------- --
-- The NEORV32 RISC-V Processor - https://github.com/stnolting/neorv32              --
-- Copyright (c) NEORV32 contributors.                                              --
-- Copyright (c) 2020 - 2026 Stephan Nolting. All rights reserved.                  --
-- Modified for SEU research platform - Olivier Oribes, 2026                               --
-- Licensed under the BSD-3-Clause license, see LICENSE for details.                --
-- SPDX-License-Identifier: BSD-3-Clause                                            --
-- ================================================================================ --

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity neorv32_prim_spram is
  generic (
    AWIDTH : natural;
    DWIDTH : natural;
    OUTREG : natural
  );
  port (
    clk_i  : in  std_ulogic;
    en_i   : in  std_ulogic;
    rw_i   : in  std_ulogic;
    addr_i : in  std_ulogic_vector(AWIDTH-1 downto 0);
    data_i : in  std_ulogic_vector(DWIDTH-1 downto 0);
    data_o : out std_ulogic_vector(DWIDTH-1 downto 0);

    fault_enable    : in  std_ulogic := '0';
    fault_trigger   : in  std_ulogic := '0';
    faulted_address : in  std_ulogic_vector(AWIDTH-1 downto 0) := (others => '0');
    faulted_bit     : in  std_ulogic_vector(DWIDTH-1 downto 0) := (others => '0');
    clean_data      : out std_ulogic_vector(DWIDTH-1 downto 0);
    faulted_data    : out std_ulogic_vector(DWIDTH-1 downto 0)
  );
end neorv32_prim_spram;

architecture neorv32_prim_spram_rtl of neorv32_prim_spram is

  type ram_t is array ((2**AWIDTH)-1 downto 0) of std_ulogic_vector(DWIDTH-1 downto 0);
  shared variable spram : ram_t;

  -- Force BRAM TDP inference
  attribute ram_style : string;
  attribute ram_style of spram : variable is "block";

  signal rdata : std_ulogic_vector(DWIDTH-1 downto 0);

  -- SEU FSM
  type seu_state_t is (IDLE, SEU_READ, SEU_WRITE);
  signal seu_state : seu_state_t := IDLE;
  signal clean_reg : std_ulogic_vector(DWIDTH-1 downto 0);
  signal addr_reg  : std_ulogic_vector(AWIDTH-1 downto 0);
  signal bit_reg   : std_ulogic_vector(DWIDTH-1 downto 0);

begin

  memory_large:
  if (AWIDTH > 0) generate

    -- ----------------------------------------------------------------
    -- Port A : CPU — normal read/write
    -- ----------------------------------------------------------------
    port_a: process(clk_i)
    begin
      if rising_edge(clk_i) then
        if (en_i = '1') then
          if (rw_i = '1') then
            spram(to_integer(unsigned(addr_i))) := data_i;
          end if;
          rdata <= spram(to_integer(unsigned(addr_i)));
        end if;
      end if;
    end process port_a;
    
    
    -- ----------------------------------------------------------------
    -- Port B : SEU FSM — 3-cycle read-modify-write, runs in parallel
    -- ----------------------------------------------------------------
    port_b: process(clk_i)
    begin
      if rising_edge(clk_i) then

        clean_data   <= (others => '0');
        faulted_data <= (others => '0');

        case seu_state is

          when IDLE =>
            if (fault_enable = '1') and (fault_trigger = '1') then
              addr_reg  <= faulted_address;
              bit_reg   <= faulted_bit;
              seu_state <= SEU_READ;
            end if;

          when SEU_READ =>
            clean_reg <= spram(to_integer(unsigned(addr_reg)));
            seu_state <= SEU_WRITE;

          when SEU_WRITE =>

            spram(to_integer(unsigned(addr_reg))) := clean_reg xor bit_reg;
            clean_data   <= clean_reg;
            faulted_data <= clean_reg xor bit_reg;
            seu_state    <= IDLE;

          when others =>
            seu_state <= IDLE;

        end case;
      end if;
    end process port_b;

  end generate;

  -- single entry only --
  memory_small:
  if (AWIDTH = 0) generate
    memory_core: process(clk_i)
    begin
      if rising_edge(clk_i) then
        if (en_i = '1') and (rw_i = '1') then
          rdata <= data_i;
        end if;
      end if;
    end process memory_core;
  end generate;

  -- Output Register
  output_register_enabled:
  if (OUTREG = 1) generate
    read_outreg: process(clk_i)
    begin
      if rising_edge(clk_i) then
        data_o <= rdata;
      end if;
    end process read_outreg;
  end generate;

  output_register_disabled:
  if (OUTREG = 0) generate
    data_o <= rdata;
  end generate;

end neorv32_prim_spram_rtl;


-- ================================================================================ --
-- NEORV32 Primitives - Generic 2-Cycle Signed/Unsigned Integer Multiplier (MUL)    --
-- -------------------------------------------------------------------------------- --
-- The NEORV32 RISC-V Processor - https://github.com/stnolting/neorv32              --
-- Copyright (c) NEORV32 contributors.                                              --
-- Copyright (c) 2020 - 2026 Stephan Nolting. All rights reserved.                  --
-- Licensed under the BSD-3-Clause license, see LICENSE for details.                --
-- SPDX-License-Identifier: BSD-3-Clause                                            --
-- ================================================================================ --

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity neorv32_prim_mul is
  generic (
    DWIDTH : natural -- operand width
  );
  port (
    -- global control --
    clk_i    : in  std_ulogic;                              -- clock, rising edge
    rstn_i   : in  std_ulogic;                              -- reset, low-active, async
    -- data path --
    en_i     : in  std_ulogic;                              -- enable input operand registers
    opa_i    : in  std_ulogic_vector(DWIDTH-1 downto 0);    -- operand A
    opa_sn_i : in  std_ulogic;                              -- operand A is a signed number
    opb_i    : in  std_ulogic_vector(DWIDTH-1 downto 0);    -- operand B
    opb_sn_i : in  std_ulogic;                              -- operand B is a signed number
    res_o    : out std_ulogic_vector((2*DWIDTH)-1 downto 0) -- resulting product
  );
end neorv32_prim_mul;

architecture neorv32_prim_mul_rtl of neorv32_prim_mul is

  signal opa, opb : signed(DWIDTH downto 0);
  signal res : signed((2*DWIDTH)+1 downto 0);

begin

  -- Input Registers ------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  in_reg: process(rstn_i, clk_i)
  begin
    if (rstn_i = '0') then
      opa <= (others => '0');
      opb <= (others => '0');
    elsif rising_edge(clk_i) then
      if (en_i = '1') then
        opa <= signed((opa_i(opa_i'left) and opa_sn_i) & opa_i);
        opb <= signed((opb_i(opb_i'left) and opb_sn_i) & opb_i);
      end if;
    end if;
  end process in_reg;

  -- Output Register ------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  out_reg: process(clk_i)
  begin
    if rising_edge(clk_i) then -- no reset to improve DSP mapping
      res <= opa * opb;
    end if;
  end process out_reg;

  -- result --
  res_o <= std_ulogic_vector(res((2*DWIDTH)-1 downto 0));

end neorv32_prim_mul_rtl;


-- ================================================================================ --
-- NEORV32 Primitives - Generic Counter Module                                      --
-- -------------------------------------------------------------------------------- --
-- High and low words are split across two individual registers to improve timing   --
-- by cutting the carry chain. The actual counter width can be trimmed via CWIDTH.  --
-- [WARNING] High and low words of counter output cnt_o are _NOT_ synchronized!     --
-- -------------------------------------------------------------------------------- --
-- The NEORV32 RISC-V Processor - https://github.com/stnolting/neorv32              --
-- Copyright (c) NEORV32 contributors.                                              --
-- Copyright (c) 2020 - 2026 Stephan Nolting. All rights reserved.                  --
-- Licensed under the BSD-3-Clause license, see LICENSE for details.                --
-- SPDX-License-Identifier: BSD-3-Clause                                            --
-- ================================================================================ --

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity neorv32_prim_cnt is
  generic (
    CWIDTH : natural range 0 to 64 -- actual counter width (0..64)
  );
  port (
    -- global control --
    clk_i  : in  std_ulogic;                     -- clock, rising edge
    rstn_i : in  std_ulogic;                     -- reset, low-active, async
    inc_i  : in  std_ulogic;                     -- enable counter increment
    -- read/write access --
    we_i   : in  std_ulogic_vector(1 downto 0);  -- subword write enable
    data_i : in  std_ulogic_vector(31 downto 0); -- subword write data
    oe_i   : in  std_ulogic;                     -- output enable
    cnt_o  : out std_ulogic_vector(63 downto 0)  -- trimmed counter output
  );
end neorv32_prim_cnt;

architecture neorv32_prim_cnt_rtl of neorv32_prim_cnt is

  signal count : std_ulogic_vector(63 downto 0);
  signal carry, incen : std_ulogic_vector(0 downto 0);
  signal inc_lo, inc_hi : std_ulogic_vector(32 downto 0);

begin

  -- 64-Bit Counter (split across two 32-bit registers) -------------------------------------
  -- -------------------------------------------------------------------------------------------
  counter_core: process(rstn_i, clk_i)
  begin
    if (rstn_i = '0') then
      incen <= (others => '0');
      count <= (others => '0');
      carry <= (others => '0');
    elsif rising_edge(clk_i) then
      -- increment enable --
      incen(0) <= inc_i;
      -- low-word --
      if (we_i(0) = '1') then
        count(31 downto 0) <= data_i;
      else
        count(31 downto 0) <= inc_lo(31 downto 0);
      end if;
      -- low-to-high carry --
      carry(0) <= inc_lo(32);
      -- high-word --
      if (we_i(1) = '1') then
        count(63 downto 32) <= data_i;
      else
        count(63 downto 32) <= inc_hi(31 downto 0);
      end if;
    end if;
  end process counter_core;

  -- increments --
  inc_lo <= std_ulogic_vector(unsigned('0' & count(31 downto  0)) + unsigned(incen));
  inc_hi <= std_ulogic_vector(unsigned('0' & count(63 downto 32)) + unsigned(carry));

  -- Output Gating and Trimming -------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  trim: process(oe_i, count)
  begin
    cnt_o <= (others => '0');
    if (oe_i = '1') then
      cnt_o(CWIDTH-1 downto 0) <= count(CWIDTH-1 downto 0);
    end if;
  end process trim;

end neorv32_prim_cnt_rtl;
