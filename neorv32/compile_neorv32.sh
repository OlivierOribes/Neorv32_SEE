#!/usr/bin/env bash
# =============================================================================
# compile_neorv32.sh
# Compile, upload, and monitor script for NEORV32
# =============================================================================

set -e

# -----------------------------------------------------------------------------
# Colors
# -----------------------------------------------------------------------------

RED='\033[31m'
BLUE1='\033[1;34m'
BLUE='\033[34m'
MAGENTA='\033[35m'
CYAN='\033[36m'
RESET='\033[0m'
YELLOW='\033[1;33m'
RED1='\033[1;31m'

# -----------------------------------------------------------------------------
# Banner
# -----------------------------------------------------------------------------

echo -e "\n\n\n"

echo -e "${RED} ##        ##   ##   ##    ${RESET}"
echo -e "${MAGENTA} ##     ##   #########   ########    ########   ##      ##   ########    ########     ##      ################  ${RESET}"
echo -e "${BLUE}####    ##  ##          ##      ##  ##      ##  ##      ##  ##      ##  ##      ##    ##    ####            ####${RESET}"
echo -e "${RED}## ##   ##  ##          ##      ##  ##      ##  ##      ##          ##         ##     ##      ##   ######   ##  ${RESET}"
echo -e "${RED}##  ##  ##  #########   ##      ##  #########   ##      ##      #####        ##       ##    ####   ######   ####${RESET}"
echo -e "${CYAN}##   ## ##  ##          ##      ##  ##     ##    ##    ##           ##     ##         ##      ##   ######   ##  ${RESET}"
echo -e "${MAGENTA}##    ####  ##          ##      ##  ##      ##    ##  ##    ##      ##   ##           ##    ####            ####${RESET}"
echo -e "${BLUE}##     ##    #########   ########   ##       ##     ##       ########   ##########    ##      ################  ${RESET}"
echo -e "${RED}                                                                                      ##        ##   ##   ##    ${RESET}"

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

DEFAULT_EXAMPLE="hello_world"
#DEFAULT_EXAMPLE="demo_blink_led"
#DEFAULT_EXAMPLE="coremark"

BAUD="19200"

EXAMPLE=${1:-$DEFAULT_EXAMPLE}

BINFILE="neorv32_exe.bin"

LOGFILE="/tmp/neorv32_uart.log"

# -----------------------------------------------------------------------------
# Detect FTDI serial port
# -----------------------------------------------------------------------------

PORT=$(ls /dev/serial/by-id/*FTDI* 2>/dev/null | head -n 1)

if [ -z "$PORT" ]; then
    echo -e "${RED}ERROR: No FTDI serial port found.${RESET}"
    exit 1
fi

echo -e "${YELLOW}Using UART port: $PORT${RESET}"

# -----------------------------------------------------------------------------
# Paths
# -----------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)/sw"

# -----------------------------------------------------------------------------
# Temporary serial port permissions
# Access resets after reboot or USB reconnect
# -----------------------------------------------------------------------------

echo -e "${RED1}>>> Setting temporary serial port permissions...${RESET}"
sudo chmod 666 "$PORT"

# -----------------------------------------------------------------------------
# Open serial monitor (--nolock so script can share port, --logfile to capture response)
# -----------------------------------------------------------------------------




echo -e "${BLUE1}>>> Opening serial monitor in a new terminal...${RESET}"

rm -f "$LOGFILE"

gnome-terminal -- bash -c "

picocom -b $BAUD --logfile $LOGFILE \"$PORT\"

exec bash
"

sleep 2

# -----------------------------------------------------------------------------
# Wait for FPGA / bootloader
# -----------------------------------------------------------------------------

echo
echo -e "${RED1}>>> Please implement the bitstream or reset the CPU within 15 seconds.${RESET}"

sleep 15

# -----------------------------------------------------------------------------
# Build
# -----------------------------------------------------------------------------

echo -e "${BLUE1}>>> Compiling example: $EXAMPLE${RESET}"

cd "$SCRIPT_DIR/example/$EXAMPLE/" || {
    echo -e "${RED}ERROR: Example not found.${RESET}"
    exit 1
}

make clean_all exe

echo -e "${CYAN}>>> Compilation done${RESET}"

# -----------------------------------------------------------------------------
# UART Upload
# -----------------------------------------------------------------------------

echo -e "${BLUE1}>>> Uploading executable...${RESET}"

FILESIZE=$(stat -c%s "$BINFILE")
TIMEOUT=$(( (FILESIZE / (BAUD / 10)) + 5 ))

printf "Opening serial port ($PORT)... "
stty -F "$PORT" "$BAUD" raw -echo -hup cs8 -cstopb -ixon clocal cread
printf "OK\n"

# Skip auto-boot
printf " " > "$PORT" ; sleep 1

# Start upload mode
printf "u" > "$PORT" ; sleep 1

printf "Uploading executable ($FILESIZE bytes)...\n"
cat "$BINFILE" > "$PORT"   # blocking — picocom logs the response while this runs

sleep "$TIMEOUT"
# Watch the logfile for bootloader response
RESPONSE=""
DEADLINE=$(( SECONDS + 5 ))

while [ "$SECONDS" -lt "$DEADLINE" ]; do
    RESPONSE=$(cat "$LOGFILE" 2>/dev/null || true)
    if [[ "$RESPONSE" == *"OK"* ]]; then break; fi
    if [[ "$RESPONSE" == *"ERR"* ]]; then break; fi
    sleep 0.2
done

# -----------------------------------------------------------------------------
# Upload result
# -----------------------------------------------------------------------------

if [[ "$RESPONSE" == *"OK"* ]]; then
    printf "Upload OK\n"
    printf "Booting executable...\n"
    printf "e" > "$PORT"
    exit 0
else
    printf "\nERROR! No valid bootloader response.\n"
    printf "Received:\n%s\n" "$RESPONSE"
    exit 1
fi

# -----------------------------------------------------------------------------
# End of script
# -----------------------------------------------------------------------------
