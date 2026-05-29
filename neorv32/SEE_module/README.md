# SEE Fault Injection Modules — NEORV32

This directory contains the VHDL modules developed to simulate cosmic radiation effects (SEE — *Single Event Effects*) on the NEORV32 processor implemented on a Zynq FPGA.

Two fault types are covered:

- **SET** — *Single Event Transient*: transient glitch on a combinational signal path
- **SEU** — *Single Event Upset*: bit-flip in a storage element (RAM)

---

## Module Structure

```
rtl/
├── Saboteur modules/              # Saboteur approach (SET + external SEU)
│   ├── Injection_fault_SET/       # Combinational injection block (SET / stuck-at)
│   ├── injection_controller_SET/  # Probabilistic controller (dual LFSR)
│   ├── fault_injection_SET_top/   # SET top-level (controller + injection)
│   └── injection_fault_SEU/       # External SEU saboteur (read-modify-write FSM)
│
├── Mutant modules/                # Mutant module approach — integrated SEU (PREFERRED)
│   ├── neorv32_dmem.vhd           # Modified DMEM exposing SEU ports
│   ├── neorv32_dmem_ram.vhd       # RAM wrapper with LFSR and fault mask generation
│   ├── neorv32_prim.vhd           # TDP SPRAM with SEU FSM on Port B
│   └── seu_pkg.vhd                # Shared package (Fibonacci LFSR function)
│
├── SEE_Injection_top/             # SoC top-level modifications (SEU + SET propagation)
│   ├── neorv32_top.vhd            # Modified neorv32_top: SEU ports exposed, btn2 routed to CPU
│   └── neorv32_test_setup_on_chip_debugger.vhd  # Board-level top with injection port wiring
│
└── SET_injection_top/             # CPU-level modifications for SET injection at the ALU
    └── neorv32_cpu.vhd            # Modified neorv32_cpu: Saboteur on rs1 before ALU, VIO control
```

---

## SET Injection — Saboteur Approach

SET injection uses a **Saboteur**: an external block inserted on an existing signal path. The original module is left untouched; the Saboteur is wired in between and corrupts the data flowing on the target bus.

### Components

#### `injection_fault_SET.vhd` — Injection block (purely combinational)

Fully combinational module — no clock, no internal state. Default behavior: `data_out = data_in`.

| Mode | Condition | Behavior |
|------|-----------|----------|
| Normal | `fault_enable = '0'` | Full transparency |
| Transient fault (SET) | `fault_enable='1'`, `transient_fault='1'`, `match='1'` | XOR of `data_in` with `fault_mask` |
| Permanent fault (stuck-at) | `fault_enable='1'`, `permanent_fault='1'` | Forces `stuckatbit` to `stuckatvalue` |

Priority: **permanent > transient > normal**.

**Main ports:**

| Port | Direction | Description |
|------|-----------|-------------|
| `data_in` / `data_out` | in/out | Data bus (configurable width) |
| `fault_enable` | in | Global enable |
| `transient_fault` | in | Triggers a transient fault |
| `match` | in | Probabilistic signal from the LFSR controller |
| `permanent_fault` | in | Enables stuck-at mode |
| `stuckatbit` | in | Index of the stuck bit |
| `stuckatvalue` | in | Forced value (`'0'` or `'1'`) |
| `fault_mask` | in | Bit mask of flipped bits (1 = flip) |

---

#### `fault_injection_controller.vhd` — Probabilistic controller

Sequential module generating a probabilistic `match` signal to control the injection rate.

- Two **decorrelated** 16-bit Fibonacci LFSRs (distinct seeds and tap polynomials):
  - LFSR1: taps `[15, 13, 12, 10]`, seed `0xACE1`
  - LFSR2: taps `[15, 14, 12, 3]`, seed `0x1234`
- `match = '1'` when the N LSBs of both LFSRs are equal
- **Injection probability: `1 / 2^N`** (`N = nbr_bits_to_match`, range 0–15)
- `N = 0` → continuous injection (`match` always `'1'` while enabled)

---

#### `fault_injection_SET_top.vhd` — SET top-level

Connects the controller and the injection block:

```
clk, rst_n ──► fault_injection_controller ──► match
                                                 │
data_in ──────► injection_fault ◄────────────────┘
                     │
               data_out
```

---

## SEU Injection — Saboteur Approach (`injection_fault_SEU.vhd`)

This module implements external SEU injection on a synchronous RAM via a **synchronous FSM** performing a read-modify-write cycle.

**FSM:** `IDLE → READ → MODIFY → WRITE → IDLE`

1. **READ**: generates a pseudo-random address (bits `[5:0]` of a 32-bit LFSR mod `MEMORY_DEPTH`), issues a read
2. **MODIFY**: selects a pseudo-random bit (bits `[7:0]` of the LFSR mod `DATA_LENGTH`), builds a one-hot mask and XORs with `data_i`
3. **WRITE**: writes the corrupted word back to the same address

**32-bit Galois LFSR:** seed `0xA5C3F19B`, taps `[32, 22, 2, 1]`

The module connects directly to the external RAM interface (`en_o`, `rw_o`, `addr_o`, `data_o`, `data_i`).

---

## SEU Injection — Mutant Module Approach (PREFERRED)

> **This is the preferred approach for SEU injection.**

A **mutant module** is a modified version of an original component from the target system. Unlike a Saboteur, the mutant is not an external block wired on top of a signal: it **directly replaces** the original component (`neorv32_dmem.vhd` and `neorv32_prim.vhd`) by integrating the injection logic inside the component itself.

### Why the mutant module is preferred

