#!/bin/bash

set -e

TARGET=${1:-arm}

echo "Starting GDB debug session for $TARGET..."

# Start QEMU in debug mode
if [ "$TARGET" = "arm" ]; then
    qemu-system-arm \
        -machine lm3s6965evb \
        -cpu cortex-m3 \
        -nographic \
        -kernel bazel-bin/firmware/firmware \
        -s -S &
    QEMU_PID=$!
    
    # Connect with GDB
    arm-none-eabi-gdb \
        -ex "target remote localhost:1234" \
        -ex "file bazel-bin/firmware/firmware" \
        -ex "load" \
        -ex "break main" \
        -ex "continue"
else
    qemu-system-riscv32 \
        -machine virt \
        -nographic \
        -bios none \
        -kernel bazel-bin/firmware/firmware_riscv \
        -s -S &
    QEMU_PID=$!
    
    # Connect with GDB
    riscv32-unknown-elf-gdb \
        -ex "target remote localhost:1234" \
        -ex "file bazel-bin/firmware/firmware_riscv" \
        -ex "load" \
        -ex "break main" \
        -ex "continue"
fi

# Clean up QEMU on exit
trap "kill $QEMU_PID 2>/dev/null || true" EXIT