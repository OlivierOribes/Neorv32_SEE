#!/usr/bin/env bash
# =============================================================================
# uart_send.sh
# Interactive NEORV32 UART uploader
# =============================================================================

set -e

# -----------------------------------------------------------------------------
# Check arguments
# -----------------------------------------------------------------------------

if [ $# -ne 1 ]; then
    echo
    echo "Usage:"
    echo "  ./uart_send.sh <file.bin> "
    echo
    exit 1
fi

BINFILE="$1"

# -----------------------------------------------------------------------------
# Detect FTDI serial port
# -----------------------------------------------------------------------------

PORT=$(ls /dev/serial/by-id/*FTDI* 2>/dev/null | head -n 1)

if [ -z "$PORT" ]; then
    echo -e "${RED}ERROR: No FTDI serial port found.${RESET}"
    exit 1
fi

echo -e "${YELLOW}Using UART port: $PORT${RESET}"


BAUD=19200

# -----------------------------------------------------------------------------
# Check binary
# -----------------------------------------------------------------------------

if [ ! -f "$BINFILE" ]; then
    echo
    echo "ERROR: Binary file not found:"
    echo "  $BINFILE"
    echo
    exit 1
fi


# -----------------------------------------------------------------------------
# Banner
# -----------------------------------------------------------------------------

echo
echo "===================================================="
echo "            NEORV32 UART UPLOADER"
echo "===================================================="
echo
echo "Binary : $BINFILE"
echo "UART   : $PORT"
echo "Baud   : $BAUD"
echo

# -----------------------------------------------------------------------------
# Step 1
# -----------------------------------------------------------------------------

echo "----------------------------------------------------"
echo "[STEP 1]"
echo "Program the FPGA bitstream."
echo "----------------------------------------------------"
echo

read -p "Press ENTER when the FPGA is programmed..."

# -----------------------------------------------------------------------------
# Step 2 - Open UART terminal
# -----------------------------------------------------------------------------

echo -e "${BLUE1}>>> Opening serial monitor in a new terminal...${RESET}"

gnome-terminal -- bash -c "
picocom -b $BAUD --nolock \"$PORT\"
exec bash
"
# -----------------------------------------------------------------------------
# Step 3 - Reset CPU / Abort autoboot
# -----------------------------------------------------------------------------

echo
echo "----------------------------------------------------"
echo "[STEP 3]"
echo "Reset the CPU now."
echo
echo "When you see:"
echo
echo "  Auto-boot in 8s. Press any key to abort."
echo
echo "Press SPACE in the UART terminal to stop autoboot."
echo "----------------------------------------------------"
echo

read -p "Press ENTER once autoboot is aborted..."
# -----------------------------------------------------------------------------
# Step 4
# -----------------------------------------------------------------------------

echo
echo "----------------------------------------------------"
echo "[STEP 4]"
echo "In the UART terminal:"
echo
echo "  Type: u"
echo
echo "You should see:"
echo
echo "  Awaiting neorv32_exe.bin..."
echo "----------------------------------------------------"
echo

read -p "Press ENTER once the bootloader is waiting for upload..."

# -----------------------------------------------------------------------------
# Configure UART
# -----------------------------------------------------------------------------

echo
echo "----------------------------------------------------"
echo "[STEP 5]"
echo "Configuring UART..."
echo "----------------------------------------------------"

stty -F "$PORT" \
    "$BAUD" \
    raw \
    -echo \
    -icanon \
    min 1 \
    time 1 \
    cs8 \
    -cstopb \
    -ixon \
    clocal \
    cread

# -----------------------------------------------------------------------------
# Open UART
# -----------------------------------------------------------------------------

exec 3>"$PORT"

FILESIZE=$(stat -c%s "$BINFILE")

sleep 2

echo
echo "Sending binary..."
echo
echo "File size: $FILESIZE bytes"
echo

# -----------------------------------------------------------------------------
# Upload
# -----------------------------------------------------------------------------

cat "$BINFILE" >&3

sync

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------

echo
echo "===================================================="
echo " Upload finished"
echo "===================================================="
echo
echo "Check the UART terminal."
echo
echo "If you received:"
echo
echo "  OK"
echo
echo "then type:"
echo
echo "  e"
echo
echo "to execute the program."
echo
echo "===================================================="

exec 3>&-