| Criterion | SEU Saboteur | Mutant Module |
|-----------|-------------|---------------|
| Placement | External, wired on the bus | Integrated inside the RAM component |
| CPU access | Shared with the injection FSM | **Independent** — dedicated Port A |
| Bus collision risk | Yes (FSM and CPU share the interface) | **None** — True Dual-Port RAM |
| CPU transparency | Partial | **Total** — CPU is never stalled |
| Physical realism | Read-modify-write visible on the bus | Direct modification inside the BRAM |
| MBU support | No (single-bit only) | **Yes** — external `mask(31:0)` |
| Observability | None | `at_bit`, `faulted_address`, `clean_data`, `faulted_data` |
| FPGA mapping | Extra external logic | **Native TDP BRAM inferred by Vivado** |

### How it works

The mutant module is built around a **True Dual-Port RAM** (`neorv32_prim_spram`) implemented as a VHDL `shared variable` forced to BRAM TDP inference (`ram_style = "block"`):

- **Port A** — Normal CPU read/write access, never interrupted
- **Port B** — SEU injection FSM, running fully in parallel and transparent to the CPU

**Port B FSM:** `IDLE → SEU_READ → SEU_WRITE`

When `fault_enable='1'` and `fault_trigger='1'`:
1. `SEU_READ`: reads the clean word at the target address from the shared BRAM
2. `SEU_WRITE`: writes `clean_data XOR faulted_bit` back to the same address and exposes both `clean_data` and `faulted_data` for observation

**Pseudo-random generation (DMEM RAM wrapper):**

A **32-bit Fibonacci LFSR** (seed `0xA5C3F19B`, taps `[31, 21, 1, 0]`) advances on each `fault_trigger` pulse. From the current LFSR vector:
- Bits `[AWIDTH-3:0]` → target word address (32-bit word-aligned)
- Bits `[4:0]` → index of the bit to flip (SBU)

**Supported fault modes:**

| Mode | Control | Mask used |
|------|---------|-----------|
| SBU (*Single-Bit Upset*) | `fault_MBU='0'` | One-hot mask generated by the LFSR |
| MBU (*Multi-Bit Upset*) | `fault_MBU='1'` | External `mask(31:0)` |

The DMEM is decomposed into **4 byte-wide SPRAM instances** (4 × 8 = 32 bits). The 32-bit fault mask is sliced into 8-bit lanes distributed to each instance.

### Injection ports (exposed to the SoC top-level)

| Port | Direction | Description |
|------|-----------|-------------|
| `fault_enable` | in | Global SEU mechanism enable |
| `fault_trigger` | in | Triggers one injection cycle (rising edge) |
| `fault_MBU` | in | Selects MBU mode |
| `mask` | in | 32-bit mask for MBU |
| `rst_n` | in | Synchronous active-low reset for the LFSR |
| `at_bit` | out | Index of the flipped bit (debug) |
| `faulted_address` | out | Address of the injected fault (debug) |
| `clean_data` | out | Original value before the fault (debug) |
| `faulted_data` | out | Value after the fault (debug) |

---

## C Test Programs — `C_Test_Program/`

Bare-metal C programs running on the NEORV32 processor itself, used to validate and characterize the fault injection modules from the software side.

```
C_Test_Program/
└── SEU_RAM_test/          # SEU mutant module validation program
    └── main.c
```

### `SEU_RAM_test/` — SEU Mutant Module Validation

Validates the SEU mutant module by detecting bit-flips injected into the DMEM from software running on the processor.

**Principle:**

1. The entire DMEM (1971 words from `0x80000000`) is initialized to a known reference pattern (`0x00000000`)
2. The SEU mutant module is triggered from the FPGA hardware side (`fault_trigger` pulse)
3. The program then scans memory for any word deviating from the reference and reports it over UART

**UART command interface:**

| Command | Action |
|---------|--------|
| `s` | Scan DMEM for corrupted words — prints address and value of each detected SEU, then total count |
| `r` | Reset all DMEM words back to `0x00000000` (clears detected faults for a new injection cycle) |

A heartbeat LED on GPIO bit 0 toggles every 500 ms to confirm the processor is alive and the monitoring loop is running.

**Typical test flow:**

```
1. Flash program → DMEM initialized to 0x00000000
2. Assert fault_trigger (hardware side) → mutant module injects one bit-flip
3. Send 's' over UART → program reports corrupted address and value
4. Send 'r' over UART → DMEM reset, ready for the next injection
```

> Additional test programs (SET validation, MBU campaigns, mitigation benchmarks) will be added here as the injection infrastructure matures.

---

## Summary Table

| Module | Type | Target | Approach | Preferred |
|--------|------|--------|----------|-----------|
| `injection_fault_SET.vhd` | SET / stuck-at | Combinational bus | Saboteur | — |
| `fault_injection_controller.vhd` | SET | — | Dual LFSR controller | — |
| `fault_injection_SET_top.vhd` | SET | Data bus | Saboteur (top-level) | — |
| `injection_fault_SEU.vhd` | SEU | External RAM | Saboteur | No |
| `neorv32_dmem.vhd` + `neorv32_dmem_ram.vhd` + `neorv32_prim_spram` | SEU / MBU | NEORV32 DMEM | **Mutant** | **Yes** |

---

## Dependencies

- VHDL 2008
- Vivado 2023+ (TDP BRAM inference via `ram_style = "block"`)
- NEORV32 SoC (for mutant modules)
- Package `neorv32.seu_pkg` (shared Fibonacci LFSR function)

---

*Author: Olivier Oribes — Neorv32 SEE Project, 2026*
