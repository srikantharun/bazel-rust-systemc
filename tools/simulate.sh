#!/bin/bash

set -e

MODE=${1:-qemu}
TARGET=${2:-arm}

case $MODE in
    qemu)
        echo "Running QEMU simulation for $TARGET..."
        if [ "$TARGET" = "arm" ]; then
            bazel run //qemu:run_qemu -- $(pwd)/bazel-bin/firmware/firmware
        else
            echo "RISC-V QEMU simulation:"
            qemu-system-riscv32 \
                -machine virt \
                -nographic \
                -bios none \
                -kernel bazel-bin/firmware/firmware_riscv
        fi
        ;;
    
    systemc)
        echo "Running SystemC simulation..."
        bazel run //systemc:testbench
        ;;
    
    co-sim)
        echo "Running co-simulation with SystemC and QEMU..."
        # Start SystemC simulation in background
        bazel-bin/systemc/testbench &
        SYSTEMC_PID=$!
        
        # Give SystemC time to initialize
        sleep 2
        
        # Start QEMU with connection to SystemC
        qemu-system-arm \
            -machine lm3s6965evb \
            -cpu cortex-m3 \
            -nographic \
            -kernel bazel-bin/firmware/firmware \
            -chardev socket,id=systemc,host=localhost,port=5555,server=on,wait=off \
            -serial chardev:systemc
        
        # Clean up
        kill $SYSTEMC_PID 2>/dev/null || true
        ;;
    
    *)
        echo "Usage: $0 [qemu|systemc|co-sim] [arm|riscv]"
        exit 1
        ;;
esac