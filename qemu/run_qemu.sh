#!/bin/bash

FIRMWARE_BIN="${1:-bazel-bin/firmware/firmware}"
QEMU_SYSTEM_ARM="${QEMU_SYSTEM_ARM:-qemu-system-arm}"

if [ ! -f "$FIRMWARE_BIN" ]; then
    echo "Error: Firmware binary not found at $FIRMWARE_BIN"
    echo "Please build the firmware first with: bazel build //firmware:firmware"
    exit 1
fi

echo "Starting QEMU simulation..."
echo "Firmware: $FIRMWARE_BIN"
echo "Press Ctrl+A, X to exit"

$QEMU_SYSTEM_ARM \
    -machine lm3s6965evb \
    -cpu cortex-m3 \
    -nographic \
    -semihosting-config enable=on,target=native \
    -kernel "$FIRMWARE_BIN" \
    -monitor telnet:127.0.0.1:1234,server,nowait \
    -gdb tcp::3333