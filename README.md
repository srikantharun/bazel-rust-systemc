# Rust Firmware with Bazel, SystemC, and QEMU

This repository demonstrates a modern Bazel-based build system for Rust firmware development with SystemC simulation and QEMU emulation support.

## Features

- **Bazel Build System**: Modern, scalable build configuration
- **Multi-target Support**: ARM Cortex-M4 and RISC-V32 targets
- **Rich Rust Ecosystem**: Demonstrates use of embedded Rust crates
- **SystemC Integration**: Hardware modeling with SystemC/TLM
- **QEMU Simulation**: Full system emulation support
- **Co-simulation**: SystemC and QEMU integration

## Project Structure

```
rust-firmware-bazel/
├── firmware/           # Rust firmware source
│   ├── src/
│   │   ├── main.rs    # Main firmware logic
│   │   ├── peripheral.rs  # Hardware abstraction
│   │   └── protocol.rs    # Communication protocol
│   ├── Cargo.toml     # Rust dependencies
│   └── BUILD.bazel    # Bazel build rules
├── systemc/           # SystemC models
│   ├── peripheral_model.h/cpp
│   ├── testbench.cpp
│   └── BUILD.bazel
├── qemu/              # QEMU configuration
│   ├── machine_config.c
│   ├── run_qemu.sh
│   └── BUILD.bazel
├── platforms/         # Target platform definitions
├── rust/              # Rust toolchain config
├── tools/             # Build and simulation scripts
├── WORKSPACE.bazel    # Bazel workspace
└── .bazelrc          # Bazel configuration

## Dependencies

- Bazel 6.0+
- Rust 1.75+
- SystemC 2.3.3+
- QEMU 7.0+
- ARM GCC toolchain (for debugging)
- RISC-V GCC toolchain (optional)

## Building

```bash
# Build all targets
./tools/build.sh

# Build specific target
bazel build //firmware:firmware --config=thumb
bazel build //firmware:firmware_riscv --config=riscv
bazel build //systemc:testbench
```

## Running Simulations

```bash
# QEMU simulation (ARM)
./tools/simulate.sh qemu arm

# QEMU simulation (RISC-V)
./tools/simulate.sh qemu riscv

# SystemC simulation
./tools/simulate.sh systemc

# Co-simulation
./tools/simulate.sh co-sim
```

## Debugging

```bash
# Debug ARM target
./tools/debug.sh arm

# Debug RISC-V target
./tools/debug.sh riscv
```

## Rust Crates Used

- `cortex-m` & `cortex-m-rt`: ARM Cortex-M support
- `riscv` & `riscv-rt`: RISC-V support
- `heapless`: Static memory data structures
- `nb`: Non-blocking I/O traits
- `embedded-hal`: Hardware abstraction traits
- `defmt`: Efficient logging framework
- `fugit`: Time handling
- `stm32f4xx-hal`: STM32F4 HAL (optional)

## Bazel Features Demonstrated

- Multi-platform builds with `--platforms`
- Crate universe for Rust dependencies
- Custom toolchain configuration
- Build configurations and feature flags
- Cross-compilation support

## SystemC/TLM Features

- TLM 2.0 socket communication
- Interrupt modeling
- Register-based peripheral model
- Transaction-level modeling

## Extending the Project

1. **Add new peripherals**: Create models in `systemc/` and corresponding drivers in `firmware/src/peripheral.rs`
2. **Add new targets**: Define platforms in `platforms/` and update `WORKSPACE.bazel`
3. **Add dependencies**: Update `firmware/Cargo.toml` and regenerate lock file
4. **Custom QEMU machines**: Extend `qemu/machine_config.c`