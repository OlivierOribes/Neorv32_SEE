#==============================================================================
# File: compile.do
# Description: Compiles ONLY the standalone TMR Voter and its testbench.
#==============================================================================

echo "--------------------------------------------"
echo "Cleaning up old libraries"
echo "--------------------------------------------"
if {[file exists work]} { vdel -lib work -all }
if {[file exists neorv32]} { vdel -lib neorv32 -all }

vlib work
vmap work work
vlib neorv32
vmap neorv32 neorv32

# Paths
set NEORV32_RTL /home/teresa/neorv32_seu/rtl/core
set TMR_SRC     /home/teresa/Documents/RP/tmr_voter/src
set TMR_TB      /home/teresa/Documents/RP/tmr_voter/tb

echo "--------------------------------------------"
echo "Compiling Prerequisites & Voter Files..."
echo "--------------------------------------------"

# Package dependency (for XLEN)
vcom -2008 -work neorv32 $NEORV32_RTL/neorv32_package.vhd

# Voter core & Testbench
vcom -2008 -work work $TMR_SRC/tmr_neorv32_cpu_voter.vhd
vcom -2008 -work work $TMR_TB/tb_tmr_neorv32_cpu_voter.vhd

echo "--------------------------------------------"
echo "Compilation finished successfully!"
echo "--------------------------------------------"