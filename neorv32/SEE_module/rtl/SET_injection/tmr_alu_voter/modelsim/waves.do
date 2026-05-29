#==============================================================================
# File: waves.do
#
# Description:
#    Waveform configuration for tb_tmr_neorv32_cpu_voter
#==============================================================================
quietly WaveActivateNextPane {} 0

#==============================================================================
# CHANNEL A INPUTS
#==============================================================================
add wave -divider "CHANNEL A INPUTS"
add wave -color green  -radix hex    sim:/tb_tmr_neorv32_cpu_voter/res_a
add wave -color green  -radix hex    sim:/tb_tmr_neorv32_cpu_voter/add_a
add wave -color green  -radix hex    sim:/tb_tmr_neorv32_cpu_voter/csr_a
add wave -color green  -radix binary sim:/tb_tmr_neorv32_cpu_voter/cmp_a
add wave -color green  -radix binary sim:/tb_tmr_neorv32_cpu_voter/done_a

#==============================================================================
# CHANNEL B INPUTS
#==============================================================================
add wave -divider "CHANNEL B INPUTS"
add wave -color yellow -radix hex    sim:/tb_tmr_neorv32_cpu_voter/res_b
add wave -color yellow -radix hex    sim:/tb_tmr_neorv32_cpu_voter/add_b
add wave -color yellow -radix hex    sim:/tb_tmr_neorv32_cpu_voter/csr_b
add wave -color yellow -radix binary sim:/tb_tmr_neorv32_cpu_voter/cmp_b
add wave -color yellow -radix binary sim:/tb_tmr_neorv32_cpu_voter/done_b

#==============================================================================
# CHANNEL C INPUTS
#==============================================================================
add wave -divider "CHANNEL C INPUTS"
add wave -color orange -radix hex    sim:/tb_tmr_neorv32_cpu_voter/res_c
add wave -color orange -radix hex    sim:/tb_tmr_neorv32_cpu_voter/add_c
add wave -color orange -radix hex    sim:/tb_tmr_neorv32_cpu_voter/csr_c
add wave -color orange -radix binary sim:/tb_tmr_neorv32_cpu_voter/cmp_c
add wave -color orange -radix binary sim:/tb_tmr_neorv32_cpu_voter/done_c

#==============================================================================
# VOTED OUTPUTS
#==============================================================================
add wave -divider "VOTED OUTPUTS"
add wave -color cyan   -radix hex    sim:/tb_tmr_neorv32_cpu_voter/res_voted
add wave -color cyan   -radix hex    sim:/tb_tmr_neorv32_cpu_voter/add_voted
add wave -color cyan   -radix hex    sim:/tb_tmr_neorv32_cpu_voter/csr_voted
add wave -color cyan   -radix binary sim:/tb_tmr_neorv32_cpu_voter/cmp_voted
add wave -color cyan   -radix binary sim:/tb_tmr_neorv32_cpu_voter/done_voted

#==============================================================================
# MISMATCH / FAULT TELEMETRY
#==============================================================================
add wave -divider "FAULT DETECTION"
add wave -color red    -radix binary sim:/tb_tmr_neorv32_cpu_voter/err_voted

#==============================================================================
# WAVEFORM VIEWER SETTINGS
#==============================================================================
configure wave -namecolwidth 250
configure wave -valuecolwidth 120
configure wave -signalnamewidth 1
configure wave -timelineunits ns
WaveRestoreZoom {0 ns} {60 ns}
update

#==============================================================================
# END OF FILE
#==============================================================================