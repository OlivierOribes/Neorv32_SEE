#==============================================================================
# File: simulate.do
#
# Description:
#   ModelSim simulation script for tb_tmr_neorv32_cpu_voter.
#   - Opens the simulation with full visibility
#   - Loads waveform configuration
#   - Runs simulation
#   - Leaves GUI open for inspection
#
# Usage (from tmr_voter/sim/):
#   vsim -do simulate.do
#==============================================================================

#------------------------------------------------------------------------------
# Launch simulator
# -L neorv32       : tells ModelSim where to find the neorv32 library (needed for package constants)
# -voptargs="+acc" : ensures internal signals are visible in the wave window
#------------------------------------------------------------------------------
vsim -voptargs="+acc" -L neorv32 work.tb_tmr_neorv32_cpu_voter -t 1ns

#------------------------------------------------------------------------------
# Load waveform configuration
#------------------------------------------------------------------------------
if {[file exists waves.do]} {
    do waves.do
}

#------------------------------------------------------------------------------
# Run simulation
# Since our voter testbench is combinational and uses a sequential 'wait',
# 'run -all' runs through all 4 scenarios and pauses cleanly at the end.
#------------------------------------------------------------------------------
run -all

#------------------------------------------------------------------------------
# Zoom to full view
#------------------------------------------------------------------------------
wave zoom full