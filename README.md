# SEU-Resilient NEORV32 RISC-V Core

Student research project at **ISAE-SUPAERO** focused on improving the resilience of a **RISC-V soft-core processor** against **Single Event Effects (SEEs)** induced by radiation effects in embedded and aerospace environments. The project is based on the **[NEORV32 RISC-V CPU v1.13.1](https://github.com/stnolting/neorv32?tab=readme-ov-file)**, which is extended and modified at the RTL level to evaluate and implement hardware fault-tolerance mechanisms.

---

## 1. Main Objectives

- Analyze the vulnerability of processor subsystems to SEEs
- Implement and evaluate mitigation techniques at RTL level
- Study the trade-offs between reliability, area overhead, timing, and power consumption

## 2. Mitigation Techniques Investigated

- **Triple Modular Redundancy (TMR)** for critical logic
- **Error Detection and Correction (EDAC/ECC)** for memories
- **Parity protection** for registers and datapaths
- **Control logic hardening** using DLD-based protection techniques
- **Fault detection and recovery mechanisms**, including watchdog supervision
- **Fault injection campaigns** to evaluate robustness and mitigation efficiency

## 3. Target Applications

- Space and radiation-constrained embedded systems
- Reliable FPGA-based computing architectures
- Safety-critical and fault-tolerant digital systems

## 4. Hardware Platform

| Hardware | Description |
|---|---|
| **Digilent Zybo Z7-20** | Zynq-7000 FPGA development board used as the main hardware platform for the NEORV32 SoC |
| **USB Micro-B cable** | Provides FPGA programming, serial communication, and board power supply |
| **Digilent Pmod USBUART** | UART interface used for communication with the NEORV32 bootloader and software execution monitoring |
| **Digilent JTAG-HS2** *(optional)* | External JTAG debugger used for low-level debugging and on-chip GDB support through the Pmod JD interface |

## 5. Software Environment

| Software / Tool | Description |
|---|---|
| **Xilinx Vivado 2025.2** | RTL synthesis, implementation, bitstream generation, and FPGA programming |
| **ModelSim 2020.1** | Simulation and functional verification of RTL modules and fault-tolerance mechanisms |
| **`riscv32-unknown-elf-gcc 13.2.0`** | Cross-compilation toolchain used to build C programs for the NEORV32 (`RV32I` and `RV32E` targets) |
| **GNU Make** | Executes the NEORV32 build system and automates compilation workflows |
| **picocom** | Serial terminal utility used to monitor UART communication and interact with the NEORV32 bootloader |
| **Git** | Version control and collaborative source management |
| **Linux environment (Ubuntu / Fedora / Red Hat)** | Main development and simulation environment used for FPGA and embedded software workflows |

---

## 6. Software Installation

### 6.1 Vivado

1. Download **Vivado ML Edition** from [xilinx.com/support/download.html](https://www.xilinx.com/support/download.html)
2. During installation select only **Zynq-7000** support to save disk space
3. Activate the free WebPACK licence: `Help → Manage Licence → Get Free WebPACK Licence`

### 6.2 ModelSim

1. Download ModelSim Intel FPGA Edition 2020.1 from [fpgasoftware.intel.com](https://fpgasoftware.intel.com)
2. Install to a known directory (e.g. `C:\intelFPGA\20.1\modelsim_ase`)

### 6.3 RISC-V Toolchain and Build Tools

The project uses the official RISC-V GNU toolchain for compiling software targeting the NEORV32 processor (`RV32I` / `RV32E`).

> Recommended environment: **Linux (Red Hat / Ubuntu / Fedora 43)**

#### Build the Toolchain from Source

The RISC-V GNU toolchain is built directly from source in order to ensure compatibility with the development environment and the NEORV32 software ecosystem.

```bash
export PATH=/usr/bin:/bin:/usr/local/bin

git clone https://github.com/riscv/riscv-gnu-toolchain
cd riscv-gnu-toolchain

./configure \
  --prefix=/opt/riscv \
  --with-arch=rv32i \
  --with-abi=ilp32

sudo make -j$(nproc)
```

#### Installation Notes

- The build process may take approximately **30 minutes**, depending on system performance.
- The compilation may be performed in multiple stages; it can be necessary to rerun:

```bash
sudo make -j$(nproc)
```

multiple times until the full toolchain is successfully installed.

#### Add the Toolchain to the Environment

Once installation is complete, add the toolchain binaries to the system `PATH`:

```bash
echo 'export PATH=/opt/riscv/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
```

#### Verify Installation

```bash
riscv32-unknown-elf-gcc --version
```

A successful installation should display the installed GCC version and RISC-V target information.

### 6.4 OpenOCD and GDB *(optional — JTAG debugging only)*

This setup is only required when using the **Digilent JTAG-HS2** probe for live NEORV32 CPU debugging through JTAG.

> Recommended environment: **native Linux installation**  
> *(Ubuntu / Fedora / Red Hat — WSL is not officially supported for USB JTAG access)*

#### Install Required Dependencies

Ubuntu / Debian:

```bash
sudo apt install \
  libtool pkg-config libusb-1.0-0-dev libftdi1-dev \
  autoconf automake texinfo libjim-dev libhidapi-dev \
  -y
```

Fedora / Red Hat:

```bash
sudo dnf install \
  libtool pkgconf-pkg-config libusb1-devel libftdi-devel \
  autoconf automake texinfo jimtcl-devel hidapi-devel \
  gcc make git
```

#### Build OpenOCD from Source

```bash
git clone https://github.com/openocd-org/openocd.git
cd openocd

./bootstrap
./configure --enable-ftdi

make -j$(nproc)
sudo make install
```

#### Verify Installation

```bash
openocd --version
riscv32-unknown-elf-gdb --version
```

---

## 7. Project Structure

```text
.
├── neorv32/
│   ├── constraints/              ← FPGA constraints and pin assignments
│   │   └── zybo_z7_neorv32.xdc
│   │
│   ├── docs/                     ← Project documentation and reports
│   │
│   ├── rtl/
│   │   ├── core/                 ← Original NEORV32 processor RTL source files
│   │   │
│   │   ├── system_integration/   ← Original NEORV32 SoC integration modules,
│   │   │                            AXI bridges, Vivado IP wrappers,
│   │   │                            and LiteX interfaces
│   │   │
│   │   ├── setups/               ← Top-level configurations and experimental setups
│   │   │
│   │   ├── top/                  ← FPGA top-level design entry points
│   │   │
│   │   ├── file_list_cpu.f       ← CPU RTL compilation file list
│   │   ├── file_list_soc.f       ← SoC RTL compilation file list
│   │   ├── generate_file_lists.sh
│   │   │                          ← Automatically generates RTL file lists
│   │   └── README.md             ← RTL-specific documentation
│   │
│   ├── SEE_module/               ← Experimental SEE mitigation and protection modules
│   │
│   ├── sim/                      ← Simulation and verification environment
│   │
│   ├── sw/                       ← NEORV32 software framework
│   │   ├── example/              ← Example C applications
│   │   └── lib/                  ← NEORV32 HAL and hardware drivers
│   │
│   ├── compile_neorv32.sh        ← Compile, upload, and UART monitoring script
│   ├── uart_upload.sh            ← UART executable upload utility
│   │
│   ├── README.md                 ← Main project documentation
│   ├── CONTRIBUTING.md           ← Contribution guidelines
│   ├── CHANGELOG.md              ← Project modification history
│   └── LICENSE                   ← Project license
│
└── Tcl_Script/                   ← Vivado automation and project generation scripts
```

> **Version note:** both `rtl/core/` and `sw/` must be from **NEORV32 v1.13.1**.

---

## 8. Hardware Setup and Physical Connections

### 8.1 Power and FPGA Programming

Connect the **USB Micro-B cable** to the **PROG/UART port (J12)** on the Zybo Z7 board.

This connection:
- powers the board,
- provides UART access,
- and allows Vivado to program the FPGA.

Set the power switch to **ON**.

> The green **DONE** LED lights up only after the FPGA has been successfully programmed.

### 8.2 UART Connection — Pmod USBUART on Pmod JB

> Configure jumper **JP1** on the Pmod USBUART so that **LCL** is connected to **VCC**  
> *(blue jumper cap installed)*, since the Zybo board is already powered through the programming USB cable.

Plug the **Pmod USBUART** directly into **Pmod JB**.

- Use the **top row** of the JB connector.
- The blue jumper cap should face upward.

Carefully align:
- **Pin 1** of the Pmod module
with
- **Pin 1** of the Zybo PCB connector.

> Pin 1 is identified by:
> - a **"1" marking** on the Zybo PCB,
> - and a **square pad** on the Pmod module.

Finally, connect the Pmod USBUART micro-USB cable to the host PC.

### 8.3 JTAG Connection — JTAG-HS2 on Pmod JD *(optional)*

For live CPU debugging through OpenOCD/GDB, connect the **Digilent JTAG-HS2** probe to **Pmod JD** using jumper wires:

```text
jtag_tck_i   → Pmod JD pin 1   (T14)
jtag_tdi_i   → Pmod JD pin 2   (T15)
jtag_tdo_o   → Pmod JD pin 3   (P14)
jtag_tms_i   → Pmod JD pin 4   (R14)
```

### 8.4 Reset Button

The **BTN0** push-button *(leftmost button on the Zybo board)* resets the NEORV32 CPU.

Pressing this button restarts the NEORV32 bootloader and reinitializes software execution.

### 8.5 SEU Injection Button

The **BTN1** push-button *(located to the right of BTN0 on the Zybo board)* is used to inject a simulated **Single Event Upset (SEU)** into the NEORV32 RAM when running the `neorv32_SEE` Vivado project.

This feature is intended for fault-injection experiments and validation of SEE mitigation techniques implemented in the processor architecture.

> A dedicated README with a detailed explanation of the SEU injection methodology and validation workflow will be provided separately.

---

## 9. Running a Program on the NEORV32

### 9.1 Create the Vivado Project

Open Vivado and select the TCL script corresponding to the desired setup or experiment.

### 9.2 Synthesis, Implementation, and Bitstream Generation

In the Vivado **Flow Navigator**:

1. Run **Synthesis**  
   - Verify that the design compiles without errors.
   - Save the resource utilization report as a reference baseline.

2. Run **Implementation**  
   - Check the timing report and confirm that:
   
   ```text
   WNS ≥ 0
   ```

3. Run **Generate Bitstream**

### 9.3 Program the FPGA

1. **Open Hardware Manager → Open Target → Auto Connect**
2. Vivado detects `xc7z020_1`
3. **Program Device** → select the `.bit` file → **Program**
4. The green **DONE** LED lights up — the NEORV32 is running

### 9.4 Compile and Upload a Program

Two methods are available to run a C program on the NEORV32 CPU.

#### Option 1 — Use the Automated Build and Upload Script

From the project root directory:

```bash
# First use only — make the script executable
chmod +x compile_neorv32.sh
```

The script requires:
- `picocom` to be installed on the system,
- and administrator privileges for temporary UART port access configuration.

Install `picocom` if necessary:

Ubuntu / Debian:

```bash
sudo apt install picocom
```

Fedora / Red Hat:

```bash
sudo dnf install picocom
```

Open `compile_neorv32.sh` and modify the `DEFAULT_EXAMPLE` variable as desired.

Several example applications are available, including:
- LED blinking demonstration
- UART `"Hello World"` example
- CoreMark benchmark for CPU performance evaluation

Then run:

```bash
./compile_neorv32.sh
```

During execution, the script may request the administrator password to temporarily configure serial port permissions.

The script automatically:
- compiles the selected program,
- uploads it through the NEORV32 bootloader,
- and opens a UART monitoring terminal.

#### Option 2 — Manual UART Upload

A second script allows manual upload of any compiled NEORV32 executable (`.bin` format).

Run:

```bash
./uart_upload.sh
```

and carefully follow the instructions displayed in the terminal.

### 9.5 Write and Run Your Own Program

You can create and execute your own C applications on the NEORV32 processor.

#### Compile and Run the Program

Run:

```bash
./compile_neorv32.sh
```

The selected example defined by `DEFAULT_EXAMPLE` inside the script will:
- be compiled with the RISC-V GCC toolchain,
- converted into a NEORV32 executable binary,
- uploaded through UART,
- and executed on the CPU.

#### Custom Standalone Programs

The repository also includes a generic `Makefile` inside:

```text
C_Test_Program/
```

This Makefile can be adapted for standalone C applications.

Requirements:
- the source file must be named `main.c`,
- the RISC-V GCC toolchain must be installed,
- and the compilation steps described previously must be completed.

The generated `.bin` executable can then be uploaded manually using:

```bash
./uart_upload.sh
```

This workflow is useful for testing custom software independently from the default NEORV32 example framework.

---

## 10. Adding SEE Mitigation Modules

Custom SEE mitigation modules are located in:

```text
neorv32/SEE_module/
```

This directory contains experimental hardware protection mechanisms used to improve the resilience of the NEORV32 processor against radiation-induced faults.

Example structure:

```text
SEE_module/
├── tmr/
│   └── tmr_voter.vhd           ← Triple Modular Redundancy voter logic
│
├── ecc/
│   └── ecc_wrapper.vhd         ← ECC protection for memories and datapaths
│
├── scrubber/
│   └── register_scrubber.vhd   ← Periodic register fault mitigation
│
└── watchdog/
    └── watchdog_unit.vhd       ← Fault detection and recovery supervision
```

The Vivado TCL project scripts automatically include these modules during project generation and synthesis.

New mitigation techniques can therefore be integrated by simply adding the corresponding RTL files to the appropriate subdirectory.

Recommended workflow for developing a new SEE mitigation module:

```text
1. Design the mitigation module in SEE_module/
2. Verify functionality using a dedicated ModelSim testbench
3. Integrate the module into the NEORV32 RTL or top-level wrapper
4. Rebuild the Vivado project and generate the bitstream
5. Validate functionality on hardware
6. Perform SEE fault-injection experiments
7. Analyze timing, utilisation, and reliability overhead
8. Commit validated modifications and experimental results
```

--- 

## References

- [NEORV32 RISC-V Processor — Official Repository](https://github.com/stnolting/neorv32?tab=readme-ov-file)

---

## Authors

- Aldo Lupio
- Olivier Oribes
- Teresa Bäurle

## License

NEORV32 is open-source under the BSD-3-Clause license.
