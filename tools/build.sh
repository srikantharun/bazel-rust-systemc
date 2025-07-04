#!/bin/bash

set -e

echo "Building Rust firmware with Bazel..."

# Build for ARM Cortex-M4 target
echo "Building for ARM Cortex-M4..."
bazel build //firmware:firmware --config=thumb

# Build for RISC-V target
echo "Building for RISC-V..."
bazel build //firmware:firmware_riscv --config=riscv

# Build SystemC testbench
echo "Building SystemC testbench..."
bazel build //systemc:testbench

echo "Build complete!"
echo ""
echo "Binaries located at:"
echo "  ARM: bazel-bin/firmware/firmware"
echo "  RISC-V: bazel-bin/firmware/firmware_riscv"
echo "  SystemC TB: bazel-bin/systemc/testbench"