# Quick Reference Guide

## Table of Contents
1. [Common Commands](#common-commands)
2. [Build Targets](#build-targets)
3. [Configuration Flags](#configuration-flags)
4. [File Locations](#file-locations)
5. [Debugging Commands](#debugging-commands)
6. [Rust Embedded Cheat Sheet](#rust-embedded-cheat-sheet)
7. [SystemC Quick Reference](#systemc-quick-reference)
8. [Memory Maps](#memory-maps)
9. [Useful Bazel Queries](#useful-bazel-queries)

## Common Commands

### Building

```bash
# Build all targets
bazel build //...

# Build firmware for ARM
bazel build --config=thumb //firmware:firmware

# Build firmware for RISC-V
bazel build --config=riscv //firmware:firmware_riscv

# Build SystemC testbench
bazel build //systemc:testbench

# Build with optimization
bazel build -c opt //firmware:firmware

# Build with debug info
bazel build -c dbg //firmware:firmware
```

### Running Simulations

```bash
# Run QEMU simulation (ARM)
./tools/simulate.sh qemu arm

# Run QEMU simulation (RISC-V)
./tools/simulate.sh qemu riscv

# Run SystemC simulation
./tools/simulate.sh systemc

# Run co-simulation
./tools/simulate.sh co-sim
```

### Debugging

```bash
# Debug ARM firmware
./tools/debug.sh arm

# Debug RISC-V firmware
./tools/debug.sh riscv

# Run with GDB
bazel run //qemu:run_qemu -- --gdb
```

### Testing

```bash
# Run all tests
bazel test //...

# Run firmware tests
bazel test //firmware:all_tests

# Run SystemC tests
bazel test //systemc:all_tests
```

### Cleaning

```bash
# Clean build artifacts
bazel clean

# Clean everything (including external deps)
bazel clean --expunge

# Clean specific target
bazel clean //firmware:firmware
```

## Build Targets

### Firmware Targets

| Target | Description | Platform |
|--------|-------------|----------|
| `//firmware:firmware` | ARM Cortex-M firmware | thumbv7em-none-eabihf |
| `//firmware:firmware_riscv` | RISC-V firmware | riscv32imac-unknown-none-elf |

### SystemC Targets

| Target | Description |
|--------|-------------|
| `//systemc:peripheral_model` | Peripheral model library |
| `//systemc:testbench` | SystemC testbench executable |

### QEMU Targets

| Target | Description |
|--------|-------------|
| `//qemu:run_qemu` | QEMU simulation script |
| `//qemu:machine_config` | Custom QEMU machine |

### Platform Targets

| Target | Description |
|--------|-------------|
| `//platforms:thumbv7em` | ARM Cortex-M4 platform |
| `//platforms:riscv32` | RISC-V 32-bit platform |

## Configuration Flags

### Build Configurations

```bash
# Target-specific builds
--config=thumb      # Build for ARM Cortex-M
--config=riscv      # Build for RISC-V
--config=sim        # Simulation build

# Optimization levels
-c opt              # Optimized build
-c dbg              # Debug build
-c fastbuild        # Fast build (default)

# Feature flags
--//:enable_logs=true    # Enable logging
--//:enable_debug=true   # Enable debug features
```

### Bazel Flags

```bash
# Performance
--jobs=N                    # Use N parallel jobs
--disk_cache=path          # Use disk cache
--remote_cache=url         # Use remote cache

# Debugging
--verbose_failures         # Show detailed error messages
--subcommands             # Show all commands
--sandbox_debug           # Debug sandbox issues
--toolchain_resolution_debug # Debug toolchain selection

# Output
--output_base=path        # Custom output directory
--compilation_mode=mode   # opt, dbg, fastbuild
```

## File Locations

### Source Files

```
firmware/
├── src/
│   ├── main.rs           # Main firmware entry point
│   ├── peripheral.rs     # Hardware abstraction layer
│   └── protocol.rs       # Communication protocols
├── Cargo.toml           # Rust dependencies
└── BUILD.bazel          # Build configuration

systemc/
├── peripheral_model.h   # Peripheral model header
├── peripheral_model.cpp # Peripheral model implementation
├── testbench.cpp        # SystemC testbench
└── BUILD.bazel          # SystemC build config
```

### Configuration Files

```
WORKSPACE.bazel          # External dependencies
.bazelrc                 # Build configuration
BUILD.bazel              # Root build file
platforms/BUILD.bazel    # Platform definitions
rust/toolchain/memory.x  # Linker script
```

### Build Outputs

```
bazel-bin/
├── firmware/
│   ├── firmware         # ARM firmware binary
│   └── firmware_riscv   # RISC-V firmware binary
├── systemc/
│   └── testbench        # SystemC simulation
└── qemu/
    └── run_qemu         # QEMU script
```

## Debugging Commands

### Binary Analysis

```bash
# Check binary format
file bazel-bin/firmware/firmware

# Show binary size
size bazel-bin/firmware/firmware

# Show symbols
nm bazel-bin/firmware/firmware

# Disassemble
objdump -d bazel-bin/firmware/firmware

# Show sections
objdump -h bazel-bin/firmware/firmware

# Hex dump
hexdump -C bazel-bin/firmware/firmware | head
```

### Memory Analysis

```bash
# Show memory map
arm-none-eabi-objdump -t bazel-bin/firmware/firmware | grep -E "\.text|\.data|\.bss"

# Check stack usage
arm-none-eabi-objdump -d bazel-bin/firmware/firmware | grep -E "sp|stack"

# Generate map file (add to rustc_flags)
rustc_flags = ["-C", "link-arg=-Wl,-Map=firmware.map"]
```

### GDB Commands

```bash
# Start GDB session
arm-none-eabi-gdb bazel-bin/firmware/firmware

# Common GDB commands
(gdb) target remote localhost:1234  # Connect to QEMU
(gdb) load                          # Load firmware
(gdb) break main                    # Set breakpoint
(gdb) continue                      # Continue execution
(gdb) info registers               # Show registers
(gdb) x/16x 0x20000000             # Examine memory
(gdb) bt                           # Show backtrace
```

## Rust Embedded Cheat Sheet

### Common Attributes

```rust
#![no_std]           // Disable standard library
#![no_main]          // Disable standard main function

#[entry]             // Entry point
#[interrupt]         // Interrupt handler
#[panic_handler]     // Panic handler
```

### Memory Management

```rust
// Static allocation
static mut BUFFER: [u8; 1024] = [0; 1024];

// Heapless collections
use heapless::Vec;
let mut vec: Vec<u8, 32> = Vec::new();

// String handling
use heapless::String;
let mut s: String<64> = String::new();
```

### Hardware Access

```rust
// Register access
unsafe {
    let reg = core::ptr::read_volatile(0x4000_0000 as *const u32);
    core::ptr::write_volatile(0x4000_0000 as *mut u32, value);
}

// Bit manipulation
let mask = 1 << 5;
reg |= mask;   // Set bit
reg &= !mask;  // Clear bit
```

### Error Handling

```rust
// Result types
fn read_sensor() -> Result<u16, SensorError> {
    // ...
}

// Option types
if let Some(value) = sensor.read() {
    // Handle value
}

// Unwrap alternatives
let value = sensor.read().unwrap_or(0);
```

## SystemC Quick Reference

### Basic Module Structure

```cpp
class MyModule : public sc_module {
    SC_CTOR(MyModule) {
        SC_THREAD(main_process);
    }
    
    void main_process() {
        while (true) {
            // Process logic
            wait(10, SC_NS);
        }
    }
};
```

### TLM Socket Usage

```cpp
// Target socket
tlm_utils::simple_target_socket<MyModule> socket;

// Register callbacks
socket.register_b_transport(this, &MyModule::b_transport);

// Transport implementation
void b_transport(tlm::tlm_generic_payload& trans, sc_time& delay) {
    // Handle transaction
}
```

### Time and Events

```cpp
// Time units
sc_time(10, SC_NS)    // 10 nanoseconds
sc_time(1, SC_US)     // 1 microsecond
sc_time(1, SC_MS)     // 1 millisecond

// Wait functions
wait(10, SC_NS);      // Wait for time
wait(event);          // Wait for event
wait(event & other);  // Wait for multiple events
```

## Memory Maps

### ARM Cortex-M Memory Layout

```
0x08000000 - 0x0803FFFF  Flash (256KB)
├── 0x08000000          Vector table
├── 0x08000100          Reset handler
└── 0x08000200          Application code

0x20000000 - 0x2000FFFF  RAM (64KB)
├── 0x20000000          Data section
├── 0x20008000          BSS section
└── 0x2000F000          Stack (grows down)
```

### Register Map (Example Peripheral)

```
Base: 0x40000000
├── 0x00  Control Register
│   ├── Bit 0: Enable
│   ├── Bit 1: Interrupt Enable
│   └── Bits 2-7: Reserved
├── 0x04  Status Register
│   ├── Bit 0: Ready
│   ├── Bit 1: Error
│   └── Bits 2-7: Reserved
└── 0x08  Data Register
    └── Bits 0-31: Data
```

### SystemC Memory Map

```
TLM Address Space:
├── 0x00000000 - 0x00000FFF  Control Registers
├── 0x00001000 - 0x00001FFF  Status Registers
└── 0x00002000 - 0x00003FFF  Data Buffers
```

## Useful Bazel Queries

### Target Information

```bash
# List all targets
bazel query //...

# List targets in package
bazel query //firmware:*

# Show target details
bazel query --output=build //firmware:firmware

# Show dependencies
bazel query "deps(//firmware:firmware)"

# Show reverse dependencies
bazel query "rdeps(//..., //firmware:firmware)"
```

### Dependency Analysis

```bash
# Find unused dependencies
bazel query "deps(//firmware:firmware) - //firmware:firmware"

# Check for circular dependencies
bazel query --output=graph //firmware:firmware

# Show external dependencies
bazel query "filter('^@', deps(//firmware:firmware))"
```

### Build Analysis

```bash
# Show build graph
bazel query --output=graph //firmware:firmware | dot -Tpng > deps.png

# Analyze build time
bazel build --profile=profile.json //firmware:firmware
bazel analyze-profile profile.json

# Check cache hit rate
bazel build --explain=explain.log //firmware:firmware
```

## Environment Variables

### Bazel Environment

```bash
# Cache locations
export BAZEL_CACHE_DIR=~/.bazel_cache

# Java heap size
export BAZEL_JAVA_HEAP_SIZE=4g

# Proxy settings
export http_proxy=http://proxy:8080
export https_proxy=http://proxy:8080
```

### Rust Environment

```bash
# Rust toolchain
export RUSTUP_TOOLCHAIN=stable

# Target directory
export CARGO_TARGET_DIR=target

# Rust flags
export RUSTFLAGS="-C opt-level=z"
```

### Cross-compilation

```bash
# ARM toolchain
export CC_thumbv7em_none_eabihf=arm-none-eabi-gcc
export AR_thumbv7em_none_eabihf=arm-none-eabi-ar

# RISC-V toolchain
export CC_riscv32imac_unknown_none_elf=riscv32-unknown-elf-gcc
export AR_riscv32imac_unknown_none_elf=riscv32-unknown-elf-ar
```

## Common File Extensions

| Extension | Description |
|-----------|-------------|
| `.bazel` | Bazel build files |
| `.bzl` | Bazel extension files |
| `.rs` | Rust source files |
| `.toml` | Cargo configuration |
| `.x` | Linker scripts |
| `.elf` | Executable binary |
| `.bin` | Raw binary |
| `.hex` | Intel hex format |
| `.map` | Memory map file |
| `.cpp/.h` | C++ source/header |
| `.vcd` | SystemC waveform |

## Keyboard Shortcuts

### GDB

| Key | Action |
|-----|--------|
| `Ctrl+C` | Interrupt execution |
| `Ctrl+D` | Exit GDB |
| `↑/↓` | Command history |
| `Tab` | Command completion |

### QEMU Monitor

| Key | Action |
|-----|--------|
| `Ctrl+A, X` | Exit QEMU |
| `Ctrl+A, C` | Switch to monitor |
| `Ctrl+A, H` | Help |

### Bazel

| Flag | Shortcut |
|------|----------|
| `-c opt` | Optimized build |
| `-c dbg` | Debug build |
| `-j N` | N parallel jobs |
| `-k` | Keep going on error |
| `-s` | Show commands |

## Common Patterns

### Conditional Compilation

```rust
#[cfg(feature = "debug")]
fn debug_print(msg: &str) {
    defmt::info!("{}", msg);
}

#[cfg(not(feature = "debug"))]
fn debug_print(_msg: &str) {}
```

### Error Propagation

```rust
fn init_system() -> Result<(), SystemError> {
    uart.init()?;
    gpio.init()?;
    timer.init()?;
    Ok(())
}
```

### State Machines

```rust
enum State {
    Idle,
    Processing,
    Error,
}

impl StateMachine {
    fn step(&mut self) -> State {
        match self.state {
            State::Idle => self.handle_idle(),
            State::Processing => self.handle_processing(),
            State::Error => self.handle_error(),
        }
    }
}
```

## Quick Links

- [Bazel Documentation](https://bazel.build/)
- [Rules Rust](https://github.com/bazelbuild/rules_rust)
- [Embedded Rust Book](https://rust-embedded.github.io/book/)
- [SystemC Reference](https://systemc.org/)
- [QEMU Documentation](https://www.qemu.org/docs/master/)

---

*This quick reference covers the most commonly used commands and patterns. For detailed explanations, refer to the comprehensive guides in the docs/ directory.*